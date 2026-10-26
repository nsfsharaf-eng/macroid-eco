import Foundation

/// Lifecycle states of a mirroring session.
public enum SessionState: Hashable, Sendable {
    case idle
    case starting(deviceId: String)
    case active(deviceId: String, pid: Int32, startTime: Date)
    case stopping(deviceId: String)
    case terminated(deviceId: String, exitCode: Int32, message: String?)
    case failed(deviceId: String, error: String)

    public var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    public var isStopping: Bool {
        if case .stopping = self { return true }
        return false
    }

    public var isTransitioning: Bool {
        switch self {
        case .starting, .stopping: return true
        default: return false
        }
    }

    public var activeDeviceId: String? {
        switch self {
        case .starting(let id),
             .active(let id, _, _),
             .stopping(let id),
             .terminated(let id, _, _),
             .failed(let id, _):
            return id
        case .idle:
            return nil
        }
    }

    public var statusDescription: String {
        switch self {
        case .idle:
            return "Idle"
        case .starting:
            return "Starting session…"
        case .active(_, let pid, _):
            return "Mirroring active (PID \(pid))"
        case .stopping:
            return "Stopping session…"
        case .terminated(_, let code, let msg):
            if let msg = msg, !msg.isEmpty {
                return "Session closed (\(msg))"
            }
            return "Session terminated (exit code \(code))"
        case .failed(_, let error):
            return "Failed: \(error)"
        }
    }
}
