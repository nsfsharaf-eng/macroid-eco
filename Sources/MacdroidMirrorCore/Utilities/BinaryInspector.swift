import Foundation

/// Architecture classification of a Mach-O binary.
public enum BinaryArchitecture: String, Codable, Sendable, Equatable {
    case x86_64 = "Intel (x86_64)"
    case arm64 = "Apple Silicon (arm64)"
    case universal = "Universal (x86_64 + arm64)"
    case nonMachO = "Non-Mach-O Executable / Script"
    case unknown = "Unknown Architecture"
}

/// Capabilities and supported options discovered for scrcpy.
public struct ScrcpyCapabilities: Sendable, Equatable {
    public let rawVersion: String
    public let majorVersion: Int
    public let minorVersion: Int
    public let architecture: BinaryArchitecture
    public let supportsAudioForwarding: Bool
    public let supportsVideoBitRateFlag: Bool
    public let supportsTurnScreenOff: Bool
    public let supportsStayAwake: Bool

    public init(
        rawVersion: String,
        majorVersion: Int,
        minorVersion: Int,
        architecture: BinaryArchitecture
    ) {
        self.rawVersion = rawVersion
        self.majorVersion = majorVersion
        self.minorVersion = minorVersion
        self.architecture = architecture
        // Audio forwarding was introduced in scrcpy v2.0
        self.supportsAudioForwarding = majorVersion >= 2
        // --video-bit-rate replaced -b in scrcpy v2.0 (v1.x uses -b)
        self.supportsVideoBitRateFlag = majorVersion >= 2
        self.supportsTurnScreenOff = true
        self.supportsStayAwake = true
    }
}

/// Inspects executable headers and version outputs to verify compatibility.
public enum BinaryInspector {

    /// Inspects the Mach-O header of a file to determine its CPU architecture.
    public static func inspectArchitecture(atPath path: String) -> BinaryArchitecture {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            return .unknown
        }
        defer { try? fileHandle.close() }

        guard let headerData = try? fileHandle.read(upToCount: 8), headerData.count >= 4 else {
            return .unknown
        }

        // Read magic 32-bit uint
        let magic = headerData.withUnsafeBytes { $0.load(as: UInt32.self) }

        // Mach-O Magic Numbers:
        // 0xfeedfacf: MH_MAGIC_64 (host endian)
        // 0xcffaedfe: MH_CIGAM_64 (swapped endian)
        // 0xcafebabe: FAT_MAGIC (Universal binary)
        // 0xbebafeca: FAT_CIGAM (Universal binary swapped)
        if magic == 0xcafebabe || magic == 0xbebafeca {
            return .universal
        }

        if magic == 0xfeedfacf || magic == 0xcffaedfe {
            // Read CPU type at offset 4
            guard headerData.count >= 8 else { return .unknown }
            let cpuType = headerData.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }
            // CPU_TYPE_X86_64 = 0x01000007 (or swapped 0x07000001)
            // CPU_TYPE_ARM64  = 0x0100000c (or swapped 0x0c000001)
            if cpuType == 0x01000007 || cpuType == 0x07000001 {
                return .x86_64
            } else if cpuType == 0x0100000c || cpuType == 0x0c000001 {
                return .arm64
            }
            return .x86_64 // Standard 64-bit Mach-O fallback
        }

        // Check if file starts with shebang "#!" (shell wrapper or python script)
        if headerData.count >= 2, headerData[0] == 0x23, headerData[1] == 0x21 {
            return .nonMachO
        }

        return .unknown
    }

    /// Parses the version string returned by `scrcpy --version`.
    /// Example output: "scrcpy 2.4 <https://github.com/Genymobile/scrcpy>"
    public static func parseScrcpyVersion(_ rawOutput: String, architecture: BinaryArchitecture = .unknown) -> ScrcpyCapabilities {
        var major = 2
        var minor = 0

        let lines = rawOutput.components(separatedBy: .newlines)
        for line in lines {
            let lower = line.lowercased()
            if lower.contains("scrcpy") {
                let parts = line.split(whereSeparator: { $0.isWhitespace })
                for part in parts {
                    let versionTokens = part.split(separator: ".")
                    if versionTokens.count >= 2,
                       let m = Int(versionTokens[0]),
                       let n = Int(versionTokens[1].prefix(while: { $0.isNumber })) {
                        major = m
                        minor = n
                        break
                    }
                }
            }
        }

        return ScrcpyCapabilities(
            rawVersion: rawOutput.trimmingCharacters(in: .whitespacesAndNewlines),
            majorVersion: major,
            minorVersion: minor,
            architecture: architecture
        )
    }

    /// Parses the version string returned by `adb version`.
    /// Example output: "Android Debug Bridge version 1.0.41\nVersion 34.0.5-10900870"
    public static func parseAdbVersion(_ rawOutput: String) -> String {
        let lines = rawOutput.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("Android Debug Bridge version") || trimmed.contains("Version") {
                return trimmed
            }
        }
        return rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
