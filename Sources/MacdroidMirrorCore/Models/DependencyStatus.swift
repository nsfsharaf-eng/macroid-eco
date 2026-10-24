import Foundation

/// Status of a local system executable tool (ADB or scrcpy).
public enum DependencyStatus: Hashable, Sendable {
    case available(path: String, version: String?)
    case missing(searchedPaths: [String])
    case permissionDenied(path: String)
    case executionError(message: String)
    case checking

    public var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    public var path: String? {
        if case .available(let path, _) = self { return path }
        return nil
    }

    public var version: String? {
        if case .available(_, let version) = self { return version }
        return nil
    }

    public var statusText: String {
        switch self {
        case .available(_, let version):
            if let ver = version, !ver.isEmpty {
                return "Installed (\(ver))"
            }
            return "Installed"
        case .missing:
            return "Not Found"
        case .permissionDenied:
            return "Permission Denied"
        case .executionError(let msg):
            return "Error: \(msg)"
        case .checking:
            return "Checking…"
        }
    }
}

/// Aggregate status of critical external dependencies.
public struct SystemDependencies: Hashable, Sendable {
    public var adb: DependencyStatus
    public var scrcpy: DependencyStatus

    public init(
        adb: DependencyStatus = .checking,
        scrcpy: DependencyStatus = .checking
    ) {
        self.adb = adb
        self.scrcpy = scrcpy
    }

    public var allAvailable: Bool {
        adb.isAvailable && scrcpy.isAvailable
    }
}
