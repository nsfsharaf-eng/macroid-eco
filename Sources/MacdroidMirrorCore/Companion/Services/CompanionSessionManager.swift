import Foundation
import Combine

/// High-level session states for the companion connection
public enum CompanionSessionState: Sendable, Equatable {
    case disconnected
    case connecting
    case pairing(sasCode: String, serverDevice: String)
    case authenticating
    case connected(serverDevice: String)
    case failed(String)

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    public var statusDescription: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting to Companion..."
        case .pairing(let sas, let device): return "Pairing with \(device) (SAS: \(sas))"
        case .authenticating: return "Authenticating..."
        case .connected(let device): return "Connected to \(device)"
        case .failed(let err): return "Connection Failed: \(err)"
        }
    }
}

/// Orchestrates the companion protocol session, pairing flow, state machine, and incoming streams.
@MainActor
public final class CompanionSessionManager: ObservableObject {
    @Published public private(set) var state: CompanionSessionState = .disconnected
    @Published public private(set) var deviceStatus: DeviceStatusPayload?
    @Published public private(set) var notifications: [NotificationPayload] = []
    @Published public private(set) var smsMessages: [SmsMessagePayload] = []
    @Published public private(set) var latestCallState: CallStatePayload?
    @Published public private(set) var lastSyncedClipboard: String?
    @Published public private(set) var savedAuthToken: String?

    private var transport: CompanionTransporting?
    private var listenTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?

    // Internal pairing handshake state
    private var pendingClientNonce: String?
    private var pendingServerNonce: String?
    private var pendingSalt: String?

    public init(savedAuthToken: String? = nil) {
        self.savedAuthToken = savedAuthToken
    }

    // MARK: - Connection & Pairing Flows

    /// Initiates a new pairing handshake with an Android phone
    public func startPairing(with transport: CompanionTransporting) async throws {
        self.transport = transport
        self.state = .connecting

        do {
            try await transport.connect()

            let clientNonce = CompanionSecurity.generateNonce()
            self.pendingClientNonce = clientNonce

            // 1. Send PAIR_REQUEST
            let pairReq = PairRequestPayload(clientNonce: clientNonce)
            let packet = try CompanionPacket(type: .pairRequest, payloadModel: pairReq)
            try await transport.send(packet: packet)

            // 2. Await PAIR_CHALLENGE from phone
            let challengePacket = try await transport.receive()
            guard challengePacket.type == .pairChallenge else {
                throw CompanionProtocolError.decodingFailed("Expected PAIR_CHALLENGE, got \(challengePacket.type.name)")
            }

            let challenge = try challengePacket.decodePayload(as: PairChallengePayload.self)
            self.pendingServerNonce = challenge.serverNonce
            self.pendingSalt = challenge.salt

            // Verify SAS matches locally computed value
            let expectedSAS = CompanionSecurity.computeSAS(
                clientNonce: clientNonce,
                serverNonce: challenge.serverNonce,
                salt: challenge.salt
            )

            guard challenge.sasCode == expectedSAS else {
                throw CompanionProtocolError.decodingFailed("SAS code mismatch. Possible MITM attack.")
            }

            // Transition to pairing state for visual confirmation
            self.state = .pairing(sasCode: challenge.sasCode, serverDevice: challenge.serverDevice)
        } catch {
            self.state = .failed(error.localizedDescription)
            await transport.disconnect()
            throw error
        }
    }

    /// User confirmed the 6-digit SAS code matches the phone screen; completes pairing
    public func confirmPairing() async throws {
        guard let transport = self.transport,
              let clientNonce = self.pendingClientNonce,
              let serverNonce = self.pendingServerNonce,
              let salt = self.pendingSalt else {
            throw CompanionTransportError.notConnected
        }

        do {
            // Send PAIR_CONFIRM with HMAC client proof
            let proof = CompanionSecurity.computeHMAC(message: "\(clientNonce):\(serverNonce)", key: salt)
            let confirmPayload = PairConfirmPayload(clientProof: proof, sasConfirmed: true)
            let confirmPacket = try CompanionPacket(type: .pairConfirm, payloadModel: confirmPayload)
            try await transport.send(packet: confirmPacket)

            // Await PAIR_SUCCESS with persistent auth token
            let successPacket = try await transport.receive()
            guard successPacket.type == .pairSuccess else {
                let failMsg = (try? successPacket.decodePayload(as: AuthResponsePayload.self))?.message ?? "Pairing rejected by device."
                throw CompanionTransportError.connectionFailed(failMsg)
            }

            let successPayload = try successPacket.decodePayload(as: PairSuccessPayload.self)
            self.savedAuthToken = successPayload.authToken
            self.state = .connected(serverDevice: "Android Device")

            // Start message listening loop & keep-alive ping
            startListeningLoop()
            startPingLoop()
        } catch {
            self.state = .failed(error.localizedDescription)
            await transport.disconnect()
            throw error
        }
    }

    /// Authenticates with an already paired Android device using the stored auth token
    public func authenticate(with transport: CompanionTransporting, token: String) async throws {
        self.transport = transport
        self.state = .authenticating

        do {
            try await transport.connect()

            let authReq = AuthRequestPayload(clientName: "Macroid Eco", authToken: token)
            let packet = try CompanionPacket(type: .authRequest, payloadModel: authReq)
            try await transport.send(packet: packet)

            let respPacket = try await transport.receive()
            guard respPacket.type == .authSuccess else {
                let failMsg = (try? respPacket.decodePayload(as: AuthResponsePayload.self))?.message ?? "Authentication failed."
                throw CompanionTransportError.connectionFailed(failMsg)
            }

            self.savedAuthToken = token
            self.state = .connected(serverDevice: "Android Device")

            startListeningLoop()
            startPingLoop()
        } catch {
            self.state = .failed(error.localizedDescription)
            await transport.disconnect()
            throw error
        }
    }

    /// Disconnects the active companion session
    public func disconnect() async {
        listenTask?.cancel()
        listenTask = nil
        pingTask?.cancel()
        pingTask = nil

        if let transport = self.transport {
            _ = try? await transport.send(packet: CompanionPacket(type: .disconnect))
            await transport.disconnect()
        }

        self.transport = nil
        self.state = .disconnected
    }

    // MARK: - Companion Actions (Client -> Android)

    public func dismissNotification(key: String) async throws {
        guard let transport = self.transport, state.isConnected else { return }
        let payload = NotificationActionRequestPayload(notificationKey: key, actionId: nil)
        let packet = try CompanionPacket(type: .notificationAction, payloadModel: payload)
        try await transport.send(packet: packet)
        notifications.removeAll(where: { $0.key == key })
    }

    public func replyToNotification(key: String, text: String) async throws {
        guard let transport = self.transport, state.isConnected else { return }
        let payload = NotificationActionRequestPayload(notificationKey: key, actionId: "reply", replyText: text)
        let packet = try CompanionPacket(type: .notificationAction, payloadModel: payload)
        try await transport.send(packet: packet)
    }

    public func sendSms(recipient: String, body: String) async throws {
        guard let transport = self.transport, state.isConnected else { return }
        let payload = SmsSendRequestPayload(recipientAddress: recipient, body: body)
        let packet = try CompanionPacket(type: .smsSendRequest, payloadModel: payload)
        try await transport.send(packet: packet)
    }

    public func syncClipboard(text: String) async throws {
        guard let transport = self.transport, state.isConnected else { return }
        let payload = ClipboardSyncPayload(text: text, sourceDeviceId: "macOS")
        let packet = try CompanionPacket(type: .clipboardSync, payloadModel: payload)
        try await transport.send(packet: packet)
        self.lastSyncedClipboard = text
    }

    // MARK: - Background Message Stream & Heartbeat

    private func startListeningLoop() {
        listenTask?.cancel()
        listenTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, let transport = self.transport else { break }

                do {
                    let packet = try await transport.receive()
                    await self.handleIncomingPacket(packet)
                } catch {
                    if !Task.isCancelled {
                        self.state = .failed("Connection lost: \(error.localizedDescription)")
                    }
                    break
                }
            }
        }
    }

    private func handleIncomingPacket(_ packet: CompanionPacket) async {
        switch packet.type {
        case .pong:
            break // Keep-alive acknowledged

        case .deviceStatus:
            if let status = try? packet.decodePayload(as: DeviceStatusPayload.self) {
                self.deviceStatus = status
            }

        case .notificationPosted:
            if let notif = try? packet.decodePayload(as: NotificationPayload.self) {
                if let index = notifications.firstIndex(where: { $0.key == notif.key }) {
                    notifications[index] = notif
                } else {
                    notifications.insert(notif, at: 0)
                }
            }

        case .notificationRemoved:
            if let key = String(data: packet.payload, encoding: .utf8) {
                notifications.removeAll(where: { $0.key == key })
            }

        case .smsReceived:
            if let msg = try? packet.decodePayload(as: SmsMessagePayload.self) {
                smsMessages.insert(msg, at: 0)
            }

        case .callStateChanged:
            if let call = try? packet.decodePayload(as: CallStatePayload.self) {
                self.latestCallState = call
            }

        case .clipboardSync:
            if let clip = try? packet.decodePayload(as: ClipboardSyncPayload.self) {
                self.lastSyncedClipboard = clip.text
            }

        case .disconnect:
            await disconnect()

        default:
            break
        }
    }

    private func startPingLoop() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15s keep-alive
                guard let self = self, let transport = self.transport, self.state.isConnected else { break }
                let ping = CompanionPacket(type: .ping)
                try? await transport.send(packet: ping)
            }
        }
    }
}
