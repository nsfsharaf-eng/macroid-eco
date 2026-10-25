import Foundation
import Testing
@testable import MacdroidMirrorCore

@Suite("Binary Inspector Tests")
struct BinaryInspectorTests {

    @Test("Parse scrcpy 2.4 capabilities with audio forwarding")
    func parseScrcpy24Capabilities() {
        let raw = """
        scrcpy 2.4 <https://github.com/Genymobile/scrcpy>
        dependencies:
         - SDL 2.30.2
         - libavcodec 60.31.102
         - libavformat 60.16.100
         - libavutil 58.29.100
        """

        let caps = BinaryInspector.parseScrcpyVersion(raw, architecture: .x86_64)
        #expect(caps.majorVersion == 2)
        #expect(caps.minorVersion == 4)
        #expect(caps.supportsAudioForwarding == true)
        #expect(caps.supportsVideoBitRateFlag == true)
        #expect(caps.supportsStayAwake == true)
        #expect(caps.supportsTurnScreenOff == true)
        #expect(caps.architecture == .x86_64)
    }

    @Test("Parse scrcpy 1.25 legacy capabilities without audio forwarding")
    func parseScrcpy125Capabilities() {
        let raw = "scrcpy 1.25 <https://github.com/Genymobile/scrcpy>"
        let caps = BinaryInspector.parseScrcpyVersion(raw, architecture: .x86_64)

        #expect(caps.majorVersion == 1)
        #expect(caps.minorVersion == 25)
        #expect(caps.supportsAudioForwarding == false)
        #expect(caps.supportsVideoBitRateFlag == false)
    }

    @Test("Parse scrcpy 4.0 current release capabilities")
    func parseScrcpy40Capabilities() {
        let raw = """
        scrcpy 4.0 <https://github.com/Genymobile/scrcpy>
        Dependencies (compiled / linked):
         - SDL: 3.4.16 / 3.4.18
         - libavcodec: 63.1.101 / 63.1.102
         - libavformat: 63.1.101 / 63.1.102
         - libavutil: 61.1.101 / 61.1.102
         - libusb: - / 1.0.30
        """

        let caps = BinaryInspector.parseScrcpyVersion(raw, architecture: .x86_64)
        #expect(caps.majorVersion == 4)
        #expect(caps.minorVersion == 0)
        #expect(caps.supportsAudioForwarding == true)
        #expect(caps.supportsVideoBitRateFlag == true)
        #expect(caps.supportsStayAwake == true)
        #expect(caps.supportsTurnScreenOff == true)
        #expect(caps.architecture == .x86_64)
    }

    @Test("Parse ADB version output")
    func parseAdbVersionOutput() {
        let raw = """
        Android Debug Bridge version 1.0.41
        Version 36.0.2-14143358
        Installed as /opt/local/bin/adb
        """

        let version = BinaryInspector.parseAdbVersion(raw)
        #expect(version.contains("Android Debug Bridge version 1.0.41"))
    }

    @Test("Inspect architecture for universal binary header")
    func inspectUniversalBinaryHeader() throws {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_fat_macho_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // FAT_MAGIC: 0xcafebabe
        let fatMagic: UInt32 = 0xCAFE_BABE
        var bigEndianMagic = fatMagic.bigEndian
        let data = withUnsafeBytes(of: &bigEndianMagic) { Data($0) }
        try data.write(to: tempFile)

        let arch = BinaryInspector.inspectArchitecture(atPath: tempFile.path)
        #expect(arch == .universal)
    }

    @Test("Inspect architecture for Intel x86_64 Mach-O header")
    func inspectIntelX8664Header() throws {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_x86_64_macho_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        var magic: UInt32 = 0xFEED_FACF // MH_MAGIC_64
        var cpuType: UInt32 = 0x0100_0007 // CPU_TYPE_X86_64
        var header = Data()
        withUnsafeBytes(of: &magic) { header.append(contentsOf: $0) }
        withUnsafeBytes(of: &cpuType) { header.append(contentsOf: $0) }
        try header.write(to: tempFile)

        let arch = BinaryInspector.inspectArchitecture(atPath: tempFile.path)
        #expect(arch == .x86_64)
    }

    @Test("Inspect architecture for script shebang")
    func inspectScriptShebang() throws {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_script_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let scriptContent = "#!/usr/bin/env bash\necho 'hello'\n"
        try scriptContent.write(to: tempFile, atomically: true, encoding: .utf8)

        let arch = BinaryInspector.inspectArchitecture(atPath: tempFile.path)
        #expect(arch == .nonMachO)
    }
}
