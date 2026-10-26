import SwiftUI
import MacdroidMirrorCore

public struct DevicesView: View {
    @ObservedObject var viewModel: AppViewModel

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connected Devices")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Manage and launch mirroring sessions for detected Android hardware.")
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
                            Text("Refresh List")
                        }
                    }
                    .disabled(viewModel.isRefreshing)
                }

                if viewModel.devices.isEmpty {
                    wirelessDebuggingCard
                    emptyDevicesView
                } else {
                    wirelessDebuggingCard
                    deviceListView
                }
            }
            .padding(24)
        }
    }

    // MARK: - Subviews

    private var wirelessDebuggingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "wifi")
                        .foregroundColor(AppTheme.electricBlue)
                        .font(.headline)
                    Text("Wireless Debugging (Wi-Fi)")
                        .font(.headline)
                }

                Spacer()

                if viewModel.isConnectingWireless {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            // One-Click Switch from USB Banner (if USB device attached)
            if let usbDevice = viewModel.devices.first(where: { $0.connectionType == .usb && $0.state.isUsableForMirroring }) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(AppTheme.electricBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("USB Device Ready: \(usbDevice.displayName)")
                            .font(.callout)
                            .fontWeight(.semibold)
                        Text("Switch to Wireless with 1 click without typing commands.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Switch to Wireless") {
                        Task { await viewModel.enableWirelessDebugging(for: usbDevice) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.electricBlue)
                    .controlSize(.small)
                    .disabled(viewModel.isConnectingWireless)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                        .fill(AppTheme.electricBlue.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                        .stroke(AppTheme.electricBlue.opacity(0.3), lineWidth: 1)
                )
            }

            // Direct IP Connect Guide & Inputs
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    guideStepRow(number: "1", text: "Make sure both your phone and Mac are connected to the same Wi-Fi network.")
                    guideStepRow(number: "2", text: "Find phone IP in Settings > About Phone > Status > IP address (e.g. 192.168.1.100).")
                    guideStepRow(number: "3", text: "Enter the IP address and port (default 5555), then click 'Connect Wi-Fi'.")
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                        .fill(AppTheme.elevatedSurface.opacity(0.35))
                )

                HStack(spacing: 10) {
                    TextField("Phone IP address (e.g. 192.168.1.100)", text: $viewModel.manualWirelessIP)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 240)

                    TextField("Port", text: $viewModel.manualWirelessPort)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 75)

                    Button {
                        let port = Int(viewModel.manualWirelessPort) ?? 5555
                        Task { await viewModel.connectManualWireless(ipAddress: viewModel.manualWirelessIP, port: port) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                            Text("Connect Wi-Fi")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.electricBlue)
                    .disabled(viewModel.manualWirelessIP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isConnectingWireless)
                }
            }

            if let msg = viewModel.wirelessStatusMessage {
                HStack(spacing: 6) {
                    Image(systemName: msg.contains("failed") || msg.contains("Could not") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    Text(msg)
                }
                .font(.caption)
                .foregroundColor(msg.contains("failed") || msg.contains("Could not") ? AppTheme.statusError : AppTheme.statusAuthorized)
            }
        }
        .cardStyled()
    }

    private var deviceListView: some View {
        VStack(spacing: 14) {
            ForEach(viewModel.devices) { device in
                deviceRow(device)
            }
        }
    }

    private func deviceRow(_ device: Device) -> some View {
        let isSelected = viewModel.selectedDevice?.id == device.id
        let isMirroringThis = viewModel.sessionManager.state.activeDeviceId == device.id && viewModel.sessionManager.state.isActive

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                // Icon
                Image(systemName: device.connectionType == .usb ? "cable.connector" : "wifi")
                    .font(.title2)
                    .foregroundColor(device.state.isUsableForMirroring ? AppTheme.electricBlue : .secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(device.state.isUsableForMirroring ? AppTheme.electricBlue.opacity(0.12) : Color.secondary.opacity(0.12))
                    )

                // Title & Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(device.displayName)
                            .font(.headline)

                        if isMirroringThis {
                            Text("MIRRORING ACTIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppTheme.statusAuthorized.opacity(0.2)))
                                .foregroundColor(AppTheme.statusAuthorized)
                        }
                    }

                    Text("Serial: \(device.serialNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // State Badge
                stateBadge(device.state)
            }

            // Hardware Metadata Grid
            HStack(spacing: 24) {
                if let product = device.productName {
                    metadataItem(label: "Product", value: product)
                }
                if let code = device.deviceCode {
                    metadataItem(label: "Codename", value: code)
                }
                if let transport = device.transportId {
                    metadataItem(label: "Transport ID", value: transport)
                }
                metadataItem(label: "Connection", value: device.connectionType == .usb ? "USB" : "Wi-Fi TCP/IP")
            }
            .padding(.top, 4)

            Divider()

            // Actions row
            HStack {
                if isMirroringThis {
                    Button(role: .destructive) {
                        viewModel.stopMirroring()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                            Text("Stop Session")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.statusError)
                } else if device.state.isUsableForMirroring {
                    Button {
                        viewModel.selectedDevice = device
                        viewModel.startMirroring()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Mirror Device")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.electricBlue)
                    .disabled(!viewModel.dependencies.scrcpy.isAvailable)

                    if device.connectionType == .usb {
                        Button {
                            Task { await viewModel.enableWirelessDebugging(for: device) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "wifi")
                                Text("Switch to Wireless")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isConnectingWireless)
                    } else if device.connectionType == .tcpip {
                        Button(role: .destructive) {
                            Task { await viewModel.disconnectWireless(for: device) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "wifi.slash")
                                Text("Disconnect Wi-Fi")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                } else if device.state == .unauthorized {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(AppTheme.statusUnauthorized)
                        Text("Device Unauthorized: Unlock phone screen and accept RSA debugging prompt.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if device.state == .offline {
                    HStack(spacing: 8) {
                        Image(systemName: "network.slash")
                            .foregroundColor(AppTheme.statusOffline)
                        Text("Device Offline: Check USB cable or restart ADB daemon.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Restart ADB") {
                            Task { await viewModel.restartAdbServer() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else if device.state == .noPermissions {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundColor(AppTheme.statusError)
                        Text("No Permissions: USB access denied on macOS.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if !isSelected {
                    Button("Set as Default") {
                        viewModel.selectedDevice = device
                    }
                    .buttonStyle(.link)
                }
            }
        }
        .cardStyled(isSelected: isSelected)
    }

    private func metadataItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private func stateBadge(_ state: DeviceState) -> some View {
        Text(state.title)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(badgeColor(state).opacity(0.15)))
            .foregroundColor(badgeColor(state))
    }

    private func badgeColor(_ state: DeviceState) -> Color {
        switch state {
        case .authorized: return AppTheme.statusAuthorized
        case .unauthorized, .authorizing: return AppTheme.statusUnauthorized
        case .offline: return AppTheme.statusOffline
        case .recovery, .bootloader, .sideload, .noPermissions, .unknown: return AppTheme.statusError
        }
    }

    private var emptyDevicesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cable.connector.slash")
                .font(.system(size: 44))
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text("No Android Devices Found")
                    .font(.headline)
                Text("Make sure USB debugging is turned on in your Android device's Developer Options and connected with a high-quality data cable.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            Button {
                viewModel.selectedSection = .troubleshooting
            } label: {
                Text("View USB Debugging Guide")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .cardStyled()
    }

    private func guideStepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption2)
                .fontWeight(.bold)
                .frame(width: 18, height: 18)
                .background(Circle().fill(AppTheme.electricBlue.opacity(0.18)))
                .foregroundColor(AppTheme.electricBlue)
                .padding(.top, 1)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
