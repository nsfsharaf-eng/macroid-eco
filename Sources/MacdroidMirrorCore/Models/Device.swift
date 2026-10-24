import Foundation

/// Represents the connection and authorization state of an Android device as reported by ADB.
public enum DeviceState: Hashable, Codable, Sendable {
    case authorized
    case unauthorized
    case offline
    case authorizing
    case recovery
    case bootloader
    case unknown(String)

    public init?(stateString: String) {
        switch stateString.lowercased() {
        case "device":
            self = .authorized
        case "unauthorized":
            self = .unauthorized
        case "offline":
            self = .offline
        case "authorizing", "connecting":
            self = .authorizing
        case "recovery":
            self = .recovery
        case "bootloader", "fastboot":
            self = .bootloader
        case "sideload":
            self = .unknown("sideload")
        default:
            return nil
        }
    }

    public init(rawValue: String) {
        if let state = DeviceState(stateString: rawValue) {
            self = state
        } else {
            self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .authorized: return "device"
        case .unauthorized: return "unauthorized"
        case .offline: return "offline"
        case .authorizing: return "authorizing"
        case .recovery: return "recovery"
        case .bootloader: return "bootloader"
        case .unknown(let val): return val
        }
    }

    public var title: String {
        switch self {
        case .authorized: return "Authorized"
        case .unauthorized: return "Unauthorized"
        case .offline: return "Offline"
        case .authorizing: return "Authorizing…"
        case .recovery: return "Recovery Mode"
        case .bootloader: return "Bootloader Mode"
        case .unknown(let val): return "Unknown (\(val))"
        }
    }

    public var isUsableForMirroring: Bool {
        self == .authorized
    }
}

/// Transport medium used by the Android connection.
public enum ConnectionType: String, Hashable, Codable, Sendable {
    case usb
    case tcpip
}

/// A parsed Android device model.
public struct Device: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let serialNumber: String
    public let state: DeviceState
    public let modelName: String?
    public let productName: String?
    public let deviceCode: String?
    public let transportId: String?
    public let connectionType: ConnectionType

    public init(
        serialNumber: String,
        state: DeviceState,
        modelName: String? = nil,
        productName: String? = nil,
        deviceCode: String? = nil,
        transportId: String? = nil
    ) {
        self.id = serialNumber
        self.serialNumber = serialNumber
        self.state = state
        self.modelName = modelName
        self.productName = productName
        self.deviceCode = deviceCode
        self.transportId = transportId
        self.connectionType = serialNumber.contains(":") ? .tcpip : .usb
    }

    public var displayName: String {
        if let model = modelName, !model.isEmpty {
            return model.replacingOccurrences(of: "_", with: " ")
        }
        return serialNumber
    }

    public var secondaryInfo: String {
        var parts: [String] = []
        if let prod = productName, !prod.isEmpty {
            parts.append(prod)
        }
        parts.append(connectionType == .usb ? "USB" : "Wi-Fi / TCP")
        return parts.joined(separator: " • ")
    }
}
