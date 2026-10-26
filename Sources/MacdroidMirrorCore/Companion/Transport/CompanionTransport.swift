import Foundation

/// State of the companion transport layer
public enum TransportState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)
}

/// Abstract transport layer capable of sending and receiving framed `CompanionPacket` objects.
public protocol CompanionTransporting: Sendable {
    var state: TransportState { get }
    var endpointDescription: String { get }
    
    func connect() async throws
    func disconnect() async
    func send(packet: CompanionPacket) async throws
    func receive() async throws -> CompanionPacket
}

/// Transport-specific errors
public enum CompanionTransportError: Error, LocalizedError, Equatable {
    case notConnected
    case connectionFailed(String)
    case connectionClosed
    case timeout
    case socketError(String)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Companion transport is not connected."
        case .connectionFailed(let reason):
            return "Failed to establish companion connection: \(reason)"
        case .connectionClosed:
            return "Companion connection was closed by remote endpoint."
        case .timeout:
            return "Companion transport timed out waiting for data."
        case .socketError(let msg):
            return "Socket I/O error: \(msg)"
        }
    }
}
