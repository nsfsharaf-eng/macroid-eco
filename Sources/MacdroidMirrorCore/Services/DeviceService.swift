import Foundation

/// Errors originating from the device discovery service.
public enum DeviceServiceError: LocalizedError, Sendable, Equatable {
    case adbNotFound(path: String)
    case commandFailed(exitCode: Int32, message: String)
    case parseError(rawOutput: String)
    case timedOut(timeoutSeconds: Double)
    case daemonStartFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case .adbNotFound(let path):
            return "ADB executable not found at '\(path)'. Please verify Android platform-tools installation or check path in Settings."
        case .commandFailed(let exitCode, let message):
            return "ADB command failed (exit code \(exitCode)): \(message)"
        case .parseError(let output):
            return "Failed to parse ADB output: \(output)"
        case .timedOut(let timeout):
            return "ADB command timed out after \(Int(timeout)) seconds while querying connected devices."
        case .daemonStartFailed(let message):
            return "Failed to start ADB daemon: \(message)"
        }
    }
}

/// Service protocol for Android device discovery.
public protocol DeviceServicing: Sendable {
    func listDevices(adbPath: String) async throws -> [Device]
    func restartServer(adbPath: String) async throws
    func enableTcpIp(adbPath: String, serial: String, port: Int) async throws
    func connectWireless(adbPath: String, ipAddress: String, port: Int) async throws -> String
    func disconnectWireless(adbPath: String, ipAddress: String, port: Int) async throws
    func queryDeviceWifiIP(adbPath: String, serial: String) async -> String?
}

/// Production implementation of DeviceServicing using ADB.
public final class DeviceService: DeviceServicing, @unchecked Sendable {
    private let processRunner: ProcessRunning
    private let isExecutableCheck: @Sendable (String) -> Bool

    public init(
        processRunner: ProcessRunning = SafeProcessRunner(),
        isExecutableCheck: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.processRunner = processRunner
        self.isExecutableCheck = isExecutableCheck
    }

    /// Queries `adb devices -l` and returns parsed Device models.
    public func listDevices(adbPath: String) async throws -> [Device] {
        guard isExecutableCheck(adbPath) else {
            throw DeviceServiceError.adbNotFound(path: adbPath)
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
                let combined = err.isEmpty ? result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines) : err

                if combined.contains("daemon not running") && combined.contains("failed") {
                    throw DeviceServiceError.daemonStartFailed(message: combined)
                }

                throw DeviceServiceError.commandFailed(
                    exitCode: result.exitCode,
                    message: combined.isEmpty ? "Unknown ADB error" : combined
                )
            }

            return Self.parseDeviceList(output: result.standardOutput)
        } catch let err as ProcessRunnerError {
            switch err {
            case .executableNotFound:
                throw DeviceServiceError.adbNotFound(path: adbPath)
            case .executionTimeout(let timeout):
                throw DeviceServiceError.timedOut(timeoutSeconds: timeout)
            case .launchFailed(let message):
                throw DeviceServiceError.commandFailed(exitCode: -1, message: message)
            case .cancelled:
                return []
            }
        }
    }

    /// Restarts the local ADB daemon to recover from stuck connections.
    public func restartServer(adbPath: String) async throws {
        guard isExecutableCheck(adbPath) else {
            throw DeviceServiceError.adbNotFound(path: adbPath)
        }

        // Kill existing daemon
        _ = try? await processRunner.run(
            executablePath: adbPath,
            arguments: ["kill-server"],
            environment: nil,
            timeout: 5.0
        )

        // Start fresh daemon
        let startResult = try await processRunner.run(
            executablePath: adbPath,
            arguments: ["start-server"],
            environment: nil,
            timeout: 8.0
        )

        guard startResult.isSuccess else {
            let err = startResult.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            throw DeviceServiceError.commandFailed(
                exitCode: startResult.exitCode,
                message: err.isEmpty ? "Failed to restart ADB server" : err
            )
        }
    }

    /// Restarts ADB daemon in TCPIP mode on the specified port (default 5555) for wireless debugging
    public func enableTcpIp(adbPath: String, serial: String, port: Int = 5555) async throws {
        guard isExecutableCheck(adbPath) else {
            throw DeviceServiceError.adbNotFound(path: adbPath)
        }

        let res = try await processRunner.run(
            executablePath: adbPath,
            arguments: ["-s", serial, "tcpip", String(port)],
            environment: nil,
            timeout: 10.0
        )

        guard res.isSuccess else {
            let msg = res.standardError.isEmpty ? res.standardOutput : res.standardError
            throw DeviceServiceError.commandFailed(exitCode: res.exitCode, message: "Failed to enable TCP/IP mode: \(msg)")
        }
    }

    /// Connects to a device wirelessly via `adb connect <ip>:<port>`
    public func connectWireless(adbPath: String, ipAddress: String, port: Int = 5555) async throws -> String {
        guard isExecutableCheck(adbPath) else {
            throw DeviceServiceError.adbNotFound(path: adbPath)
        }

        let target = "\(ipAddress):\(port)"
        let res = try await processRunner.run(
            executablePath: adbPath,
            arguments: ["connect", target],
            environment: nil,
            timeout: 10.0
        )

        let output = res.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !res.isSuccess || output.contains("failed") || output.contains("unable") {
            let err = res.standardError.isEmpty ? output : res.standardError
            throw DeviceServiceError.commandFailed(exitCode: res.exitCode, message: "Failed to connect to \(target): \(err)")
        }

        return target
    }

    /// Disconnects a wireless ADB session via `adb disconnect <ip>:<port>`
    public func disconnectWireless(adbPath: String, ipAddress: String, port: Int = 5555) async throws {
        guard isExecutableCheck(adbPath) else {
            throw DeviceServiceError.adbNotFound(path: adbPath)
        }

        let target = "\(ipAddress):\(port)"
        _ = try? await processRunner.run(
            executablePath: adbPath,
            arguments: ["disconnect", target],
            environment: nil,
            timeout: 5.0
        )
    }

    /// Queries the device's local Wi-Fi IPv4 address via ADB shell
    public func queryDeviceWifiIP(adbPath: String, serial: String) async -> String? {
        do {
            let res = try await processRunner.run(
                executablePath: adbPath,
                arguments: ["-s", serial, "shell", "ip -o -4 addr show"],
                environment: nil,
                timeout: 5.0
            )
            guard res.isSuccess else { return nil }
            let lines = res.standardOutput.components(separatedBy: .newlines)
            
            // First pass: Prioritize standard Wi-Fi interfaces (wlan0, wlan1, wlan2, wifi0, etc.)
            for line in lines {
                if line.contains("wlan") || line.contains("wifi") {
                    if let ip = Self.extractIPv4(from: line) {
                        return ip
                    }
                }
            }

            // Fallback pass: Any valid non-cellular, non-loopback network interface
            for line in lines {
                if !line.contains("lo") && !line.contains("rmnet") && !line.contains("p2p") && !line.contains("dummy") {
                    if let ip = Self.extractIPv4(from: line) {
                        return ip
                    }
                }
            }

            return nil
        } catch {
            return nil
        }
    }

    /// Extracts IPv4 address from a standard `ip -o -4 addr show` output line
    public static func extractIPv4(from line: String) -> String? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard let inetIdx = parts.firstIndex(of: "inet"), inetIdx + 1 < parts.count else { return nil }
        let cidr = String(parts[inetIdx + 1])
        guard let ip = cidr.components(separatedBy: "/").first, !ip.isEmpty, ip != "127.0.0.1" else { return nil }
        return ip
    }

    /// Parses the raw stdout of `adb devices -l` into strongly-typed `Device` models.
    /// Handles daemon startup text, header lines, and device key-value metadata.
    public static func parseDeviceList(output: String) -> [Device] {
        var devices: [Device] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines, daemon logs, version mismatches, and header lines
            if trimmed.isEmpty ||
                trimmed.hasPrefix("*") ||
                trimmed.hasPrefix("List of devices") ||
                trimmed.hasPrefix("adb server version") ||
                trimmed.hasPrefix("cannot connect to daemon") {
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
    /// `HT66S0200001           no permissions (user in plugdev group...); see [url] usb:1-2`
    public static func parseDeviceLine(_ line: String) -> Device? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Handle "no permissions" multi-word state
        if trimmed.contains("no permissions") {
            let tokens = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard let first = tokens.first else { return nil }
            return Device(serialNumber: first, state: .noPermissions)
        }

        let tokens = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
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
