import SwiftUI
import MacdroidMirrorCore

public struct OverviewView: View {
    @ObservedObject var viewModel: AppViewModel

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with action bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mirroring Dashboard")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Real-time control and monitoring for connected Android devices.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        Task { await viewModel.refreshDevices() }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Refresh Devices")
                        }
                    }
                    .disabled(viewModel.isRefreshing)
                }

                // Dependency Alert Banner if missing
                if !viewModel.dependencies.allAvailable {
                    dependencyAlertBanner
                }

                // Primary Hero Session Card
                sessionHeroCard

                // Device Selection & Details
                if !viewModel.devices.isEmpty {
                    connectedDevicesSection
                } else if viewModel.dependencies.adb.isAvailable {
                    noDevicesBanner
                }

                // Active Mirroring Configuration Summary
                configSummaryCard
            }
            .padding(24)
        }
    }

    // MARK: - Subviews

    private var dependencyAlertBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(AppTheme.statusUnauthorized)

            VStack(alignment: .leading, spacing: 2) {
                Text("Required Utilities Missing")
                    .font(.headline)
                    .foregroundColor(.primary)

                if !viewModel.dependencies.adb.isAvailable && !viewModel.dependencies.scrcpy.isAvailable {
                    Text("Neither ADB nor scrcpy was found on this system. Install them via Homebrew or specify paths in Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if !viewModel.dependencies.adb.isAvailable {
                    Text("ADB is missing. Device discovery cannot proceed until ADB is installed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("scrcpy is missing. Mirroring cannot start until scrcpy is installed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Diagnostics") {
                viewModel.selectedSection = .diagnostics
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.electricBlue)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(AppTheme.statusUnauthorized.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(AppTheme.statusUnauthorized.opacity(0.3), lineWidth: 1)
        )
    }

    private var sessionHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(sessionIndicatorColor)
                        .frame(width: 10, height: 10)
                    Text(viewModel.sessionManager.state.statusDescription)
                        .font(.headline)
                }

                Spacer()

                if let device = viewModel.selectedDevice {
                    Text(device.connectionType == .usb ? "USB Connection" : "Wi-Fi TCP/IP")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
            }

            Divider()

            if viewModel.sessionManager.state.isActive {
                activeSessionDetails
            } else {
                inactiveSessionControls
            }
        }
        .cardStyled(isSelected: viewModel.sessionManager.state.isActive)
    }

    private var activeSessionDetails: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedDevice?.displayName ?? "Android Device")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Mirroring is actively running in separate window")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                viewModel.stopMirroring()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                    Text("Stop Mirroring")
                }
                .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.statusError)
        }
    }

    private var inactiveSessionControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let device = viewModel.selectedDevice {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                        HStack(spacing: 8) {
                            Text("Serial: \(device.serialNumber)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(device.state.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(deviceStateColor(device.state))
                        }
                    }

                    Spacer()

                    if device.state.isUsableForMirroring {
                        Button {
                            viewModel.startMirroring()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Start Mirroring")
                            }
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.electricBlue)
                        .disabled(!viewModel.dependencies.scrcpy.isAvailable)
                    } else if device.state == .unauthorized {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Action Required")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.statusUnauthorized)
                            Text("Accept RSA key prompt on phone")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else if device.state == .offline {
                        Button {
                            Task { await viewModel.restartAdbServer() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Restart ADB")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Detailed guidance alert depending on status
                if device.state == .unauthorized {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(AppTheme.statusUnauthorized)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unlock your phone to authorize debugging")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("A prompt 'Allow USB debugging?' should appear on the phone. Check 'Always allow' and tap 'Allow'. If no prompt appears, toggle USB debugging off and on.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(AppTheme.statusUnauthorized.opacity(0.1))
                    .cornerRadius(AppTheme.cornerRadiusSmall)
                } else if device.state == .offline {
                    HStack(spacing: 10) {
                        Image(systemName: "network.slash")
                            .foregroundColor(AppTheme.statusOffline)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Device is offline")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("The phone is connected but not responding to ADB. Unplug and replug the USB cable, or click 'Restart ADB' above.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(AppTheme.statusOffline.opacity(0.1))
                    .cornerRadius(AppTheme.cornerRadiusSmall)
                } else if device.state == .noPermissions {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundColor(AppTheme.statusError)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Insufficient USB Permissions")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Your macOS user account lacks permission to communicate with this USB device.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(AppTheme.statusError.opacity(0.1))
                    .cornerRadius(AppTheme.cornerRadiusSmall)
                }
            } else {
                HStack {
                    Image(systemName: "cable.connector.slash")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Android Device Ready")
                            .font(.headline)
                        Text("Connect a phone via USB and enable USB Debugging to begin.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    private var connectedDevicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Device")
                .font(.headline)

            ForEach(viewModel.devices) { device in
                HStack {
                    Image(systemName: device.connectionType == .usb ? "cable.connector" : "wifi")
                        .foregroundColor(device.state.isUsableForMirroring ? AppTheme.electricBlue : .secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                        Text(device.serialNumber)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(device.state.title)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(deviceStateColor(device.state).opacity(0.15)))
                        .foregroundColor(deviceStateColor(device.state))

                    if viewModel.selectedDevice?.id == device.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.electricBlue)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                        .fill(viewModel.selectedDevice?.id == device.id ? AppTheme.elevatedSurface : AppTheme.graphiteSurface)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedDevice = device
                }
            }
        }
    }

    private var noDevicesBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No Devices Connected")
                .font(.headline)
            Text("1. Connect your Android phone with a USB data cable.\n2. Ensure Developer Options > USB Debugging is turned ON.\n3. Tap 'Allow' when the RSA key prompt appears on your phone.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .cardStyled()
    }

    private var configSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Mirroring Profile")
                .font(.headline)

            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Framerate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(viewModel.config.maxFps > 0 ? "\(viewModel.config.maxFps) FPS" : "Native")
                        .font(.callout)
                        .fontWeight(.medium)
                }

                VStack(alignment: .leading) {
                    Text("Bitrate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.config.bitRateMbps) Mbps")
                        .font(.callout)
                        .fontWeight(.medium)
                }

                VStack(alignment: .leading) {
                    Text("Stay Awake")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(viewModel.config.stayAwake ? "Enabled" : "Disabled")
                        .font(.callout)
                        .fontWeight(.medium)
                }

                VStack(alignment: .leading) {
                    Text("Audio Forwarding")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(viewModel.config.forwardAudio ? "Enabled" : "Disabled")
                        .font(.callout)
                        .fontWeight(.medium)
                }

                Spacer()

                Button("Edit Profile") {
                    viewModel.selectedSection = .settings
                }
                .buttonStyle(.link)
            }
        }
        .cardStyled()
    }

    private var sessionIndicatorColor: Color {
        switch viewModel.sessionManager.state {
        case .active: return AppTheme.statusAuthorized
        case .starting, .stopping: return AppTheme.statusUnauthorized
        case .failed: return AppTheme.statusError
        case .idle, .terminated: return .secondary
        }
    }

    private func deviceStateColor(_ state: DeviceState) -> Color {
        switch state {
        case .authorized: return AppTheme.statusAuthorized
        case .unauthorized, .authorizing: return AppTheme.statusUnauthorized
        case .offline: return AppTheme.statusOffline
        case .recovery, .bootloader, .sideload, .noPermissions, .unknown: return AppTheme.statusError
        }
    }
}
