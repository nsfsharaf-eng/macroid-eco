import Foundation
import Testing
@testable import MacdroidMirrorCore

@Suite("Mirroring Config Tests")
struct MirroringConfigTests {

    @Test("Verify standard configuration scrcpy arguments")
    func standardConfigArguments() {
        let config = MirroringConfig.standard
        let args = config.buildArguments(serial: "DEVICE123")

        #expect(args[0] == "--serial")
        #expect(args[1] == "DEVICE123")
        #expect(args.contains("--video-bit-rate"))
        #expect(args.contains("8M"))
        #expect(args.contains("--max-fps"))
        #expect(args.contains("60"))
        #expect(args.contains("--stay-awake"))
        #expect(!args.contains("--no-audio"))
        #expect(!args.contains("--turn-screen-off"))
        #expect(!args.contains("--show-touches"))
        #expect(!args.contains("--max-size"))
    }

    @Test("Verify custom configuration scrcpy arguments")
    func customConfigArguments() {
        var config = MirroringConfig()
        config.maxSize = 1080
        config.bitRateMbps = 16
        config.maxFps = 30
        config.stayAwake = false
        config.turnScreenOff = true
        config.showTouches = true
        config.forwardAudio = false

        let args = config.buildArguments(serial: "PIXEL_XYZ")

        #expect(args[0] == "--serial")
        #expect(args[1] == "PIXEL_XYZ")

        // Max Size
        #expect(args.contains("--max-size"))
        if let idx = args.firstIndex(of: "--max-size") {
            #expect(args[idx + 1] == "1080")
        }

        // Bitrate
        #expect(args.contains("--video-bit-rate"))
        if let idx = args.firstIndex(of: "--video-bit-rate") {
            #expect(args[idx + 1] == "16M")
        }

        // FPS
        #expect(args.contains("--max-fps"))
        if let idx = args.firstIndex(of: "--max-fps") {
            #expect(args[idx + 1] == "30")
        }

        #expect(!args.contains("--stay-awake"))
        #expect(args.contains("--turn-screen-off"))
        #expect(args.contains("--show-touches"))
        #expect(args.contains("--no-audio"))
    }

    @Test("Unlimited FPS omits max-fps argument")
    func unlimitedFpsOmitsMaxFpsArgument() {
        var config = MirroringConfig()
        config.maxFps = 0
        let args = config.buildArguments(serial: "DEVICE_TEST")
        #expect(!args.contains("--max-fps"))
    }

    @Test("Native resolution omits max-size argument")
    func nativeResolutionOmitsMaxSizeArgument() {
        var config = MirroringConfig()
        config.maxSize = 0
        let args = config.buildArguments(serial: "DEVICE_TEST")
        #expect(!args.contains("--max-size"))
    }

    @Test("Codable serialization roundtrip")
    func codableRoundTrip() throws {
        var config = MirroringConfig()
        config.maxSize = 1440
        config.bitRateMbps = 12
        config.customAdbPath = "/opt/custom/bin/adb"
        config.customScrcpyPath = "/opt/custom/bin/scrcpy"

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(MirroringConfig.self, from: data)

        #expect(decoded.maxSize == 1440)
        #expect(decoded.bitRateMbps == 12)
        #expect(decoded.customAdbPath == "/opt/custom/bin/adb")
        #expect(decoded.customScrcpyPath == "/opt/custom/bin/scrcpy")
        #expect(decoded == config)
    }
}
