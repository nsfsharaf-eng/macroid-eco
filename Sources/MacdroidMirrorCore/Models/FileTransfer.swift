import Foundation

/// Represents a distinct storage volume on the Android device (Internal storage or external SD card)
public struct StorageVolume: Identifiable, Hashable, Sendable {
    public var id: String { rootPath }
    public let name: String
    public let rootPath: String
    public let isRemovable: Bool

    public init(name: String, rootPath: String, isRemovable: Bool = false) {
        self.name = name
        self.rootPath = rootPath
        self.isRemovable = isRemovable
    }

    public static let internalStorage = StorageVolume(name: "Internal storage", rootPath: "/sdcard", isRemovable: false)
    public static let deviceRoot = StorageVolume(name: "Entire Device (/)", rootPath: "/", isRemovable: false)
}

/// Represents a remote item on an Android device's filesystem.
public struct RemoteFileItem: Identifiable, Hashable, Sendable {
    public var id: String { fullPath }
    public let name: String
    public let fullPath: String
    public let isDirectory: Bool
    public let sizeBytes: Int64
    public let modificationDateString: String

    public init(
        name: String,
        fullPath: String,
        isDirectory: Bool,
        sizeBytes: Int64 = 0,
        modificationDateString: String = ""
    ) {
        self.name = name
        self.fullPath = fullPath
        self.isDirectory = isDirectory
        self.sizeBytes = sizeBytes
        self.modificationDateString = modificationDateString
    }

    public var formattedSize: String {
        if isDirectory { return "Directory" }
        return ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

/// Normalized representation of remote directory navigation path
public struct RemotePathModel: Equatable, Hashable, Sendable {
    public let normalizedPath: String
    public let storageRoot: String

    public init(_ path: String, storageRoot: String = "/sdcard") {
        var clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            clean = storageRoot
        }
        // Normalize multiple slashes
        while clean.contains("//") {
            clean = clean.replacingOccurrences(of: "//", with: "/")
        }
        // Remove trailing slash unless root "/"
        if clean.count > 1 && clean.hasSuffix("/") {
            clean = String(clean.dropLast())
        }
        self.normalizedPath = clean
        self.storageRoot = storageRoot
    }

    public var isRoot: Bool {
        if normalizedPath == "/" || normalizedPath == storageRoot {
            return true
        }
        return storageRoot == "/sdcard" && (normalizedPath == "/sdcard" || normalizedPath == "/storage/emulated/0" || normalizedPath == "/storage/self/primary")
    }

    public var parentPath: String {
        guard !isRoot else { return normalizedPath }
        let parent = (normalizedPath as NSString).deletingLastPathComponent
        return parent.isEmpty ? storageRoot : parent
    }

    public var displayName: String {
        if isRoot {
            if storageRoot == "/" { return "Device Root (/)" }
            return (normalizedPath.contains("emulated") || normalizedPath == "/sdcard" || normalizedPath == "/storage/self/primary") ? "Internal storage" : "SD card"
        }
        return (normalizedPath as NSString).lastPathComponent
    }

    public var friendlyDisplayPath: String {
        if isRoot {
            return displayName
        }
        let rootName: String
        if storageRoot == "/" {
            rootName = "Device Root"
        } else if storageRoot == "/sdcard" || storageRoot.contains("emulated") || storageRoot.contains("self/primary") {
            rootName = "Internal storage"
        } else {
            rootName = "SD card"
        }
        var relative = normalizedPath
        if relative.hasPrefix(storageRoot) {
            relative = String(relative.dropFirst(storageRoot.count))
        }
        if relative.hasPrefix("/") {
            relative = String(relative.dropFirst())
        }
        return relative.isEmpty ? rootName : "\(rootName)/\(relative)"
    }

    public var breadcrumbs: [(title: String, path: String)] {
        if isRoot {
            return [(displayName, normalizedPath)]
        }

        var crumbs: [(title: String, path: String)] = []
        let rootName: String
        if storageRoot == "/" {
            rootName = "Device Root"
        } else if storageRoot == "/sdcard" || storageRoot.contains("emulated") || storageRoot.contains("self/primary") {
            rootName = "Internal storage"
        } else {
            rootName = "SD card"
        }

        crumbs.append((rootName, storageRoot))

        var relative = normalizedPath
        if relative.hasPrefix(storageRoot) {
            relative = String(relative.dropFirst(storageRoot.count))
        }

        let components = relative.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        var currentAccum = storageRoot == "/" ? "" : storageRoot

        for comp in components {
            currentAccum += "/\(comp)"
            crumbs.append((comp, currentAccum))
        }

        return crumbs
    }
}

/// Transfer direction
public enum FileTransferDirection: String, Sendable {
    case toAndroid = "Mac to Android"
    case toMac = "Android to Mac"
}

/// User's resolution choice when a conflict is encountered
public enum FileConflictResolution: Sendable, Equatable {
    case replace
    case skip
    case cancel
}

/// Information needed to present an interactive conflict confirmation dialog
public struct FileConflictItem: Identifiable, Sendable, Equatable {
    public var id: String { fileName }
    public let localURL: URL
    public let fileName: String
    public let destinationDirectory: String
    public let remoteExistingPath: String

    public init(
        localURL: URL,
        fileName: String,
        destinationDirectory: String,
        remoteExistingPath: String
    ) {
        self.localURL = localURL
        self.fileName = fileName
        self.destinationDirectory = destinationDirectory
        self.remoteExistingPath = remoteExistingPath
    }
}

/// Summary report returned after a batch transfer
public struct BatchTransferSummary: Sendable, Equatable {
    public var transferredCount: Int = 0
    public var replacedCount: Int = 0
    public var skippedCount: Int = 0
    public var failedCount: Int = 0
    public var isCancelled: Bool = false

    public init(
        transferredCount: Int = 0,
        replacedCount: Int = 0,
        skippedCount: Int = 0,
        failedCount: Int = 0,
        isCancelled: Bool = false
    ) {
        self.transferredCount = transferredCount
        self.replacedCount = replacedCount
        self.skippedCount = skippedCount
        self.failedCount = failedCount
        self.isCancelled = isCancelled
    }

    public var userFeedbackDescription: String {
        if isCancelled {
            return "Transfer cancelled"
        }
        var parts: [String] = []
        let regularSuccess = transferredCount - replacedCount
        if regularSuccess > 0 {
            parts.append("\(regularSuccess) transferred")
        }
        if replacedCount > 0 {
            parts.append("\(replacedCount) replaced")
        }
        if skippedCount > 0 {
            parts.append("\(skippedCount) skipped")
        }
        if failedCount > 0 {
            parts.append("\(failedCount) failed")
        }
        return parts.isEmpty ? "No files transferred" : parts.joined(separator: ", ")
    }
}
