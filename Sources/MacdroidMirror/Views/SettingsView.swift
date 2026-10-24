import SwiftUI
import MacdroidMirrorCore

public struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var localConfig: MirroringConfig
    @State private var hasUnsavedChanges: Bool = false
    @State private var showSavedBanner: Bool = false

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        _localConfig = State(initialValue: viewModel.config)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mirroring & Engine Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Configure video resolution, framerate, power saving, and tool binary paths.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if showSavedBanner {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.statusAuthorized)
                            Text("Saved")
                                .font(.caption)
                                .foregroundColor(AppTheme.statusAuthorized)
                        }
                        .transition(.opacity)
                    }

                    Button("Reset Defaults") {
                        viewModel.resetConfigToDefaults()
                        localConfig = viewModel.config
                        hasUnsavedChanges = false
                    }
                    .buttonStyle(.bordered)

                    Button("Save Changes") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.electricBlue)
                    .disabled(!hasUnsavedChanges)
                }

                // Video Performance Section
                performanceSection

                // Display & Behavior Section
                behaviorSection

                // Binary Paths Section
                binaryPathsSection
            }
            .padding(24)
        }
        .onChange(of: viewModel.config) { newConf in
            localConfig = newConf
        }
    }

    // MARK: - Sections

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Video & Performance")
                .font(.headline)

            VStack(spacing: 16) {
                // Max Resolution
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max Dimension (Resolution)")
                            .font(.body)
                        Text("Downscales phone video stream to reduce CPU and GPU usage on Intel Macs.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $localConfig.maxSize) {
                        Text("Native Resolution").tag(0)
                        Text("1080p Max").tag(1080)
                        Text("1440p Max").tag(1440)
                        Text("1920p Max").tag(1920)
                        Text("720p (Low Power)").tag(720)
                    }
                    .frame(width: 180)
                    .onChange(of: localConfig.maxSize) { _ in markDirty() }
                }

                Divider()

                // Max Framerate
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Target Framerate")
                            .font(.body)
                        Text("Limits rendering rate. 60 FPS is optimal for Intel UHD Graphics 630.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $localConfig.maxFps) {
                        Text("Native / Unlimited").tag(0)
                        Text("60 FPS (Recommended)").tag(60)
                        Text("30 FPS (Power Saver)").tag(30)
                        Text("90 FPS").tag(90)
                        Text("120 FPS").tag(120)
                    }
                    .frame(width: 180)
                    .onChange(of: localConfig.maxFps) { _ in markDirty() }
                }

                Divider()

                // Bitrate Stepper
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Video Bitrate: \(localConfig.bitRateMbps) Mbps")
                            .font(.body)
                        Text("Higher bitrate improves video clarity at the expense of higher USB bandwidth.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Stepper("", value: $localConfig.bitRateMbps, in: 2...32, step: 2)
                        .frame(width: 100)
                        .onChange(of: localConfig.bitRateMbps) { _ in markDirty() }
                }
            }
        }
        .cardStyled()
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Display & Session Behavior")
                .font(.headline)

            VStack(spacing: 14) {
                Toggle(isOn: $localConfig.stayAwake) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stay Awake")
                            .font(.body)
                        Text("Keeps the phone screen awake while mirroring is active.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: localConfig.stayAwake) { _ in markDirty() }

                Divider()

                Toggle(isOn: $localConfig.turnScreenOff) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Turn Physical Screen Off")
                            .font(.body)
                        Text("Turns off the physical device backlight during mirroring to save phone battery.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: localConfig.turnScreenOff) { _ in markDirty() }

                Divider()

                Toggle(isOn: $localConfig.forwardAudio) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Forward Audio")
                            .font(.body)
                        Text("Streams device audio directly to Mac output (requires Android 11+).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: localConfig.forwardAudio) { _ in markDirty() }

                Divider()

                Toggle(isOn: $localConfig.showTouches) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Finger Touches")
                            .font(.body)
                        Text("Displays physical touch dots on the mirrored screen.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: localConfig.showTouches) { _ in markDirty() }
            }
        }
        .cardStyled()
    }

    private var binaryPathsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tool Binary Overrides")
                .font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom ADB Executable Path")
                        .font(.body)
                    Text("Leave blank to use automatic search paths (/usr/local/bin, /opt/homebrew/bin, etc.).")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("/usr/local/bin/adb", text: $localConfig.customAdbPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: localConfig.customAdbPath) { _ in markDirty() }
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom scrcpy Executable Path")
                        .font(.body)
                    Text("Leave blank to use automatic search paths.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("/usr/local/bin/scrcpy", text: $localConfig.customScrcpyPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: localConfig.customScrcpyPath) { _ in markDirty() }
                }
            }
        }
        .cardStyled()
    }

    // MARK: - Helpers

    private func markDirty() {
        hasUnsavedChanges = true
    }

    private func save() {
        viewModel.updateConfig(localConfig)
        hasUnsavedChanges = false
        withAnimation {
            showSavedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSavedBanner = false
            }
        }
        Task {
            await viewModel.checkDependencies()
        }
    }
}
