import Foundation
import SwiftUI
import Combine

public enum NavigationSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case devices = "Devices"
    case settings = "Settings"
    case diagnostics = "Diagnostics"
    case troubleshooting = "Troubleshooting"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .devices: return "iphone.gen3"
        case .settings: return "gearshape"
        case .diagnostics: return "waveform.path.ecg"
        case .troubleshooting: return "wrench.and.screwdriver"
        }
    }
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

    public let sessionManager: MirroringSessionManager
    private let dependencyService: DependencyServicing
    private let deviceService: DeviceServicing
    private let preferencesService: PreferencesServicing

    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?

    public init(
        dependencyService: DependencyServicing = DependencyService(),
        deviceService: DeviceServicing = DeviceService(),
        sessionManager: MirroringSessionManager? = nil,
        preferencesService: PreferencesServicing = PreferencesService()
    ) {
        self.dependencyService = dependencyService
        self.deviceService = deviceService
        self.sessionManager = sessionManager ?? MirroringSessionManager()
        self.preferencesService = preferencesService
        self.config = preferencesService.loadConfig()

        // Forward session manager error updates
        self.sessionManager.$lastError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.showAlert(message: error)
            }
            .store(in: &cancellables)
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

        do {
            try sessionManager.startMirroring(
                device: device,
                scrcpyPath: scrcpyPath,
                adbPath: dependencies.adb.path,
                config: config
            )
        } catch {
            showAlert(message: error.localizedDescription)
        }
    }

    /// Stops the active mirroring session.
    public func stopMirroring() {
        sessionManager.stopMirroring()
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
}
