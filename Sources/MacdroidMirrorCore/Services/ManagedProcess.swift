import Foundation

/// Abstraction over a running subprocess to allow deterministic unit testing of session lifecycles.
public protocol ManagedProcess: AnyObject, Sendable {
    var isRunning: Bool { get }
    var processIdentifier: Int32 { get }
    var terminationStatus: Int32 { get }
    var arguments: [String]? { get set }
    var environment: [String: String]? { get set }
    var executableURL: URL? { get set }
    var standardOutput: Any? { get set }
    var standardError: Any? { get set }
    var terminationHandler: (@Sendable (ManagedProcess) -> Void)? { get set }

    func run() throws
    func terminate()
}

/// Factory protocol for instantiating subprocess instances.
public protocol ManagedProcessFactory: Sendable {
    func makeProcess() -> ManagedProcess
}

/// Production wrapper around Foundation.Process.
public final class SystemProcess: ManagedProcess, @unchecked Sendable {
    private let process: Process

    public init(process: Process = Process()) {
        self.process = process
    }

    public var isRunning: Bool {
        process.isRunning
    }

    public var processIdentifier: Int32 {
        process.processIdentifier
    }

    public var terminationStatus: Int32 {
        process.terminationStatus
    }

    public var arguments: [String]? {
        get { process.arguments }
        set { process.arguments = newValue }
    }

    public var environment: [String: String]? {
        get { process.environment }
        set { process.environment = newValue }
    }

    public var executableURL: URL? {
        get { process.executableURL }
        set { process.executableURL = newValue }
    }

    public var standardOutput: Any? {
        get { process.standardOutput }
        set { process.standardOutput = newValue }
    }

    public var standardError: Any? {
        get { process.standardError }
        set { process.standardError = newValue }
    }

    public var terminationHandler: (@Sendable (ManagedProcess) -> Void)? {
        get {
            return nil
        }
        set {
            if let handler = newValue {
                process.terminationHandler = { [weak self] _ in
                    guard let self = self else { return }
                    handler(self)
                }
            } else {
                process.terminationHandler = nil
            }
        }
    }

    public func run() throws {
        try process.run()
    }

    public func terminate() {
        process.terminate()
    }
}

/// Production process factory.
public struct SystemProcessFactory: ManagedProcessFactory {
    public init() {}

    public func makeProcess() -> ManagedProcess {
        SystemProcess()
    }
}
