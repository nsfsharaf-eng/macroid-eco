import Foundation
import SwiftUI
import Combine

public enum NavigationSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case devices = "Devices"
    case fileTransfer = "File Transfer"
    case settings = "Settings"
    case diagnostics = "Diagnostics"
    case troubleshooting = "Troubleshooting"
    case help = "Help & Guide"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .devices: return "iphone.gen3"
        case .fileTransfer: return "arrow.up.arrow.down.square"
        case .settings: return "gearshape"
        case .diagnostics: return "waveform.path.ecg"
        case .troubleshooting: return "wrench.and.screwdriver"
        case .help: return "questionmark.circle"
        }
    }
}

extension Notification.Name {
    public static let openNavigationSection = Notification.Name("com.macroideco.openNavigationSection")
}

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var selectedSection: NavigationSection = .overview
    @Published public var dependencies: SystemDependencies = SystemDependencies()
    @Published public var devices: [Device] = []
    @Published public var selectedDevice: Device?
    @Published public var isRefreshing: Bool = false
    @Published public var config: MirroringConfig
    @Published public var alertMessage: String?
    @Published public var showAlert: Bool = false

    // File transfer state
    @Published public var storageVolumes: [StorageVolume] = [.internalStorage]
    @Published public var selectedVolume: StorageVolume = .internalStorage
    @Published public var remoteFiles: [RemoteFileItem] = []
    @Published public var currentRemotePath: String = "/sdcard"
    @Published public var isLoadingFiles: Bool = false
    @Published public var transferStatusMessage: String?

    // Interactive Conflict Resolution State
    @Published public var activeConflict: FileConflictItem?
    @Published public var hasPendingBatchConflicts: Bool = false
    private var conflictContinuation: CheckedContinuation<(resolution: FileConflictResolution, applyToAll: Bool), Never>?

    // Wireless Debugging Assistant State
    @Published public var isConnectingWireless: Bool = false
    @Published public var detectedDeviceIP: String?
    @Published public var manualWirelessIP: String = ""
    @Published public var manualWirelessPort: String = "5555"
    @Published public var wirelessStatusMessage: String? = nil

    public let sessionManager: MirroringSessionManager
    public let fileTransferService: FileTransferServicing
    private let dependencyService: DependencyServicing
    private let deviceService: DeviceServicing
    private let preferencesService: PreferencesServicing

    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?

    public init(
        dependencyService: DependencyServicing = DependencyService(),
        deviceService: DeviceServicing = DeviceService(),
        sessionManager: MirroringSessionManager? = nil,
        fileTransferService: FileTransferServicing = FileTransferService(),
        preferencesService: PreferencesServicing = PreferencesService()
    ) {
        self.dependencyService = dependencyService
        self.deviceService = deviceService
        self.sessionManager = sessionManager ?? MirroringSessionManager()
        self.fileTransferService = fileTransferService
        self.preferencesService = preferencesService
        self.config = preferencesService.loadConfig()

        // Synchronize session manager state updates immediately to trigger UI re-renders
        self.sessionManager.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Forward session manager error updates
        self.sessionManager.$lastError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.showAlert(message: error)
            }
            .store(in: &cancellables)

        // Handle external section navigation (e.g. from macOS Menu Bar Help or system shortcuts)
        NotificationCenter.default.publisher(for: .openNavigationSection)
            .compactMap { notification -> NavigationSection? in
                if let raw = notification.userInfo?["section"] as? String {
                    return NavigationSection(rawValue: raw)
                }
                return notification.userInfo?["section"] as? NavigationSection
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] section in
                self?.selectedSection = section
            }
            .store(in: &cancellables)
    }

    /// Programmatically triggers navigation to a section from anywhere in the app or menu bar
    public static func navigate(to section: NavigationSection) {
        NotificationCenter.default.post(
            name: .openNavigationSection,
            object: nil,
            userInfo: ["section": section.rawValue]
        )
    }

    /// Checks ADB and scrcpy installation and version status.
    public func checkDependencies() async {
        let customAdb = config.customAdbPath.isEmpty ? nil : config.customAdbPath
        let customScrcpy = config.customScrcpyPath.isEmpty ? nil : config.customScrcpyPath
        let result = await dependencyService.checkAll(
            customAdbPath: customAdb,
            customScrcpyPath: customScrcpy
        )
        self.dependencies = result

        // If ADB is available, refresh the device list
        if result.adb.isAvailable {
            await refreshDevices()
        }
    }

    /// Scans for connected Android devices via ADB.
    public func refreshDevices() async {
        guard let adbPath = dependencies.adb.path else {
            devices = []
            selectedDevice = nil
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let fetchedDevices = try await deviceService.listDevices(adbPath: adbPath)
            self.devices = fetchedDevices

            // Preserve current selection if still connected, otherwise select first authorized or first available
            if let current = selectedDevice, let matching = fetchedDevices.first(where: { $0.id == current.id }) {
                self.selectedDevice = matching
            } else {
                self.selectedDevice = fetchedDevices.first(where: { $0.state.isUsableForMirroring }) ?? fetchedDevices.first
            }

            // Check if active session device was disconnected
            if let activeId = sessionManager.state.activeDeviceId {
                if !fetchedDevices.contains(where: { $0.id == activeId }) {
                    sessionManager.handleDeviceDisconnected(serial: activeId)
                }
            }
        } catch {
            self.showAlert(message: error.localizedDescription)
        }
    }

    /// Restarts the ADB daemon and refreshes connected devices.
    public func restartAdbServer() async {
        guard let adbPath = dependencies.adb.path else {
            showAlert(message: "Cannot restart ADB daemon: ADB executable path is not resolved.")
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await deviceService.restartServer(adbPath: adbPath)
            await refreshDevices()
        } catch {
            showAlert(message: "Failed to restart ADB daemon: \(error.localizedDescription)")
        }
    }

    /// Initiates a mirroring session for the selected device.
    public func startMirroring() {
        guard let device = selectedDevice else {
            showAlert(message: "No device selected. Please connect an Android phone with USB debugging enabled.")
            return
        }

        guard let scrcpyPath = dependencies.scrcpy.path else {
            showAlert(message: "scrcpy executable not found. Please install scrcpy or provide its path in Settings.")
            return
        }

        objectWillChange.send()
        do {
            try sessionManager.startMirroring(
                device: device,
                scrcpyPath: scrcpyPath,
                adbPath: dependencies.adb.path,
                config: config
            )
            objectWillChange.send()
        } catch {
            showAlert(message: error.localizedDescription)
            objectWillChange.send()
        }
    }

    /// Stops the active mirroring session.
    public func stopMirroring() {
        objectWillChange.send()
        sessionManager.stopMirroring()
        objectWillChange.send()
    }

    /// Updates mirroring configuration and persists it.
    public func updateConfig(_ newConfig: MirroringConfig) {
        self.config = newConfig
        preferencesService.saveConfig(newConfig)
    }

    /// Resets configuration to defaults and persists.
    public func resetConfigToDefaults() {
        let standard = preferencesService.resetToDefaults()
        self.config = standard
    }

    public func showAlert(message: String) {
        self.alertMessage = message
        self.showAlert = true
    }

    // MARK: - File Transfer Operations

    /// Scans and switches storage volumes (Internal storage vs Removable SD card)
    public func refreshStorageVolumes() async {
        guard let device = selectedDevice, device.state.isUsableForMirroring, let adbPath = dependencies.adb.path else {
            storageVolumes = [.internalStorage]
            selectedVolume = .internalStorage
            return
        }

        let volumes = await fileTransferService.detectStorageVolumes(adbPath: adbPath, serial: device.serialNumber)
        self.storageVolumes = volumes
        if !volumes.contains(where: { $0.rootPath == selectedVolume.rootPath }) {
            self.selectedVolume = volumes.first ?? .internalStorage
            self.currentRemotePath = self.selectedVolume.rootPath
        }
    }

    /// Selects a specific storage volume (Internal storage vs SD card)
    public func selectVolume(_ volume: StorageVolume) async {
        self.selectedVolume = volume
        self.currentRemotePath = volume.rootPath
        await loadRemoteFiles()
    }

    /// Navigates to a specific remote directory
    public func navigateToRemoteDirectory(_ path: String) async {
        let normalized = RemotePathModel(path, storageRoot: selectedVolume.rootPath).normalizedPath
        currentRemotePath = normalized
        await loadRemoteFiles()
    }

    /// Navigates to the parent directory
    public func navigateToParentDirectory() async {
        let model = RemotePathModel(currentRemotePath, storageRoot: selectedVolume.rootPath)
        guard !model.isRoot else { return }
        currentRemotePath = model.parentPath
        await loadRemoteFiles()
    }

    /// Loads items from current remote path on the selected device
    public func loadRemoteFiles() async {
        guard let device = selectedDevice, device.state.isUsableForMirroring else {
            remoteFiles = []
            return
        }

        guard let adbPath = dependencies.adb.path else {
            showAlert(message: "ADB path not found. Cannot browse files.")
            return
        }

        isLoadingFiles = true
        defer { isLoadingFiles = false }

        do {
            let files = try await fileTransferService.listRemoteFiles(
                adbPath: adbPath,
                serial: device.serialNumber,
                remotePath: currentRemotePath
            )
            self.remoteFiles = files
        } catch {
            self.remoteFiles = []
            self.showAlert(message: "Failed to load directory: \(error.localizedDescription)")
        }
    }

    // MARK: - Interactive Conflict Resolution

    /// Resolves the current active conflict prompt
    public func resolveConflict(with resolution: FileConflictResolution, applyToAll: Bool = false) {
        guard let continuation = conflictContinuation else { return }
        self.activeConflict = nil
        self.hasPendingBatchConflicts = false
        self.conflictContinuation = nil
        continuation.resume(returning: (resolution, applyToAll))
    }

    /// Pushes local files from Mac to Android with interactive duplicate conflict confirmation.
    public func pushFiles(fileURLs: [URL], destinationDirectory: String? = nil) async {
        guard let device = selectedDevice, device.state.isUsableForMirroring else {
            showAlert(message: "Please select an authorized device before transferring files.")
            return
        }

        guard let adbPath = dependencies.adb.path else {
            showAlert(message: "ADB executable not found.")
            return
        }

        guard !fileURLs.isEmpty else { return }

        let targetDir = RemotePathModel(destinationDirectory ?? currentRemotePath).normalizedPath

        isLoadingFiles = true
        defer { isLoadingFiles = false }

        var summary = BatchTransferSummary()
        var batchResolution: FileConflictResolution?
        let totalFiles = fileURLs.count

        for (index, fileURL) in fileURLs.enumerated() {
            if summary.isCancelled { break }

            let fileName = fileURL.lastPathComponent
            let remoteDestPath = "\(targetDir)/\(fileName)"
            transferStatusMessage = "Checking \(fileName)..."

            // Check actual existence on Android device
            let existsOnDevice = await fileTransferService.remoteFileExists(
                adbPath: adbPath,
                serial: device.serialNumber,
                remotePath: remoteDestPath
            )

            var shouldOverwrite = false

            if existsOnDevice {
                let chosenResolution: FileConflictResolution

                if let remembered = batchResolution {
                    chosenResolution = remembered
                } else {
                    // Prompt user interactively
                    let conflictItem = FileConflictItem(
                        localURL: fileURL,
                        fileName: fileName,
                        destinationDirectory: targetDir,
                        remoteExistingPath: remoteDestPath
                    )
                    self.activeConflict = conflictItem
                    self.hasPendingBatchConflicts = (totalFiles - index) > 1

                    let response = await withCheckedContinuation { continuation in
                        self.conflictContinuation = continuation
                    }

                    chosenResolution = response.resolution
                    if response.applyToAll {
                        batchResolution = chosenResolution
                    }
                }

                switch chosenResolution {
                case .cancel:
                    summary.isCancelled = true
                    break
                case .skip:
                    summary.skippedCount += 1
                    continue
                case .replace:
                    shouldOverwrite = true
                }
            }

            if summary.isCancelled { break }

            transferStatusMessage = "Pushing \(fileName)..."
            do {
                _ = try await fileTransferService.pushFile(
                    adbPath: adbPath,
                    serial: device.serialNumber,
                    localPath: fileURL.path,
                    targetDirectory: targetDir,
                    overwrite: shouldOverwrite
                )
                if shouldOverwrite {
                    summary.replacedCount += 1
                }
                summary.transferredCount += 1
            } catch {
                summary.failedCount += 1
                showAlert(message: "Failed to transfer \(fileName): \(error.localizedDescription)")
            }
        }

        transferStatusMessage = summary.userFeedbackDescription
        await loadRemoteFiles()
    }

    /// Pulls a remote Android file to the local Mac destination directory
    public func pullFileToMac(remoteFile: RemoteFileItem, destinationDirectory: URL? = nil) async {
        guard let device = selectedDevice, device.state.isUsableForMirroring else {
            showAlert(message: "Please select an authorized device.")
            return
        }

        guard !remoteFile.isDirectory else {
            showAlert(message: "Folder downloads are not supported directly. Please open the folder and select files.")
            return
        }

        guard let adbPath = dependencies.adb.path else {
            showAlert(message: "ADB executable not found.")
            return
        }

        let localDestDir = destinationDirectory?.path ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? NSTemporaryDirectory()

        isLoadingFiles = true
        transferStatusMessage = "Downloading \(remoteFile.name)..."
        defer {
            isLoadingFiles = false
        }

        do {
            let savedPath = try await fileTransferService.pullFile(
                adbPath: adbPath,
                serial: device.serialNumber,
                remotePath: remoteFile.fullPath,
                localTargetDirectory: localDestDir
            )
            transferStatusMessage = "Saved to: \(savedPath)"
        } catch {
            transferStatusMessage = "Download failed"
            showAlert(message: "Download failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Wireless Debugging Operations

    /// Automatically switches the selected USB device to TCP/IP mode and connects wirelessly over Wi-Fi
    public func enableWirelessDebugging(for device: Device) async {
        guard let adbPath = dependencies.adb.path else {
            showAlert(message: "ADB executable not found.")
            return
        }

        isConnectingWireless = true
        wirelessStatusMessage = "Detecting device Wi-Fi IP address..."
        defer { isConnectingWireless = false }

        // 1. Query Wi-Fi IP from device
        guard let ip = await deviceService.queryDeviceWifiIP(adbPath: adbPath, serial: device.serialNumber) else {
            wirelessStatusMessage = "Could not detect Wi-Fi IP. Ensure phone is on the same Wi-Fi as your Mac."
            showAlert(message: "Could not detect device Wi-Fi IP. Make sure Wi-Fi is enabled on the phone and connected to the same network as your Mac.")
            return
        }

        self.detectedDeviceIP = ip
        wirelessStatusMessage = "Enabling TCP/IP mode on port 5555..."

        do {
            // 2. Run adb tcpip 5555
            try await deviceService.enableTcpIp(adbPath: adbPath, serial: device.serialNumber, port: 5555)

            // Small delay to allow adbd to restart in TCP/IP mode
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            // 3. Connect wirelessly
            wirelessStatusMessage = "Connecting to \(ip):5555..."
            let target = try await deviceService.connectWireless(adbPath: adbPath, ipAddress: ip, port: 5555)

            wirelessStatusMessage = "Connected wirelessly to \(target)! You can now disconnect the USB cable."
            await refreshDevices()
        } catch {
            wirelessStatusMessage = "Wireless connection failed: \(error.localizedDescription)"
            showAlert(message: "Failed to establish wireless debugging: \(error.localizedDescription)")
        }
    }

    /// Manually connects to a specified IP and port
    public func connectManualWireless(ipAddress: String, port: Int = 5555) async {
        guard let adbPath = dependencies.adb.path else {
            showAlert(message: "ADB executable not found.")
            return
        }

        let cleanIP = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanIP.isEmpty else {
            showAlert(message: "Please enter a valid IP address.")
            return
        }

        isConnectingWireless = true
        wirelessStatusMessage = "Connecting to \(cleanIP):\(port)..."
        defer { isConnectingWireless = false }

        do {
            let target = try await deviceService.connectWireless(adbPath: adbPath, ipAddress: cleanIP, port: port)
            wirelessStatusMessage = "Connected to \(target)!"
            await refreshDevices()
        } catch {
            wirelessStatusMessage = "Connection failed: \(error.localizedDescription)"
            showAlert(message: "Failed to connect to \(cleanIP):\(port): \(error.localizedDescription)")
        }
    }

    /// Disconnects an active wireless device
    public func disconnectWireless(for device: Device) async {
        guard let adbPath = dependencies.adb.path else { return }

        let target = device.serialNumber
        let parts = target.components(separatedBy: ":")
        let ip = parts.first ?? target
        let port = parts.count > 1 ? (Int(parts[1]) ?? 5555) : 5555

        do {
            try await deviceService.disconnectWireless(adbPath: adbPath, ipAddress: ip, port: port)
            wirelessStatusMessage = "Disconnected from \(target)"
            await refreshDevices()
        } catch {
            showAlert(message: "Failed to disconnect: \(error.localizedDescription)")
        }
    }
}
