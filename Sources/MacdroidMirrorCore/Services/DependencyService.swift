import Foundation

public protocol DependencyServicing: Sendable {
    func locateAdb(customPath: String?) async -> DependencyStatus
    func locateScrcpy(customPath: String?) async -> DependencyStatus
    func checkAll(customAdbPath: String?, customScrcpyPath: String?) async -> SystemDependencies
}

public final class DependencyService: DependencyServicing, @unchecked Sendable {
    private let processRunner: ProcessRunning
    private let fileManager: FileManager

    public init(
        processRunner: ProcessRunning = SafeProcessRunner(),
        fileManager: FileManager = .default
    ) {
        self.processRunner = processRunner
        self.fileManager = fileManager
    }

    public static let standardAdbCandidatePaths: [String] = [
        "/usr/local/bin/adb",
        "/opt/homebrew/bin/adb",
        "/opt/local/bin/adb",
        (NSHomeDirectory() as NSString).appendingPathComponent("Library/Android/sdk/platform-tools/adb")
    ]

    public static let standardScrcpyCandidatePaths: [String] = [
        "/usr/local/bin/scrcpy",
        "/opt/homebrew/bin/scrcpy",
        "/opt/local/bin/scrcpy"
    ]

    public func locateAdb(customPath: String? = nil) async -> DependencyStatus {
        var candidatePaths: [String] = []

        if let custom = customPath, !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            candidatePaths.append(custom.trimmingCharacters(in: .whitespaces))
        }

        // Add PATH lookup candidates if resolved
        if let pathBinary = searchSystemPath(for: "adb") {
            if !candidatePaths.contains(pathBinary) {
                candidatePaths.append(pathBinary)
            }
        }

        for path in Self.standardAdbCandidatePaths {
            if !candidatePaths.contains(path) {
                candidatePaths.append(path)
            }
        }

        for path in candidatePaths {
            if fileManager.isExecutableFile(atPath: path) {
                let version = await queryVersion(executablePath: path, versionFlag: "version")
                return .available(path: path, version: version)
            } else if fileManager.fileExists(atPath: path) {
                return .permissionDenied(path: path)
            }
        }

        return .missing(searchedPaths: candidatePaths)
    }

    public func locateScrcpy(customPath: String? = nil) async -> DependencyStatus {
        var candidatePaths: [String] = []

        if let custom = customPath, !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            candidatePaths.append(custom.trimmingCharacters(in: .whitespaces))
        }

        if let pathBinary = searchSystemPath(for: "scrcpy") {
            if !candidatePaths.contains(pathBinary) {
                candidatePaths.append(pathBinary)
            }
        }

        for path in Self.standardScrcpyCandidatePaths {
            if !candidatePaths.contains(path) {
                candidatePaths.append(path)
            }
        }

        for path in candidatePaths {
            if fileManager.isExecutableFile(atPath: path) {
                let version = await queryVersion(executablePath: path, versionFlag: "--version")
                return .available(path: path, version: version)
            } else if fileManager.fileExists(atPath: path) {
                return .permissionDenied(path: path)
            }
        }

        return .missing(searchedPaths: candidatePaths)
    }

    public func checkAll(customAdbPath: String? = nil, customScrcpyPath: String? = nil) async -> SystemDependencies {
        async let adb = locateAdb(customPath: customAdbPath)
        async let scrcpy = locateScrcpy(customPath: customScrcpyPath)
        return await SystemDependencies(adb: adb, scrcpy: scrcpy)
    }

    // MARK: - Internal Helpers

    private func searchSystemPath(for toolName: String) -> String? {
        guard let pathEnv = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        let directories = pathEnv.split(separator: ":").map(String.init)
        for dir in directories {
            let fullPath = (dir as NSString).appendingPathComponent(toolName)
            if fileManager.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }

    private func queryVersion(executablePath: String, versionFlag: String) async -> String? {
        do {
            let result = try await processRunner.run(
                executablePath: executablePath,
                arguments: [versionFlag],
                environment: nil,
                timeout: 3.0
            )
            let combined = result.standardOutput.isEmpty ? result.standardError : result.standardOutput
            return parseFirstVersionLine(from: combined)
        } catch {
            return nil
        }
    }

    private func parseFirstVersionLine(from output: String) -> String? {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }
}
