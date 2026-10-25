import Testing
@testable import MacdroidMirrorCore

@Suite("Device Parsing Tests")
struct DeviceParsingTests {

    @Test("Parse empty device list output")
    func parseEmptyDeviceList() {
        let output = """
        List of devices attached

        """
        let devices = DeviceService.parseDeviceList(output: output)
        #expect(devices.isEmpty)
    }

    @Test("Parse daemon startup output and valid device")
    func parseDaemonStartupOutput() {
        let output = """
        * daemon not running; starting now at tcp:5037
        * daemon started successfully
        List of devices attached
        RF8M123456X\tdevice usb:1-1 product:starqlteue model:SM_G960U1 device:starqlte transport_id:1
        """
        let devices = DeviceService.parseDeviceList(output: output)
        #expect(devices.count == 1)

        let device = devices[0]
        #expect(device.serialNumber == "RF8M123456X")
        #expect(device.state == .authorized)
        #expect(device.state.isUsableForMirroring)
        #expect(device.modelName == "SM_G960U1")
        #expect(device.displayName == "SM G960U1")
        #expect(device.productName == "starqlteue")
        #expect(device.deviceCode == "starqlte")
        #expect(device.transportId == "1")
        #expect(device.connectionType == .usb)
    }

    @Test("Parse multiple devices with varying states including offline and unauthorized")
    func parseMultipleDevicesWithDifferentStates() {
        let output = """
        List of devices attached
        0123456789ABCDEF       unauthorized usb:1-2 transport_id:2
        emulator-5554          offline transport_id:3
        192.168.1.105:5555     device product:oriole model:Pixel_6 device:oriole transport_id:4
        recovery_device_1      recovery transport_id:5
        bootloader_dev         bootloader transport_id:6
        sideload_device        sideload transport_id:7
        HT66S0200001           no permissions (user in plugdev group...); see [http://developer.android.com] usb:1-2
        """
        let devices = DeviceService.parseDeviceList(output: output)
        #expect(devices.count == 7)

        // Device 1: Unauthorized USB
        #expect(devices[0].serialNumber == "0123456789ABCDEF")
        #expect(devices[0].state == .unauthorized)
        #expect(!devices[0].state.isUsableForMirroring)
        #expect(devices[0].connectionType == .usb)
        #expect(devices[0].state.title == "Unauthorized")

        // Device 2: Offline emulator
        #expect(devices[1].serialNumber == "emulator-5554")
        #expect(devices[1].state == .offline)
        #expect(!devices[1].state.isUsableForMirroring)

        // Device 3: Authorized Wi-Fi TCP/IP device
        #expect(devices[2].serialNumber == "192.168.1.105:5555")
        #expect(devices[2].state == .authorized)
        #expect(devices[2].state.isUsableForMirroring)
        #expect(devices[2].connectionType == .tcpip)
        #expect(devices[2].displayName == "Pixel 6")

        // Device 4: Recovery
        #expect(devices[3].state == .recovery)
        #expect(!devices[3].state.isUsableForMirroring)

        // Device 5: Bootloader
        #expect(devices[4].state == .bootloader)
        #expect(!devices[4].state.isUsableForMirroring)

        // Device 6: Sideload
        #expect(devices[5].state == .sideload)
        #expect(!devices[5].state.isUsableForMirroring)

        // Device 7: No Permissions
        #expect(devices[6].serialNumber == "HT66S0200001")
        #expect(devices[6].state == .noPermissions)
        #expect(!devices[6].state.isUsableForMirroring)
    }

    @Test("Parse CRLF formatted output")
    func parseCrlfLineEndings() {
        let output = "List of devices attached\r\nSERIAL_CRLF\tdevice product:test model:Test_Phone device:test transport_id:1\r\n"
        let devices = DeviceService.parseDeviceList(output: output)
        #expect(devices.count == 1)
        #expect(devices[0].serialNumber == "SERIAL_CRLF")
        #expect(devices[0].displayName == "Test Phone")
        #expect(devices[0].state == .authorized)
    }

    @Test("Parse malformed or empty lines safely")
    func parseMalformedOrEmptyLines() {
        let output = """
        random invalid header line
        singleTokenOnly
        
           
        """
        let devices = DeviceService.parseDeviceList(output: output)
        #expect(devices.isEmpty)
    }

    @Test("Verify device state raw value mappings")
    func deviceStateRawValueMapping() {
        #expect(DeviceState(stateString: "device") == .authorized)
        #expect(DeviceState(stateString: "unauthorized") == .unauthorized)
        #expect(DeviceState(stateString: "offline") == .offline)
        #expect(DeviceState(stateString: "authorizing") == .authorizing)
        #expect(DeviceState(stateString: "recovery") == .recovery)
        #expect(DeviceState(stateString: "bootloader") == .bootloader)
        #expect(DeviceState(stateString: "sideload") == .sideload)
        #expect(DeviceState(stateString: "no permissions") == .noPermissions)

        #expect(DeviceState(stateString: "sideload")?.rawValue == "sideload")
        #expect(DeviceState(stateString: "device")?.rawValue == "device")
        #expect(DeviceState(stateString: "invalid") == nil)
    }
}
