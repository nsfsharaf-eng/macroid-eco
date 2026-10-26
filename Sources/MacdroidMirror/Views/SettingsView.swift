import SwiftUI
import AppKit
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
                HStack(alignment: .center) {
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
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.statusAuthorized)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppTheme.statusAuthorized.opacity(0.12)))
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
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max Dimension (Resolution)")
                            .font(.body)
                            .fontWeight(.medium)
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
                    .labelsHidden()
                    .frame(width: 200)
                    .onChange(of: localConfig.maxSize) { _ in markDirty() }
                }

                Divider()

                // Max Framerate
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Target Framerate")
                            .font(.body)
                            .fontWeight(.medium)
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
                    .labelsHidden()
                    .frame(width: 200)
                    .onChange(of: localConfig.maxFps) { _ in markDirty() }
                }

                Divider()

                // Bitrate Stepper
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Video Bitrate")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Higher bitrate improves video clarity at the expense of higher USB bandwidth.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        Text("\(localConfig.bitRateMbps) Mbps")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.electricBlue)
                            .frame(width: 80, alignment: .trailing)

                        Stepper("", value: $localConfig.bitRateMbps, in: 2...32, step: 2)
                            .labelsHidden()
                    }
                    .frame(width: 200, alignment: .trailing)
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

            VStack(spacing: 16) {
                // Stay Awake
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stay Awake")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Keeps the phone screen awake while mirroring is active.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $localConfig.stayAwake)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: localConfig.stayAwake) { _ in markDirty() }
                }

                Divider()

                // Turn Physical Screen Off
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Turn Physical Screen Off")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Turns off physical phone screen backlight during mirroring to save battery.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $localConfig.turnScreenOff)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: localConfig.turnScreenOff) { _ in markDirty() }
                }

                Divider()

                // Forward Audio
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Forward Audio")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Streams device audio directly to Mac speakers/headphones (requires Android 11+).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $localConfig.forwardAudio)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: localConfig.forwardAudio) { _ in markDirty() }
                }

                Divider()

                // Show Finger Touches
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Finger Touches")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Displays visual touch indicators on the mirrored screen.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $localConfig.showTouches)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: localConfig.showTouches) { _ in markDirty() }
                }
            }
        }
        .cardStyled()
    }

    private var binaryPathsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tool Binary Overrides")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                // ADB Path
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom ADB Executable Path")
                        .font(.body)
                        .fontWeight(.medium)
                    Text("Leave blank to use automatic search paths (/usr/local/bin, /opt/local/bin, /opt/homebrew/bin).")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        TextField("/opt/local/bin/adb", text: $localConfig.customAdbPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: localConfig.customAdbPath) { _ in markDirty() }

                        Button("Browse...") {
                            browseForExecutable { selectedPath in
                                localConfig.customAdbPath = selectedPath
                                markDirty()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Divider()

                // scrcpy Path
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom scrcpy Executable Path")
                        .font(.body)
                        .fontWeight(.medium)
                    Text("Leave blank to use automatic search paths.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        TextField("/opt/local/bin/scrcpy", text: $localConfig.customScrcpyPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: localConfig.customScrcpyPath) { _ in markDirty() }

                        Button("Browse...") {
                            browseForExecutable { selectedPath in
                                localConfig.customScrcpyPath = selectedPath
                                markDirty()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .cardStyled()
    }

    // MARK: - Helpers

    private func markDirty() {
        hasUnsavedChanges = true
    }

    private func browseForExecutable(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = "Select Binary"

        if panel.runModal() == .OK, let url = panel.url {
            completion(url.path)
        }
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
