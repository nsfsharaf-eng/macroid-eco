import Foundation
import Testing
@testable import MacdroidMirrorCore

final class MockManagedProcess: ManagedProcess, @unchecked Sendable {
    var isRunning: Bool = false
    var processIdentifier: Int32 = 0
    var terminationStatus: Int32 = 0
    var arguments: [String]?
    var environment: [String: String]?
    var executableURL: URL?
    var standardOutput: Any?
    var standardError: Any?
    var terminationHandler: (@Sendable (ManagedProcess) -> Void)?

    var runCalled = false
    var terminateCalled = false
    var shouldFailRun: String?

    func run() throws {
        if let err = shouldFailRun {
            throw NSError(domain: "MockProcessError", code: 1, userInfo: [NSLocalizedDescriptionKey: err])
        }
        runCalled = true
        isRunning = true
    }

    func terminate() {
        terminateCalled = true
        isRunning = false
    }

    func simulateExit(code: Int32) {
        isRunning = false
        terminationStatus = code
        terminationHandler?(self)
    }
}

final class MockManagedProcessFactory: ManagedProcessFactory, @unchecked Sendable {
    var createdProcesses: [MockManagedProcess] = []
    var nextProcessToReturn: MockManagedProcess?

    func makeProcess() -> ManagedProcess {
        let proc = nextProcessToReturn ?? MockManagedProcess()
        createdProcesses.append(proc)
        return proc
    }
}

@Suite("Session Manager Tests")
@MainActor
struct SessionManagerTests {

    @Test("Start mirroring authorized device succeeds")
    func startMirroringAuthorizedDevice() throws {
        let factory = MockManagedProcessFactory()
        let manager = MirroringSessionManager(
            processFactory: factory,
            isExecutableCheck: { _ in true }
        )

        let device = Device(serialNumber: "DEVICE_AUTH", state: .authorized, modelName: "Pixel 7")
        try manager.startMirroring(
            device: device,
            scrcpyPath: "/usr/local/bin/scrcpy",
            adbPath: "/usr/local/bin/adb",
            config: .standard
        )

        #expect(manager.state.isActive)
        #expect(manager.state.activeDeviceId == "DEVICE_AUTH")
        #expect(factory.createdProcesses.count == 1)
        #expect(factory.createdProcesses[0].runCalled)
        #expect(factory.createdProcesses[0].arguments?.contains("--serial") == true)
        #expect(factory.createdProcesses[0].arguments?.contains("DEVICE_AUTH") == true)
    }

    @Test("Start mirroring unauthorized device throws error")
    func startMirroringUnauthorizedDeviceThrows() {
        let factory = MockManagedProcessFactory()
        let manager = MirroringSessionManager(
            processFactory: factory,
            isExecutableCheck: { _ in true }
        )

        let device = Device(serialNumber: "DEVICE_UNAUTH", state: .unauthorized)
        do {
            try manager.startMirroring(
                device: device,
                scrcpyPath: "/usr/local/bin/scrcpy",
                adbPath: nil,
                config: .standard
            )
            Issue.record("Expected deviceNotAuthorized error")
        } catch let err as SessionError {
            #expect(err == .deviceNotAuthorized(serial: "DEVICE_UNAUTH", state: .unauthorized))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Start mirroring offline device throws error")
    func startMirroringOfflineDeviceThrows() {
        let factory = MockManagedProcessFactory()
        let manager = MirroringSessionManager(
            processFactory: factory,
            isExecutableCheck: { _ in true }
        )

        let device = Device(serialNumber: "DEVICE_OFFLINE", state: .offline)
        do {
            try manager.startMirroring(
                device: device,
                scrcpyPath: "/usr/local/bin/scrcpy",
                adbPath: nil,
                config: .standard
            )
            Issue.record("Expected deviceNotAuthorized error")
        } catch let err as SessionError {
            #expect(err == .deviceNotAuthorized(serial: "DEVICE_OFFLINE", state: .offline))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Start mirroring missing scrcpy throws scrcpyNotFound")
    func startMirroringMissingScrcpyThrows() {
        let factory = MockManagedProcessFactory()
        let manager = MirroringSessionManager(
            processFactory: factory,
            isExecutableCheck: { _ in false }
        )

        let device = Device(serialNumber: "DEVICE_OK", state: .authorized)
        do {
            try manager.startMirroring(
                device: device,
                scrcpyPath: "/nonexistent/scrcpy",
                adbPath: nil,
                config: .standard
            )
            Issue.record("Expected scrcpyNotFound error")
        } catch let err as SessionError {
            #expect(err == .scrcpyNotFound(path: "/nonexistent/scrcpy"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Prevent duplicate concurrent mirroring sessions")
    func preventDuplicateConcurrentSessions() throws {
        let factory = MockManagedProcessFactory()
        let manager = MirroringSessionManager(
            processFactory: factory,
            isExecutableCheck: { _ in true }
        )

        let device1 = Device(serialNumber: "PHONE_1", state: .authorized)
        let device2 = Device(serialNumber: "PHONE_2", state: .authorized)

        try manager.startMirroring(
            device: device1,
            scrcpyPath: "/usr/local/bin/scrcpy",
            adbPath: nil,
            config: .standard
        )

        #expect(manager.state.isActive)

        // Attempting to mirror device 2 while device 1 is active must fail
        do {
            try manager.startMirroring(
                device: device2,
                scrcpyPath: "/usr/local/bin/scrcpy",
                adbPath: nil,
                config: .standard
            )
            Issue.record("Expected sessionAlreadyRunning error")
        } catch let err as SessionError {
            #expect(err == .sessionAlreadyRunning(serial: "PHONE_1"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Stop mirroring cleanly terminates process")
    func stopMirroringCleanlyTerminates() throws {
        let factory = MockManagedProcessFactory()
        let mockProc = MockManagedProcess()
        factory.nextProcessToReturn = mockProc

        let manager = MirroringSessionManager(
            processFactory: factory,
            isExecutableCheck: { _ in true }
        )

        let device = Device(serialNumber: "PHONE_STOP", state: .authorized)
        try manager.startMirroring(
            device: device,
            scrcpyPath: "/usr/local/bin/scrcpy",
            adbPath: nil,
            config: .standard
        )

        manager.stopMirroring()
        #expect(mockProc.terminateCalled)
        #expect(manager.state == .stopping(deviceId: "PHONE_STOP"))

        // Simulate SIGTERM exit
        manager.handleProcessTermination(process: mockProc, serial: "PHONE_STOP")
        #expect(manager.state == .terminated(deviceId: "PHONE_STOP", exitCode: 0, message: "Mirroring session ended"))
    }

    @Test("Process crash sets failed state with error")
    func processCrashSetsFailedState() throws {
        let factory = MockManagedProcessFactory()
        let mockProc = MockManagedProcess()
        factory.nextProcessToReturn = mockProc

        let manager = MirroringSessionManager(
            processFactory: factory,
            isExecutableCheck: { _ in true }
        )

        let device = Device(serialNumber: "PHONE_CRASH", state: .authorized)
        try manager.startMirroring(
            device: device,
            scrcpyPath: "/usr/local/bin/scrcpy",
            adbPath: nil,
            config: .standard
        )

        mockProc.terminationStatus = 1
        manager.handleProcessTermination(process: mockProc, serial: "PHONE_CRASH")

        #expect(!manager.state.isActive)
        if case .failed(let devId, _) = manager.state {
            #expect(devId == "PHONE_CRASH")
        } else {
            Issue.record("Expected failed state, got \(manager.state)")
        }
    }

    @Test("USB disconnection during mirroring terminates session")
    func usbDisconnectionTerminatesSession() throws {
        let factory = MockManagedProcessFactory()
        let mockProc = MockManagedProcess()
        factory.nextProcessToReturn = mockProc

        let manager = MirroringSessionManager(
            processFactory: factory,
            isExecutableCheck: { _ in true }
        )

        let device = Device(serialNumber: "PHONE_DISCONNECT", state: .authorized)
        try manager.startMirroring(
            device: device,
            scrcpyPath: "/usr/local/bin/scrcpy",
            adbPath: nil,
            config: .standard
        )

        #expect(manager.state.isActive)

        manager.handleDeviceDisconnected(serial: "PHONE_DISCONNECT")

        #expect(mockProc.terminateCalled)
        #expect(!manager.state.isActive)
        #expect(manager.lastError?.contains("disconnected") == true)
    }
}
