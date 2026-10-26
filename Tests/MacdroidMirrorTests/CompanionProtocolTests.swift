import Foundation
import Testing
@testable import MacdroidMirrorCore

@Suite("Companion Protocol Tests")
struct CompanionProtocolTests {

    @Test("CompanionPacket header serialization and roundtrip parsing")
    func testPacketRoundtrip() throws {
        let originalPayload = "{\"test\":\"hello world\"}".data(using: .utf8)!
        let packet = CompanionPacket(
            type: .ping,
            flags: 0x01,
            payload: originalPayload
        )

        let serialized = packet.serialize()
        #expect(serialized.count == 12 + originalPayload.count)

        // Magic bytes MECO
        let magicStr = String(data: serialized.subdata(in: 0..<4), encoding: .utf8)
        #expect(magicStr == "MECO")

        let parseResult = try CompanionPacket.parse(from: serialized)
        #expect(parseResult != nil)
        guard let (parsedPacket, bytesConsumed) = parseResult else { return }

        #expect(bytesConsumed == serialized.count)
        #expect(parsedPacket.version == CompanionPacket.currentVersion)
        #expect(parsedPacket.type == .ping)
        #expect(parsedPacket.flags == 0x01)
        #expect(parsedPacket.payload == originalPayload)
    }

    @Test("CompanionPacket rejects invalid magic header")
    func testInvalidMagic() {
        var corrupted = CompanionPacket(type: .ping).serialize()
        corrupted[0] = 0x58 // 'X' instead of 'M'

        #expect(throws: CompanionProtocolError.invalidMagicBytes) {
            _ = try CompanionPacket.parse(from: corrupted)
        }
    }

    @Test("CompanionPacket rejects oversized payload header")
    func testOversizedPayload() {
        var corrupted = CompanionPacket(type: .ping).serialize()
        // Overwrite payloadLength (bytes 8..11) with 17 MB (17 * 1024 * 1024 = 17825792)
        let oversized: UInt32 = 17 * 1024 * 1024
        withUnsafeBytes(of: oversized.bigEndian) { bytes in
            corrupted.replaceSubrange(8..<12, with: bytes)
        }

        do {
            _ = try CompanionPacket.parse(from: corrupted)
            Issue.record("Expected payloadTooLarge error")
        } catch CompanionProtocolError.payloadTooLarge(let len) {
            #expect(len > CompanionPacket.maxPayloadSize)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("CompanionPacket stream reassembly handles fragmented data")
    func testFragmentedStreamReassembly() throws {
        let payload = "{\"device\":\"Redmi Note\"}".data(using: .utf8)!
        let packet = CompanionPacket(type: .deviceStatus, payload: payload)
        let fullData = packet.serialize()

        // Feed data byte by byte
        var accumulator = Data()
        var parsed: (packet: CompanionPacket, bytesConsumed: Int)?

        for byte in fullData {
            accumulator.append(byte)
            if let result = try? CompanionPacket.parse(from: accumulator) {
                parsed = result
                break
            }
        }

        #expect(parsed != nil)
        #expect(parsed?.bytesConsumed == fullData.count)
        #expect(parsed?.packet.type == .deviceStatus)
        #expect(parsed?.packet.payload == payload)
    }

    @Test("CompanionSecurity random nonce generation")
    func testNonceGeneration() {
        let nonce1 = CompanionSecurity.generateNonce(byteCount: 16)
        let nonce2 = CompanionSecurity.generateNonce(byteCount: 16)

        #expect(nonce1.count == 32) // 16 bytes = 32 hex chars
        #expect(nonce2.count == 32)
        #expect(nonce1 != nonce2)
    }

    @Test("CompanionSecurity Short Authentication String (SAS) derivation")
    func testSASDerivation() {
        let clientNonce = "a1b2c3d4e5f60718"
        let serverNonce = "9f8e7d6c5b4a3210"
        let salt = "macroid-eco-sas-v1"

        let sas1 = CompanionSecurity.computeSAS(clientNonce: clientNonce, serverNonce: serverNonce, salt: salt)
        let sas2 = CompanionSecurity.computeSAS(clientNonce: clientNonce, serverNonce: serverNonce, salt: salt)

        #expect(sas1 == sas2)
        #expect(sas1.count == 7) // "123 456" has length 7 (6 digits + 1 space)
        #expect(sas1.contains(" "))

        let parts = sas1.split(separator: " ")
        #expect(parts.count == 2)
        #expect(parts[0].count == 3)
        #expect(parts[1].count == 3)

        // Altering one nonce produces a different SAS code
        let differentSas = CompanionSecurity.computeSAS(clientNonce: "0000000000000000", serverNonce: serverNonce, salt: salt)
        #expect(sas1 != differentSas)
    }

    @Test("CompanionSecurity HMAC-SHA256 verification and constant-time compare")
    func testHmacVerification() {
        let message = "device_id=Redmi_Note_14&nonce=abcd1234"
        let secret = "super-secret-key-32-bytes-long!!"

        let signature = CompanionSecurity.computeHMAC(message: message, key: secret)
        #expect(!signature.isEmpty)

        // Same signature regenerated
        let signature2 = CompanionSecurity.computeHMAC(message: message, key: secret)
        #expect(signature == signature2)

        // Altered message produces different signature
        let tamperedSignature = CompanionSecurity.computeHMAC(message: "tampered_data", key: secret)
        #expect(signature != tamperedSignature)

        // Constant time compare
        #expect(CompanionSecurity.secureCompare("abcdef", "abcdef"))
        #expect(!CompanionSecurity.secureCompare("abcdef", "abcdeg"))
        #expect(!CompanionSecurity.secureCompare("abcdef", "abcde"))
    }

    @Test("CompanionPayloads JSON encode and decode roundtrips")
    func testPayloadSerialization() throws {
        // Device status
        let status = DeviceStatusPayload(
            batteryLevel: 87,
            isCharging: true,
            wifiSSID: "Office-5G",
            cellularNetwork: "Jio 5G"
        )
        let statusPacket = try CompanionPacket(type: .deviceStatus, payloadModel: status)
        let decodedStatus = try statusPacket.decodePayload(as: DeviceStatusPayload.self)
        #expect(decodedStatus.batteryLevel == 87)
        #expect(decodedStatus.isCharging == true)
        #expect(decodedStatus.cellularNetwork == "Jio 5G")

        // Notification
        let notification = NotificationPayload(
            id: "notif-9912",
            key: "key-whatsapp-9912",
            packageName: "com.whatsapp",
            appName: "WhatsApp",
            title: "Alice",
            text: "Are you coming to the meeting?",
            actions: [NotificationActionItem(id: "reply", title: "Reply", isQuickReply: true)]
        )
        let notifPacket = try CompanionPacket(type: .notificationPosted, payloadModel: notification)
        let decodedNotif = try notifPacket.decodePayload(as: NotificationPayload.self)
        #expect(decodedNotif.id == "notif-9912")
        #expect(decodedNotif.appName == "WhatsApp")
        #expect(decodedNotif.actions.count == 1)

        // SMS Message
        let sms = SmsMessagePayload(
            id: "sms-551",
            threadId: "thread-12",
            senderAddress: "+15551234567",
            body: "Verification code: 849201"
        )
        let smsPacket = try CompanionPacket(type: .smsReceived, payloadModel: sms)
        let decodedSms = try smsPacket.decodePayload(as: SmsMessagePayload.self)
        #expect(decodedSms.senderAddress == "+15551234567")
        #expect(decodedSms.body.contains("Verification code"))

        // Call State
        let call = CallStatePayload(
            state: .ringing,
            incomingNumber: "+15559876543",
            callerName: "Bob Smith"
        )
        let callPacket = try CompanionPacket(type: .callStateChanged, payloadModel: call)
        let decodedCall = try callPacket.decodePayload(as: CallStatePayload.self)
        #expect(decodedCall.state == .ringing)
        #expect(decodedCall.callerName == "Bob Smith")

        // Clipboard
        let clip = ClipboardSyncPayload(
            text: "https://github.com/nsfsharaf-eng/macroid-eco",
            sourceDeviceId: "MacBookPro"
        )
        let clipPacket = try CompanionPacket(type: .clipboardSync, payloadModel: clip)
        let decodedClip = try clipPacket.decodePayload(as: ClipboardSyncPayload.self)
        #expect(decodedClip.text.contains("github.com"))
    }

    @Test("CompanionMockTransport simulates packet delivery")
    func testMockTransportStreaming() async throws {
        let transport = CompanionMockTransport()
        #expect(transport.state == .disconnected)

        try await transport.connect()
        #expect(transport.state == .connected)

        var receivedPackets: [CompanionPacket] = []
        transport.onSend = { packet in
            receivedPackets.append(packet)
        }

        let testPacket = CompanionPacket(type: .ping)
        try await transport.send(packet: testPacket)

        #expect(receivedPackets.count == 1)
        #expect(receivedPackets.first?.type == .ping)

        // Enqueue incoming packet on mock transport
        let incoming = CompanionPacket(type: .pong)
        transport.injectIncoming(packet: incoming)

        let received = try await transport.receive()
        #expect(received.type == .pong)

        await transport.disconnect()
        #expect(transport.state == .disconnected)
    }

    @Test("CompanionSessionManager full pairing handshake flow")
    func testCompanionPairingFlow() async throws {
        let mockTransport = CompanionMockTransport()
        let manager = await CompanionSessionManager()

        let isDisconnected = await MainActor.run { manager.state == .disconnected }
        #expect(isDisconnected)

        var capturedPairRequest: PairRequestPayload?
        mockTransport.onSend = { packet in
            if packet.type == .pairRequest, let req = try? packet.decodePayload(as: PairRequestPayload.self) {
                capturedPairRequest = req
            }
        }

        // Start pairing task
        let pairingTask = Task { @MainActor in
            try await manager.startPairing(with: mockTransport)
        }

        // Wait for connect & pairRequest
        try await Task.sleep(nanoseconds: 80_000_000)

        guard let pairReq = capturedPairRequest else {
            Issue.record("Expected to capture pairRequest from Mac")
            return
        }

        // Mock phone derives SAS from clientNonce
        let serverNonce = CompanionSecurity.generateNonce()
        let salt = "macroid-eco-sas-v1"
        let expectedSAS = CompanionSecurity.computeSAS(
            clientNonce: pairReq.clientNonce,
            serverNonce: serverNonce,
            salt: salt
        )

        let challengePayload = PairChallengePayload(
            serverName: "Macroid Companion",
            serverDevice: "Redmi Note 14 Pro+ 5G",
            sasCode: expectedSAS,
            serverNonce: serverNonce,
            salt: salt
        )
        let challengePacket = try CompanionPacket(type: .pairChallenge, payloadModel: challengePayload)
        mockTransport.injectIncoming(packet: challengePacket)

        _ = try await pairingTask.value

        let isPairingState = await MainActor.run { () -> Bool in
            if case .pairing(let sas, let device) = manager.state {
                return sas == expectedSAS && device == "Redmi Note 14 Pro+ 5G"
            }
            return false
        }
        #expect(isPairingState)

        // Mac user confirms pairing
        let confirmTask = Task { @MainActor in
            try await manager.confirmPairing()
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        // Phone responds with PAIR_SUCCESS
        let successPayload = PairSuccessPayload(authToken: "token-auth-xyz", serverProof: "proof-abc")
        let successPacket = try CompanionPacket(type: .pairSuccess, payloadModel: successPayload)
        mockTransport.injectIncoming(packet: successPacket)

        _ = try await confirmTask.value

        let isConnected = await MainActor.run { () -> Bool in
            if case .connected = manager.state {
                return manager.savedAuthToken == "token-auth-xyz"
            }
            return false
        }
        #expect(isConnected)

        await manager.disconnect()
        let isDisconnectedAfter = await MainActor.run { manager.state == .disconnected }
        #expect(isDisconnectedAfter)
    }

    @Test("CompanionSessionManager authentication failure handles rejection safely")
    func testCompanionAuthFailure() async throws {
        let mockTransport = CompanionMockTransport()
        let manager = await CompanionSessionManager()

        let authTask = Task { @MainActor in
            try await manager.authenticate(with: mockTransport, token: "bad-token")
        }

        // Wait for connect & auth request
        try await Task.sleep(nanoseconds: 60_000_000)

        // Mock phone rejects authentication
        let failPayload = AuthResponsePayload(isSuccess: false, message: "Invalid auth token")
        let rejectPacket = try CompanionPacket(type: .authFailed, payloadModel: failPayload)
        mockTransport.injectIncoming(packet: rejectPacket)

        do {
            _ = try await authTask.value
            Issue.record("Expected authentication to fail")
        } catch {
            let isFailed = await MainActor.run { () -> Bool in
                if case .failed = manager.state { return true }
                return false
            }
            #expect(isFailed)
        }
    }
}
