import Foundation

/// Transport layer that establishes an authenticated local bridge through `adb forward`.
///
/// This provides local communication over USB or existing ADB sessions, bypassing Wi-Fi AP Client Isolation.
public final class AdbBridgeTransport: CompanionTransporting, @unchecked Sendable {
    public let serial: String
    public let adbPath: String
    public let localPort: UInt16
    public let remotePort: UInt16
    public let processRunner: ProcessRunning

    private var socketTransport: NetworkSocketTransport?
    public var state: TransportState { socketTransport?.state ?? .disconnected }
    public var endpointDescription: String { "adb-bridge://\(serial):\(remotePort) -> 127.0.0.1:\(localPort)" }

    public init(
        serial: String,
        adbPath: String,
        localPort: UInt16 = 8275,
        remotePort: UInt16 = 8275,
        processRunner: ProcessRunning = SafeProcessRunner()
    ) {
        self.serial = serial
        self.adbPath = adbPath
        self.localPort = localPort
        self.remotePort = remotePort
        self.processRunner = processRunner
    }

    public func connect() async throws {
        // Step 1: Set up ADB port forwarding: adb -s <serial> forward tcp:<localPort> tcp:<remotePort>
        let forwardRes = try await processRunner.run(
            executablePath: adbPath,
            arguments: ["-s", serial, "forward", "tcp:\(localPort)", "tcp:\(remotePort)"],
            environment: nil,
            timeout: 5.0
        )

        guard forwardRes.isSuccess else {
            let msg = forwardRes.standardError.isEmpty ? forwardRes.standardOutput : forwardRes.standardError
            throw CompanionTransportError.connectionFailed("ADB forward setup failed: \(msg)")
        }

        // Step 2: Connect socket to localhost
        let transport = NetworkSocketTransport(host: "127.0.0.1", port: localPort)
        self.socketTransport = transport
        try await transport.connect()
    }

    public func disconnect() async {
        await socketTransport?.disconnect()
        socketTransport = nil

        // Clean up port forwarding
        _ = try? await processRunner.run(
            executablePath: adbPath,
            arguments: ["-s", serial, "forward", "--remove", "tcp:\(localPort)"],
            environment: nil,
            timeout: 3.0
        )
    }

    public func send(packet: CompanionPacket) async throws {
        guard let transport = socketTransport else {
            throw CompanionTransportError.notConnected
        }
        try await transport.send(packet: packet)
    }

    public func receive() async throws -> CompanionPacket {
        guard let transport = socketTransport else {
            throw CompanionTransportError.notConnected
        }
        return try await transport.receive()
    }
}
