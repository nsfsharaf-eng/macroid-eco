import Foundation

public protocol FileTransferServicing: Sendable {
    func detectStorageVolumes(adbPath: String, serial: String) async -> [StorageVolume]
    func listRemoteFiles(adbPath: String, serial: String, remotePath: String) async throws -> [RemoteFileItem]
    func pushFile(
        adbPath: String,
        serial: String,
        localPath: String,
        targetDirectory: String,
        overwrite: Bool
    ) async throws -> String
    func pullFile(
        adbPath: String,
        serial: String,
        remotePath: String,
        localTargetDirectory: String
    ) async throws -> String
    func remoteFileExists(adbPath: String, serial: String, remotePath: String) async -> Bool
    func remoteDirectoryExists(adbPath: String, serial: String, remotePath: String) async -> Bool
    func verifyRemoteFileSize(adbPath: String, serial: String, remotePath: String, expectedSize: Int64) async -> Bool
}

public final class FileTransferService: FileTransferServicing, @unchecked Sendable {
    private let runner: ProcessRunning
    private let fileManager: FileManager

    public init(runner: ProcessRunning = SafeProcessRunner(), fileManager: FileManager = .default) {
        self.runner = runner
        self.fileManager = fileManager
    }

    /// Shell-escapes a remote path with single quotes so Android `/system/bin/sh` receives it verbatim.
    public static func escapeShellArgument(_ arg: String) -> String {
        let escaped = arg.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    /// Detects all active storage volumes (Internal storage + external physical SD cards)
    public func detectStorageVolumes(adbPath: String, serial: String) async -> [StorageVolume] {
        var volumes: [StorageVolume] = [.internalStorage]

        // Inspect sm list-volumes public and /storage for removable SD card volumes across all Android vendors
        do {
            // 1. Check Android's StorageManager public volumes
            let smRes = try await runner.run(
                executablePath: adbPath,
                arguments: ["-s", serial, "shell", "sm list-volumes public 2>/dev/null"],
                environment: nil,
                timeout: 5
            )
            let smLines = smRes.standardOutput.components(separatedBy: .newlines)
            for line in smLines {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                if parts.count >= 3 && parts[1] == "mounted" {
                    let uuid = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let sdPath = "/storage/\(uuid)"
                    if !volumes.contains(where: { $0.rootPath == sdPath }) {
                        volumes.append(StorageVolume(name: "SD card (\(uuid))", rootPath: sdPath, isRemovable: true))
                    }
                }
            }

            // 2. Check /storage directory for mounted FAT/exFAT/NTFS volume UUIDs (e.g. 1A2B-3C4D)
            let res = try await runner.run(
                executablePath: adbPath,
                arguments: ["-s", serial, "shell", "ls -1 /storage 2>/dev/null"],
                environment: nil,
                timeout: 5
            )
            let lines = res.standardOutput.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.range(of: "^[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}$", options: .regularExpression) != nil {
                    let sdPath = "/storage/\(trimmed)"
                    if !volumes.contains(where: { $0.rootPath == sdPath }) {
                        volumes.append(StorageVolume(name: "SD card (\(trimmed))", rootPath: sdPath, isRemovable: true))
                    }
                }
            }
        } catch {
            // Fallback to internal storage if query fails
        }

        // 3. Add Entire Device root option for accessing all phone files
        volumes.append(.deviceRoot)

        return volumes
    }

    /// Lists files and directories inside a remote Android path using machine-readable:
    /// `find -L '<path>' -maxdepth 1 ! -path '<path>' -exec stat -L -c "%F|%s|%Y|%n" {} + 2>/dev/null`
    /// Note the `-L` flag dereferences symlinks like `/sdcard` -> `/storage/emulated/0`, exposing all root folders!
    public func listRemoteFiles(adbPath: String, serial: String, remotePath: String) async throws -> [RemoteFileItem] {
        let normalized = RemotePathModel(remotePath).normalizedPath

        // Verify remote directory actually exists
        let exists = await remoteDirectoryExists(adbPath: adbPath, serial: serial, remotePath: normalized)
        guard exists else {
            throw NSError(
                domain: "MacroidEco.FileTransfer",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Directory does not exist on device: \(normalized)"]
            )
        }

        let escaped = Self.escapeShellArgument(normalized)
        let findCmd = "find -L \(escaped) -maxdepth 1 ! -path \(escaped) -exec stat -L -c \"%F|%s|%Y|%n\" {} + 2>/dev/null"
        let result = try await runner.run(
            executablePath: adbPath,
            arguments: ["-s", serial, "shell", findCmd],
            environment: nil,
            timeout: 15
        )

        let output = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if output.isEmpty {
            return []
        }

        return parseStatOutput(output)
    }

    /// Pushes a local Mac file to an Android directory.
    public func pushFile(
        adbPath: String,
        serial: String,
        localPath: String,
        targetDirectory: String,
        overwrite: Bool = false
    ) async throws -> String {
        guard fileManager.fileExists(atPath: localPath) else {
            throw NSError(
                domain: "MacroidEco.FileTransfer",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Local file does not exist: \(localPath)"]
            )
        }

        let localAttributes = try? fileManager.attributesOfItem(atPath: localPath)
        let localFileSize = (localAttributes?[.size] as? NSNumber)?.int64Value ?? 0

        let normalizedTarget = RemotePathModel(targetDirectory).normalizedPath
        let originalName = URL(fileURLWithPath: localPath).lastPathComponent
        let destinationRemotePath = "\(normalizedTarget)/\(originalName)"

        // Check if destination exists
        let destinationExists = await remoteFileExists(adbPath: adbPath, serial: serial, remotePath: destinationRemotePath)
        if destinationExists && !overwrite {
            throw NSError(
                domain: "MacroidEco.FileTransfer",
                code: 409,
                userInfo: [NSLocalizedDescriptionKey: "File already exists at destination: \(destinationRemotePath)"]
            )
        }

        let pushResult = try await runner.run(
            executablePath: adbPath,
            arguments: ["-s", serial, "push", localPath, destinationRemotePath],
            environment: nil,
            timeout: 300
        )

        guard pushResult.exitCode == 0 else {
            let errorMsg = pushResult.standardError.isEmpty ? pushResult.standardOutput : pushResult.standardError
            throw NSError(
                domain: "MacroidEco.FileTransfer",
                code: Int(pushResult.exitCode),
                userInfo: [NSLocalizedDescriptionKey: "Failed to push \(originalName): \(errorMsg)"]
            )
        }

        // Post-transfer verification
        let verified = await verifyRemoteFileSize(
            adbPath: adbPath,
            serial: serial,
            remotePath: destinationRemotePath,
            expectedSize: localFileSize
        )

        guard verified else {
            throw NSError(
                domain: "MacroidEco.FileTransfer",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Post-transfer verification failed for \(destinationRemotePath): remote file does not exist or size mismatch."]
            )
        }

        return destinationRemotePath
    }

    /// Pulls a remote Android file to a local Mac directory.
    public func pullFile(
        adbPath: String,
        serial: String,
        remotePath: String,
        localTargetDirectory: String
    ) async throws -> String {
        let originalName = (remotePath as NSString).lastPathComponent
        let localDestination = (localTargetDirectory as NSString).appendingPathComponent(originalName)

        let pullResult = try await runner.run(
            executablePath: adbPath,
            arguments: ["-s", serial, "pull", remotePath, localDestination],
            environment: nil,
            timeout: 300
        )

        guard pullResult.exitCode == 0 else {
            let errorMsg = pullResult.standardError.isEmpty ? pushResultErrorMessage(pullResult) : pullResult.standardError
            throw NSError(
                domain: "MacroidEco.FileTransfer",
                code: Int(pullResult.exitCode),
                userInfo: [NSLocalizedDescriptionKey: "Failed to pull \(originalName): \(errorMsg)"]
            )
        }

        // Verify the file was created and is readable
        guard fileManager.fileExists(atPath: localDestination) else {
            throw NSError(
                domain: "MacroidEco.FileTransfer",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Downloaded file not found at destination: \(localDestination)"]
            )
        }

        return localDestination
    }

    private func pushResultErrorMessage(_ result: ProcessResult) -> String {
        result.standardError.isEmpty ? result.standardOutput : result.standardError
    }

    public func remoteFileExists(adbPath: String, serial: String, remotePath: String) async -> Bool {
        let escaped = Self.escapeShellArgument(remotePath)
        do {
            let res = try await runner.run(
                executablePath: adbPath,
                arguments: ["-s", serial, "shell", "test -e \(escaped)"],
                environment: nil,
                timeout: 5
            )
            return res.exitCode == 0
        } catch {
            return false
        }
    }

    public func remoteDirectoryExists(adbPath: String, serial: String, remotePath: String) async -> Bool {
        let escaped = Self.escapeShellArgument(remotePath)
        do {
            let res = try await runner.run(
                executablePath: adbPath,
                arguments: ["-s", serial, "shell", "test -d \(escaped)"],
                environment: nil,
                timeout: 5
            )
            return res.exitCode == 0
        } catch {
            return false
        }
    }

    public func verifyRemoteFileSize(adbPath: String, serial: String, remotePath: String, expectedSize: Int64) async -> Bool {
        let escaped = Self.escapeShellArgument(remotePath)
        do {
            let res = try await runner.run(
                executablePath: adbPath,
                arguments: ["-s", serial, "shell", "stat -c '%s' \(escaped)"],
                environment: nil,
                timeout: 5
            )
            guard res.exitCode == 0 else { return false }
            let sizeStr = res.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let remoteSize = Int64(sizeStr) else { return false }
            return remoteSize == expectedSize
        } catch {
            return false
        }
    }

    /// Parses machine-readable stat output format:
    /// `%F|%s|%Y|%n`
    public func parseStatOutput(_ rawOutput: String) -> [RemoteFileItem] {
        var items: [RemoteFileItem] = []
        let lines = rawOutput.components(separatedBy: .newlines)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let parts = trimmed.components(separatedBy: "|")
            guard parts.count >= 4 else { continue }

            let fileType = parts[0]
            let isDirectory = fileType.localizedCaseInsensitiveContains("directory")
            let size = Int64(parts[1]) ?? 0

            let epochSeconds = TimeInterval(parts[2]) ?? 0
            let date = Date(timeIntervalSince1970: epochSeconds)
            let dateString = dateFormatter.string(from: date)

            let fullPath = parts[3...].joined(separator: "|")
            let name = (fullPath as NSString).lastPathComponent

            if name == "." || name == ".." { continue }

            items.append(RemoteFileItem(
                name: name,
                fullPath: fullPath,
                isDirectory: isDirectory,
                sizeBytes: size,
                modificationDateString: dateString
            ))
        }

        return items.sorted {
            if $0.isDirectory != $1.isDirectory {
                return $0.isDirectory && !$1.isDirectory
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}
