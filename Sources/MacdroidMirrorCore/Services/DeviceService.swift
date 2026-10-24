import Foundation

/// Errors originating from the device discovery service.
public enum DeviceServiceError: LocalizedError, Sendable {
    case adbNotFound
    case commandFailed(exitCode: Int32, message: String)
    case parseError(rawOutput: String)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .adbNotFound:
            return "ADB executable not found. Please install Android platform-tools or specify the custom path in Settings."
        case .commandFailed(let exitCode, let message):
            return "ADB command failed with exit code \(exitCode): \(message)"
        case .parseError(let output):
            return "Failed to parse ADB output: \(output)"
        case .timedOut:
            return "ADB command timed out while querying connected devices."
        }
    }
}

/// Service protocol for Android device discovery.
public protocol DeviceServicing: Sendable {
    func listDevices(adbPath: String) async throws -> [Device]
}

/// Production implementation of DeviceServicing using ADB.
public final class DeviceService: DeviceServicing {
    private let processRunner: ProcessRunning

    public init(processRunner: ProcessRunning = SafeProcessRunner()) {
        self.processRunner = processRunner
    }

    /// Queries `adb devices -l` and returns parsed Device models.
    public func listDevices(adbPath: String) async throws -> [Device] {
        guard FileManager.default.isExecutableFile(atPath: adbPath) else {
            throw DeviceServiceError.adbNotFound
        }

        do {
            let result = try await processRunner.run(
                executablePath: adbPath,
                arguments: ["devices", "-l"],
                environment: nil,
                timeout: 6.0
            )

            guard result.isSuccess else {
                let err = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
                throw DeviceServiceError.commandFailed(
                    exitCode: result.exitCode,
                    message: err.isEmpty ? "Unknown ADB error" : err
                )
            }

            return Self.parseDeviceList(output: result.standardOutput)
        } catch let err as ProcessRunnerError {
            switch err {
            case .executableNotFound:
                throw DeviceServiceError.adbNotFound
            case .executionTimeout:
                throw DeviceServiceError.timedOut
            case .launchFailed(let message):
                throw DeviceServiceError.commandFailed(exitCode: -1, message: message)
            case .cancelled:
                return []
            }
        }
    }

    /// Parses the raw stdout of `adb devices -l` into strongly-typed `Device` models.
    /// Handles daemon startup text, header lines, and device key-value metadata.
    public static func parseDeviceList(output: String) -> [Device] {
        var devices: [Device] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines, daemon logs, and the header line
            if trimmed.isEmpty ||
                trimmed.hasPrefix("*") ||
                trimmed.hasPrefix("List of devices") {
                continue
            }

            if let device = parseDeviceLine(trimmed) {
                devices.append(device)
            }
        }

        return devices
    }

    /// Parses a single line from `adb devices -l`.
    /// Example lines:
    /// `RF8M123456X            device usb:1-1 product:starqlteue model:SM_G960U1 device:starqlte transport_id:1`
    /// `0123456789ABCDEF       unauthorized usb:1-2 transport_id:3`
    /// `emulator-5554          offline transport_id:4`
    public static func parseDeviceLine(_ line: String) -> Device? {
        let tokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard tokens.count >= 2 else { return nil }

        let serial = tokens[0]
        let stateString = tokens[1]
        guard let state = DeviceState(stateString: stateString) else { return nil }

        var modelName: String?
        var productName: String?
        var deviceCode: String?
        var transportId: String?

        // Parse key:value metadata tokens (from index 2 onward)
        for token in tokens.dropFirst(2) {
            if let colonIndex = token.firstIndex(of: ":") {
                let key = String(token[..<colonIndex])
                let value = String(token[token.index(after: colonIndex)...])

                switch key {
                case "model":
                    modelName = value
                case "product":
                    productName = value
                case "device":
                    deviceCode = value
                case "transport_id":
                    transportId = value
                default:
                    break
                }
            }
        }

        return Device(
            serialNumber: serial,
            state: state,
            modelName: modelName,
            productName: productName,
            deviceCode: deviceCode,
            transportId: transportId
        )
    }
}
