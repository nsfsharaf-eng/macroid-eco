import Foundation
import Testing
@testable import MacdroidMirrorCore

final class MockProcessRunner: ProcessRunning, @unchecked Sendable {
    var responses: [String: ProcessResult] = [:]
    var recordedCalls: [(executable: String, arguments: [String])] = []

    func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval
    ) async throws -> ProcessResult {
        recordedCalls.append((executable: executablePath, arguments: arguments))
        if let result = responses[executablePath] {
            return result
        }
        return ProcessResult(exitCode: 0, standardOutput: "mock-tool version 1.0.0", standardError: "")
    }
}

@Suite("Dependency Service Tests")
struct DependencyServiceTests {

    @Test("System dependencies aggregation health check")
    func systemDependenciesAggregation() {
        var deps = SystemDependencies()
        #expect(!deps.allAvailable)

        deps.adb = .available(path: "/usr/local/bin/adb", version: "Android Debug Bridge version 1.0.41")
        #expect(!deps.allAvailable)

        deps.scrcpy = .available(path: "/usr/local/bin/scrcpy", version: "scrcpy 2.4")
        #expect(deps.allAvailable)

        deps.adb = .missing(searchedPaths: ["/usr/local/bin/adb"])
        #expect(!deps.allAvailable)
    }

    @Test("Dependency status descriptions and availability")
    func dependencyStatusText() {
        let available = DependencyStatus.available(path: "/bin/test", version: "1.2.3")
        #expect(available.statusText == "Installed (1.2.3)")
        #expect(available.path == "/bin/test")
        #expect(available.version == "1.2.3")
        #expect(available.isAvailable)

        let missing = DependencyStatus.missing(searchedPaths: ["/bin/test"])
        #expect(missing.statusText == "Not Found")
        #expect(missing.path == nil)
        #expect(missing.version == nil)
        #expect(!missing.isAvailable)

        let permDenied = DependencyStatus.permissionDenied(path: "/bin/locked")
        #expect(permDenied.statusText == "Permission Denied")
        #expect(!permDenied.isAvailable)

        let error = DependencyStatus.executionError(message: "Crash")
        #expect(error.statusText == "Error: Crash")
        #expect(!error.isAvailable)

        let checking = DependencyStatus.checking
        #expect(checking.statusText == "Checking…")
        #expect(!checking.isAvailable)
    }

    @Test("Locating non-existent custom path returns missing")
    func locateWithNonExistentCustomPathReturnsMissing() async {
        let service = DependencyService()
        let result = await service.locateAdb(customPath: "/nonexistent/custom/path/adb")

        if case .missing(let candidates) = result {
            #expect(candidates.contains("/nonexistent/custom/path/adb"))
        } else {
            Issue.record("Expected .missing for nonexistent binary path, got \(result)")
        }
    }
}
