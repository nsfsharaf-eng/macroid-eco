import Foundation

/// Safe configuration parameters for the scrcpy mirroring process.
public struct MirroringConfig: Codable, Hashable, Sendable {
    public var maxSize: Int // e.g. 0 (original), 1080, 1440, 1920
    public var bitRateMbps: Int // e.g. 8 (default), 12, 16
    public var maxFps: Int // e.g. 0 (unlimited), 30, 60
    public var stayAwake: Bool
    public var showTouches: Bool
    public var turnScreenOff: Bool
    public var forwardAudio: Bool
    public var customAdbPath: String
    public var customScrcpyPath: String

    public init(
        maxSize: Int = 0,
        bitRateMbps: Int = 8,
        maxFps: Int = 60,
        stayAwake: Bool = true,
        showTouches: Bool = false,
        turnScreenOff: Bool = false,
        forwardAudio: Bool = true,
        customAdbPath: String = "",
        customScrcpyPath: String = ""
    ) {
        self.maxSize = maxSize
        self.bitRateMbps = bitRateMbps
        self.maxFps = maxFps
        self.stayAwake = stayAwake
        self.showTouches = showTouches
        self.turnScreenOff = turnScreenOff
        self.forwardAudio = forwardAudio
        self.customAdbPath = customAdbPath
        self.customScrcpyPath = customScrcpyPath
    }

    /// Default production configuration
    public static let standard = MirroringConfig()

    /// Builds a verified, sanitized array of command-line arguments for scrcpy.
    /// Does NOT perform string interpolation into a shell script; each flag is an isolated argument.
    public func buildArguments(serial: String) -> [String] {
        var args: [String] = ["--serial", serial]

        if maxSize > 0 {
            args.append(contentsOf: ["--max-size", String(maxSize)])
        }

        if bitRateMbps > 0 {
            args.append(contentsOf: ["--video-bit-rate", "\(bitRateMbps)M"])
        }

        if maxFps > 0 {
            args.append(contentsOf: ["--max-fps", String(maxFps)])
        }

        if stayAwake {
            args.append("--stay-awake")
        }

        if showTouches {
            args.append("--show-touches")
        }

        if turnScreenOff {
            args.append("--turn-screen-off")
        }

        if !forwardAudio {
            args.append("--no-audio")
        }

        return args
    }
}
