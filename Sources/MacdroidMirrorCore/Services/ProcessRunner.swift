import Foundation

/// Safe result of an external process execution.
public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public var isSuccess: Bool {
        exitCode == 0
    }
}

/// Errors originating from process execution.
public enum ProcessRunnerError: LocalizedError, Sendable {
    case executableNotFound(path: String)
    case executionTimeout(timeoutSeconds: Double)
    case launchFailed(underlyingError: String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            return "Executable not found at path: \(path)"
        case .executionTimeout(let timeout):
            return "Process execution timed out after \(timeout) seconds."
        case .launchFailed(let underlying):
            return "Failed to launch process: \(underlying)"
        case .cancelled:
            return "Process execution was cancelled."
        }
    }
}

/// Protocol for running external commands safely without shell injection.
public protocol ProcessRunning: Sendable {
    func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval
    ) async throws -> ProcessResult
}

/// Production implementation of ProcessRunning using Foundation.Process.
public final class SafeProcessRunner: ProcessRunning {
    public init() {}

    public func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 10.0
    ) async throws -> ProcessResult {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw ProcessRunnerError.executableNotFound(path: executablePath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            var env = ProcessInfo.processInfo.environment
            if let customEnv = environment {
                env.merge(customEnv) { _, new in new }
            }
            // Ensure common paths exist in PATH for subprocesses
            let standardPaths = "/usr/local/bin:/opt/homebrew/bin:/opt/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            let existingPath = env["PATH"] ?? ""
            env["PATH"] = existingPath.isEmpty ? standardPaths : "\(existingPath):\(standardPaths)"
            process.environment = env

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            final class ExecutionState: @unchecked Sendable {
                let lock = NSLock()
                var hasCompleted = false
            }
            let state = ExecutionState()

            // Timeout timer
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler {
                state.lock.lock()
                defer { state.lock.unlock() }
                if !state.hasCompleted {
                    state.hasCompleted = true
                    if process.isRunning {
                        process.terminate()
                    }
                    continuation.resume(throwing: ProcessRunnerError.executionTimeout(timeoutSeconds: timeout))
                }
            }
            timer.resume()

            process.terminationHandler = { proc in
                state.lock.lock()
                defer { state.lock.unlock() }
                timer.cancel()
                if !state.hasCompleted {
                    state.hasCompleted = true
                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                    continuation.resume(returning: ProcessResult(
                        exitCode: proc.terminationStatus,
                        standardOutput: stdout,
                        standardError: stderr
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                state.lock.lock()
                defer { state.lock.unlock() }
                timer.cancel()
                if !state.hasCompleted {
                    state.hasCompleted = true
                    continuation.resume(throwing: ProcessRunnerError.launchFailed(underlyingError: error.localizedDescription))
                }
            }
        }
    }
}
