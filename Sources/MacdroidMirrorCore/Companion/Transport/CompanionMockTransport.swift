import Foundation

/// In-memory mock transport for testing pairing, authentication, and packet streaming.
public final class CompanionMockTransport: CompanionTransporting, @unchecked Sendable {
    public private(set) var state: TransportState = .disconnected
    public let endpointDescription: String

    public var onSend: (@Sendable (CompanionPacket) -> Void)?
    private var incomingQueue: [CompanionPacket] = []
    private var receiveContinuations: [CheckedContinuation<CompanionPacket, Error>] = []
    private let lock = NSLock()

    public init(endpointDescription: String = "mock://local") {
        self.endpointDescription = endpointDescription
    }

    public func connect() async throws {
        lock.lock()
        state = .connected
        lock.unlock()
    }

    public func disconnect() async {
        lock.lock()
        state = .disconnected
        let pending = receiveContinuations
        receiveContinuations.removeAll()
        incomingQueue.removeAll()
        lock.unlock()

        for cont in pending {
            cont.resume(throwing: CompanionTransportError.connectionClosed)
        }
    }

    public func send(packet: CompanionPacket) async throws {
        lock.lock()
        guard state == .connected else {
            lock.unlock()
            throw CompanionTransportError.notConnected
        }
        let callback = onSend
        lock.unlock()

        callback?(packet)
    }

    public func receive() async throws -> CompanionPacket {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            guard state == .connected else {
                lock.unlock()
                continuation.resume(throwing: CompanionTransportError.notConnected)
                return
            }

            if !incomingQueue.isEmpty {
                let packet = incomingQueue.removeFirst()
                lock.unlock()
                continuation.resume(returning: packet)
            } else {
                receiveContinuations.append(continuation)
                lock.unlock()
            }
        }
    }

    /// Injects an incoming packet to be consumed by `receive()`
    public func injectIncoming(packet: CompanionPacket) {
        lock.lock()
        if !receiveContinuations.isEmpty {
            let cont = receiveContinuations.removeFirst()
            lock.unlock()
            cont.resume(returning: packet)
        } else {
            incomingQueue.append(packet)
            lock.unlock()
        }
    }

    /// Simulates sudden remote connection drop
    public func simulateConnectionDrop() {
        Task { await disconnect() }
    }
}
