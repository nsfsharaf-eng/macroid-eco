import Foundation
import Network

/// Concrete transport communicating over TCP sockets using Apple's Network.framework.
public final class NetworkSocketTransport: CompanionTransporting, @unchecked Sendable {
    public private(set) var state: TransportState = .disconnected
    public let host: String
    public let port: UInt16
    public var endpointDescription: String { "\(host):\(port)" }

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.macroideco.companion.transport", qos: .userInitiated)
    private var readBuffer = Data()
    private let lock = NSLock()

    public init(host: String, port: UInt16 = 8275) {
        self.host = host
        self.port = port
    }

    public func connect() async throws {
        lock.lock()
        if case .connected = state {
            lock.unlock()
            return
        }
        state = .connecting
        lock.unlock()

        let nwHost = NWEndpoint.Host(host)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw CompanionTransportError.connectionFailed("Invalid port: \(port)")
        }

        let nwConn = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        self.connection = nwConn

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var hasResumed = false

            nwConn.stateUpdateHandler = { [weak self] newState in
                guard let self = self else { return }
                switch newState {
                case .ready:
                    self.lock.lock()
                    self.state = .connected
                    self.lock.unlock()
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume()
                    }
                case .failed(let error):
                    self.lock.lock()
                    self.state = .failed(error.localizedDescription)
                    self.lock.unlock()
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(throwing: CompanionTransportError.connectionFailed(error.localizedDescription))
                    }
                case .cancelled:
                    self.lock.lock()
                    self.state = .disconnected
                    self.lock.unlock()
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(throwing: CompanionTransportError.connectionClosed)
                    }
                default:
                    break
                }
            }

            nwConn.start(queue: queue)
        }
    }

    public func disconnect() async {
        lock.lock()
        state = .disconnected
        readBuffer.removeAll()
        let conn = connection
        connection = nil
        lock.unlock()

        conn?.cancel()
    }

    public func send(packet: CompanionPacket) async throws {
        guard let conn = connection, state == .connected else {
            throw CompanionTransportError.notConnected
        }

        let serializedData = packet.serialize()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            conn.send(content: serializedData, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: CompanionTransportError.socketError(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    public func receive() async throws -> CompanionPacket {
        while true {
            lock.lock()
            // Check if readBuffer already has a complete packet
            if let parsed = try? CompanionPacket.parse(from: readBuffer) {
                readBuffer.removeSubrange(0..<parsed.bytesConsumed)
                lock.unlock()
                return parsed.packet
            }
            lock.unlock()

            guard let conn = connection, state == .connected else {
                throw CompanionTransportError.notConnected
            }

            // Read more chunks from the TCP stream
            let chunk: Data = try await withCheckedThrowingContinuation { continuation in
                conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { content, _, isComplete, error in
                    if let error = error {
                        continuation.resume(throwing: CompanionTransportError.socketError(error.localizedDescription))
                    } else if let data = content, !data.isEmpty {
                        continuation.resume(returning: data)
                    } else if isComplete {
                        continuation.resume(throwing: CompanionTransportError.connectionClosed)
                    } else {
                        continuation.resume(returning: Data())
                    }
                }
            }

            lock.lock()
            readBuffer.append(chunk)
            lock.unlock()
        }
    }
}
