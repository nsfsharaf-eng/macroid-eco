import Foundation
import AppKit

/// Errors that can occur during session lifecycle.
public enum SessionError: LocalizedError, Sendable {
    case deviceNotAuthorized(serial: String, state: DeviceState)
    case scrcpyNotFound(path: String)
    case sessionAlreadyRunning(serial: String)
    case processLaunchFailed(message: String)
    case deviceDisconnected(serial: String)

    public var errorDescription: String? {
        switch self {
        case .deviceNotAuthorized(let serial, let state):
            return "Device '\(serial)' cannot be mirrored in its current state: \(state.title). Please enable USB debugging and accept the authorization prompt on the phone screen."
        case .scrcpyNotFound(let path):
            return "scrcpy binary not found at '\(path)'. Please install scrcpy via Homebrew or specify its location in Settings."
        case .sessionAlreadyRunning(let serial):
            return "A mirroring session is already active for device '\(serial)'. Stop the active session before starting a new one."
        case .processLaunchFailed(let message):
            return "Failed to launch scrcpy: \(message)"
        case .deviceDisconnected(let serial):
            return "Mirroring session ended: device '\(serial)' was disconnected."
        }
    }
}

/// Interface for managing scrcpy mirroring subprocesses.
@MainActor
public protocol MirroringSessionManaging: AnyObject {
    var state: SessionState { get }
    func startMirroring(device: Device, scrcpyPath: String, adbPath: String?, config: MirroringConfig) throws
    func stopMirroring()
}

/// Production implementation of MirroringSessionManaging.
@MainActor
public final class MirroringSessionManager: ObservableObject, MirroringSessionManaging {
    @Published public private(set) var state: SessionState = .idle
    @Published public private(set) var lastError: String?

    private var activeProcess: Process?
    private var activeDeviceSerial: String?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var terminationObserver: NSObjectProtocol?

    public init() {
        setupTerminationCleanup()
    }

    deinit {
        // Stop process immediately if manager is deallocated
        if let proc = activeProcess, proc.isRunning {
            proc.terminate()
        }
        if let obs = terminationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    /// Starts mirroring an authorized device using scrcpy.
    public func startMirroring(
        device: Device,
        scrcpyPath: String,
        adbPath: String?,
        config: MirroringConfig
    ) throws {
        // Prevent duplicate concurrent sessions
        if state.isActive {
            if let activeId = state.activeDeviceId {
                throw SessionError.sessionAlreadyRunning(serial: activeId)
            }
        }

        // Verify device authorization
        guard device.state.isUsableForMirroring else {
            throw SessionError.deviceNotAuthorized(serial: device.serialNumber, state: device.state)
        }

        // Verify scrcpy executable
        guard FileManager.default.isExecutableFile(atPath: scrcpyPath) else {
            throw SessionError.scrcpyNotFound(path: scrcpyPath)
        }

        state = .starting(deviceId: device.serialNumber)
        lastError = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: scrcpyPath)

        // Build explicit arguments - NO shell interpolation
        let arguments = config.buildArguments(serial: device.serialNumber)
        process.arguments = arguments

        // Build clean environment with explicit ADB path if known
        var env = ProcessInfo.processInfo.environment
        let standardPaths = "/usr/local/bin:/opt/homebrew/bin:/opt/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        let existingPath = env["PATH"] ?? ""
        env["PATH"] = existingPath.isEmpty ? standardPaths : "\(existingPath):\(standardPaths)"

        if let adb = adbPath, FileManager.default.isExecutableFile(atPath: adb) {
            env["ADB"] = adb
            let adbDir = (adb as NSString).deletingLastPathComponent
            env["PATH"] = "\(adbDir):\(env["PATH"] ?? "")"
        }
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        self.stdoutPipe = stdout
        self.stderrPipe = stderr
        self.activeProcess = process
        self.activeDeviceSerial = device.serialNumber

        let serial = device.serialNumber

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.handleProcessTermination(process: proc, serial: serial)
            }
        }

        do {
            try process.run()
            self.state = .active(deviceId: device.serialNumber, pid: process.processIdentifier, startTime: Date())
        } catch {
            self.state = .failed(deviceId: device.serialNumber, error: error.localizedDescription)
            self.lastError = error.localizedDescription
            self.cleanupActiveProcess()
            throw SessionError.processLaunchFailed(message: error.localizedDescription)
        }
    }

    /// Stops the active mirroring session cleanly.
    public func stopMirroring() {
        guard let process = activeProcess, process.isRunning else {
            if let serial = activeDeviceSerial {
                state = .terminated(deviceId: serial, exitCode: 0, message: "Session closed")
            } else {
                state = .idle
            }
            cleanupActiveProcess()
            return
        }

        if let serial = activeDeviceSerial {
            state = .stopping(deviceId: serial)
        }

        // Clean termination via SIGTERM
        process.terminate()

        // Wait briefly on a background task; if still alive, send SIGKILL
        let pid = process.processIdentifier
        Task.detached(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            var status: Int32 = 0
            if waitpid(pid, &status, WNOHANG) == 0 {
                // Process is still running, force terminate
                kill(pid, SIGKILL)
            }
        }
    }

    /// Notifies the session manager that a device was disconnected from USB.
    public func handleDeviceDisconnected(serial: String) {
        if activeDeviceSerial == serial && state.isActive {
            stopMirroring()
            state = .failed(deviceId: serial, error: "Device disconnected from USB")
            lastError = "Device \(serial) disconnected from USB."
        }
    }

    // MARK: - Private Helpers

    private func handleProcessTermination(process: Process, serial: String) {
        let code = process.terminationStatus
        var errorMessage: String?

        if let stderr = stderrPipe {
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let output = output, !output.isEmpty {
                errorMessage = output
            }
        }

        if code == 0 || code == 15 /* SIGTERM */ {
            state = .terminated(deviceId: serial, exitCode: code, message: "Mirroring session ended")
        } else {
            let msg = errorMessage ?? "Process exited with code \(code)"
            state = .failed(deviceId: serial, error: msg)
            lastError = msg
        }

        cleanupActiveProcess()
    }

    private func cleanupActiveProcess() {
        activeProcess = nil
        activeDeviceSerial = nil
        stdoutPipe = nil
        stderrPipe = nil
    }

    private func setupTerminationCleanup() {
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.activeProcess?.terminate()
            }
        }
    }
}
