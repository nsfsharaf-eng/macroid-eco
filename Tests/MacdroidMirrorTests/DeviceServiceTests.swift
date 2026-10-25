import Foundation
import Testing
@testable import MacdroidMirrorCore

final class MockAdbProcessRunner: ProcessRunning, @unchecked Sendable {
    var cannedResults: [String: ProcessResult] = [:]
    var recordedCalls: [(executable: String, arguments: [String])] = []
    var shouldTimeout: Bool = false
    var shouldFailLaunch: String? = nil

    func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval
    ) async throws -> ProcessResult {
        recordedCalls.append((executable: executablePath, arguments: arguments))

        if shouldTimeout {
            throw ProcessRunnerError.executionTimeout(timeoutSeconds: timeout)
        }

        if let launchErr = shouldFailLaunch {
            throw ProcessRunnerError.launchFailed(underlyingError: launchErr)
        }

        let key = arguments.joined(separator: " ")
        if let result = cannedResults[key] {
            return result
        }

        return ProcessResult(exitCode: 0, standardOutput: "", standardError: "")
    }
}

@Suite("Device Service Tests")
struct DeviceServiceTests {

    @Test("List devices successfully parses real ADB stdout")
    func listDevicesSuccess() async throws {
        let mockRunner = MockAdbProcessRunner()
        mockRunner.cannedResults["devices -l"] = ProcessResult(
            exitCode: 0,
            standardOutput: """
            List of devices attached
            RFCNA012345            device usb:1-1 product:dm3qxxx model:SM_S918B device:dm3q transport_id:1
            0123456789ABCDEF       unauthorized usb:1-2 transport_id:2
            emulator-5554          offline transport_id:3
            """,
            standardError: ""
        )

        let service = DeviceService(
            processRunner: mockRunner,
            isExecutableCheck: { _ in true }
        )

        let devices = try await service.listDevices(adbPath: "/opt/local/bin/adb")

        #expect(devices.count == 3)

        // Device 1: Authorized Samsung S23 Ultra
        #expect(devices[0].serialNumber == "RFCNA012345")
        #expect(devices[0].state == .authorized)
        #expect(devices[0].displayName == "SM S918B")
        #expect(devices[0].productName == "dm3qxxx")
        #expect(devices[0].deviceCode == "dm3q")
        #expect(devices[0].transportId == "1")
        #expect(devices[0].isUsableForMirroring == true)

        // Device 2: Unauthorized
        #expect(devices[1].serialNumber == "0123456789ABCDEF")
        #expect(devices[1].state == .unauthorized)
        #expect(devices[1].isUsableForMirroring == false)

        // Device 3: Offline
        #expect(devices[2].serialNumber == "emulator-5554")
        #expect(devices[2].state == .offline)
        #expect(devices[2].isUsableForMirroring == false)
    }

    @Test("List devices throws adbNotFound when executable is missing")
    func listDevicesMissingAdb() async {
        let mockRunner = MockAdbProcessRunner()
        let service = DeviceService(
            processRunner: mockRunner,
            isExecutableCheck: { _ in false }
        )

        do {
            _ = try await service.listDevices(adbPath: "/nonexistent/adb")
            Issue.record("Expected adbNotFound error")
        } catch let error as DeviceServiceError {
            #expect(error == .adbNotFound(path: "/nonexistent/adb"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("List devices handles command timeout")
    func listDevicesTimeout() async {
        let mockRunner = MockAdbProcessRunner()
        mockRunner.shouldTimeout = true

        let service = DeviceService(
            processRunner: mockRunner,
            isExecutableCheck: { _ in true }
        )

        do {
            _ = try await service.listDevices(adbPath: "/opt/homebrew/bin/adb")
            Issue.record("Expected timedOut error")
        } catch let error as DeviceServiceError {
            #expect(error == .timedOut(timeoutSeconds: 6.0))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("List devices handles command failure with non-zero exit code")
    func listDevicesCommandFailure() async {
        let mockRunner = MockAdbProcessRunner()
        mockRunner.cannedResults["devices -l"] = ProcessResult(
            exitCode: 1,
            standardOutput: "",
            standardError: "error: protocol fault (couldn't read status): Connection reset by peer"
        )

        let service = DeviceService(
            processRunner: mockRunner,
            isExecutableCheck: { _ in true }
        )

        do {
            _ = try await service.listDevices(adbPath: "/usr/local/bin/adb")
            Issue.record("Expected commandFailed error")
        } catch let error as DeviceServiceError {
            #expect(error == .commandFailed(
                exitCode: 1,
                message: "error: protocol fault (couldn't read status): Connection reset by peer"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("List devices skips ADB daemon startup banners")
    func listDevicesDaemonStartupBanners() async throws {
        let mockRunner = MockAdbProcessRunner()
        mockRunner.cannedResults["devices -l"] = ProcessResult(
            exitCode: 0,
            standardOutput: """
            * daemon not running; starting now at tcp:5037
            * daemon started successfully
            List of devices attached
            28151JEHN12345         device product:husky model:Pixel_8_Pro device:husky transport_id:5
            """,
            standardError: ""
        )

        let service = DeviceService(
            processRunner: mockRunner,
            isExecutableCheck: { _ in true }
        )

        let devices = try await service.listDevices(adbPath: "/usr/local/bin/adb")
        #expect(devices.count == 1)
        #expect(devices[0].serialNumber == "28151JEHN12345")
        #expect(devices[0].displayName == "Pixel 8 Pro")
        #expect(devices[0].state == .authorized)
    }

    @Test("Restart server executes kill-server then start-server")
    func restartServerSuccess() async throws {
        let mockRunner = MockAdbProcessRunner()
        mockRunner.cannedResults["kill-server"] = ProcessResult(exitCode: 0, standardOutput: "", standardError: "")
        mockRunner.cannedResults["start-server"] = ProcessResult(
            exitCode: 0,
            standardOutput: "* daemon started successfully\n",
            standardError: ""
        )

        let service = DeviceService(
            processRunner: mockRunner,
            isExecutableCheck: { _ in true }
        )

        try await service.restartServer(adbPath: "/usr/local/bin/adb")

        #expect(mockRunner.recordedCalls.count == 2)
        #expect(mockRunner.recordedCalls[0].arguments == ["kill-server"])
        #expect(mockRunner.recordedCalls[1].arguments == ["start-server"])
    }

    @Test("Restart server reports error when start-server fails")
    func restartServerFailure() async {
        let mockRunner = MockAdbProcessRunner()
        mockRunner.cannedResults["kill-server"] = ProcessResult(exitCode: 0, standardOutput: "", standardError: "")
        mockRunner.cannedResults["start-server"] = ProcessResult(
            exitCode: 1,
            standardOutput: "",
            standardError: "cannot bind 'tcp:5037': Address already in use"
        )

        let service = DeviceService(
            processRunner: mockRunner,
            isExecutableCheck: { _ in true }
        )

        do {
            try await service.restartServer(adbPath: "/usr/local/bin/adb")
            Issue.record("Expected commandFailed error")
        } catch let error as DeviceServiceError {
            #expect(error == .commandFailed(
                exitCode: 1,
                message: "cannot bind 'tcp:5037': Address already in use"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
