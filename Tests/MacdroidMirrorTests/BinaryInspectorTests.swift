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

    @Test("Parse ADB version output")
    func parseAdbVersionOutput() {
        let raw = """
        Android Debug Bridge version 1.0.41
        Version 34.0.5-10900870
        Installed as /usr/local/bin/adb
        """

        let version = BinaryInspector.parseAdbVersion(raw)
        #expect(version.contains("Android Debug Bridge version 1.0.41"))
    }

    @Test("Inspect architecture for universal binary header")
    func inspectUniversalBinaryHeader() throws {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_fat_macho_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // FAT_MAGIC: 0xcafebabe (big endian)
        var fatMagic: UInt32 = UInt32(0xcafebabe).bigEndian
        let data = Data(bytes: &fatMagic, count: 4)
        try data.write(to: tempFile)

        let arch = BinaryInspector.inspectArchitecture(atPath: tempFile.path)
        #expect(arch == .universal)
    }

    @Test("Inspect architecture for Intel x86_64 Mach-O header")
    func inspectIntelX8664Header() throws {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_x86_64_macho_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        var header = Data()
        var magic: UInt32 = 0xfeedfacf // MH_MAGIC_64
        var cpuType: UInt32 = 0x01000007 // CPU_TYPE_X86_64
        header.append(Data(bytes: &magic, count: 4))
        header.append(Data(bytes: &cpuType, count: 4))
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
