import SwiftUI
import AppKit
import UniformTypeIdentifiers
import MacdroidMirrorCore

public struct FileTransferView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isTargetedForDrop: Bool = false
    @State private var applyToAllRemaining: Bool = false
    @State private var showCustomPathSheet: Bool = false
    @State private var customPathInput: String = ""

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    private var isDeviceReady: Bool {
        viewModel.selectedDevice != nil && viewModel.selectedDevice?.state.isUsableForMirroring == true
    }

    private var currentPathModel: RemotePathModel {
        RemotePathModel(viewModel.currentRemotePath, storageRoot: viewModel.selectedVolume.rootPath)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header & Action Bar
                headerActionBar

                // Storage Volume Selector & Navigation Bar
                navigationBreadcrumbsBar

                // Drag and Drop Zone
                dropTargetZone

                // Transfer Status Banner
                transferStatusBanner

                // Remote File Explorer
                filesListCard
            }
            .padding(24)
        }
        .task {
            await viewModel.refreshStorageVolumes()
            if viewModel.remoteFiles.isEmpty {
                await viewModel.loadRemoteFiles()
            }
        }
        .sheet(item: $viewModel.activeConflict) { conflictItem in
            conflictModalSheet(for: conflictItem)
        }
        .sheet(isPresented: $showCustomPathSheet) {
            goToPathSheet
        }
    }

    // MARK: - Subviews

    private var headerActionBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("File Transfer")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Universal file explorer and transfer manager")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Storage Volume Switcher (Internal storage vs SD Card vs Device Root)
            Picker("Storage:", selection: Binding(
                get: { viewModel.selectedVolume },
                set: { newVol in
                    Task { await viewModel.selectVolume(newVol) }
                }
            )) {
                ForEach(viewModel.storageVolumes) { vol in
                    Text(vol.name).tag(vol)
                }
            }
            .frame(width: 195)
            .disabled(!isDeviceReady || viewModel.isLoadingFiles)

            // Quick Folder Jump Menu
            Menu {
                Button("Internal storage (Root)") {
                    Task { await viewModel.navigateToRemoteDirectory("/sdcard") }
                }
                Divider()
                Button("Downloads") {
                    Task { await viewModel.navigateToRemoteDirectory("/sdcard/Download") }
                }
                Button("Documents") {
                    Task { await viewModel.navigateToRemoteDirectory("/sdcard/Documents") }
                }
                Button("Photos (DCIM)") {
                    Task { await viewModel.navigateToRemoteDirectory("/sdcard/DCIM") }
                }
                Button("Pictures") {
                    Task { await viewModel.navigateToRemoteDirectory("/sdcard/Pictures") }
                }
                Button("Music") {
                    Task { await viewModel.navigateToRemoteDirectory("/sdcard/Music") }
                }
                Button("Movies") {
                    Task { await viewModel.navigateToRemoteDirectory("/sdcard/Movies") }
                }
                Divider()
                Button("Device Root (/)") {
                    Task { await viewModel.navigateToRemoteDirectory("/") }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.gearshape")
                    Text("Jump to")
                }
            }
            .disabled(!isDeviceReady || viewModel.isLoadingFiles)

            // Go to Custom Path
            Button {
                customPathInput = viewModel.currentRemotePath
                showCustomPathSheet = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .help("Go to specific folder path")
            .disabled(!isDeviceReady || viewModel.isLoadingFiles)

            // Refresh
            Button {
                Task {
                    await viewModel.refreshStorageVolumes()
                    await viewModel.loadRemoteFiles()
                }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isLoadingFiles {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Refresh")
                }
            }
            .disabled(!isDeviceReady || viewModel.isLoadingFiles)

            // Upload
            Button {
                chooseAndUploadFiles()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Send Files to Phone")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.electricBlue)
            .disabled(!isDeviceReady || viewModel.isLoadingFiles)
        }
    }

    private var navigationBreadcrumbsBar: some View {
        HStack(spacing: 10) {
            // Back Button
            Button {
                Task { await viewModel.navigateToParentDirectory() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!isDeviceReady || currentPathModel.isRoot || viewModel.isLoadingFiles)

            Divider()
                .frame(height: 16)

            // Clickable Breadcrumbs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(currentPathModel.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Button {
                            Task { await viewModel.navigateToRemoteDirectory(crumb.path) }
                        } label: {
                            Text(crumb.title)
                                .font(.callout)
                                .fontWeight(index == currentPathModel.breadcrumbs.count - 1 ? .bold : .regular)
                                .foregroundColor(index == currentPathModel.breadcrumbs.count - 1 ? .primary : AppTheme.electricBlue)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isDeviceReady || index == currentPathModel.breadcrumbs.count - 1 || viewModel.isLoadingFiles)
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                .fill(AppTheme.elevatedSurface.opacity(0.6))
        )
    }

    private var dropTargetZone: some View {
        VStack(spacing: 10) {
            Image(systemName: isTargetedForDrop ? "arrow.down.doc.fill" : "arrow.down.doc")
                .font(.system(size: 28))
                .foregroundColor(AppTheme.electricBlue)

            Text("Drag & Drop Files Here from Finder")
                .font(.headline)

            Text(isDeviceReady ? "Files will be pushed to: \(currentPathModel.friendlyDisplayPath)" : "Connect and authorize an Android device to transfer files")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(isTargetedForDrop ? AppTheme.electricBlue.opacity(0.12) : AppTheme.surfaceBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(isTargetedForDrop ? AppTheme.electricBlue : AppTheme.subtleBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .onDrop(of: [UTType.fileURL.identifier, UTType.item.identifier], isTargeted: $isTargetedForDrop) { providers in
            guard isDeviceReady else { return false }
            return handleDrop(providers: providers)
        }
    }

    private var transferStatusBanner: some View {
        HStack {
            if viewModel.isLoadingFiles {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            } else {
                Image(systemName: isDeviceReady ? "info.circle" : "exclamationmark.circle")
                    .foregroundColor(isDeviceReady ? AppTheme.electricBlue : AppTheme.statusUnauthorized)
            }

            Text(isDeviceReady ? (viewModel.transferStatusMessage ?? "Ready for file transfer") : "No authorized device connected.")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var filesListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isDeviceReady ? "Contents of \(currentPathModel.friendlyDisplayPath)" : "File Explorer")
                    .font(.headline)

                Spacer()

                if viewModel.isLoadingFiles {
                    ProgressView()
                        .controlSize(.small)
                } else if isDeviceReady {
                    Text("\(viewModel.remoteFiles.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            if !isDeviceReady {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "cable.connector.slash")
                            .font(.system(size: 38))
                            .foregroundColor(.secondary)

                        VStack(spacing: 4) {
                            Text("No Android Device Available")
                                .font(.headline)
                            Text("Connect an Android device via USB or Wireless Debugging to browse and transfer files.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 380)
                        }

                        Button("Open Connected Devices") {
                            viewModel.selectedSection = .devices
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 36)
                    Spacer()
                }
            } else if viewModel.remoteFiles.isEmpty && !viewModel.isLoadingFiles {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No items found in this directory")
                            .foregroundColor(.secondary)
                            .font(.callout)
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
            } else {
                // Table column header row
                HStack(spacing: 12) {
                    Text("Name")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("Size")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 90, alignment: .trailing)

                    Text("Modified")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 130, alignment: .leading)

                    Text("Action")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 105, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

                Divider()

                VStack(spacing: 4) {
                    ForEach(viewModel.remoteFiles) { file in
                        HStack(spacing: 12) {
                            Image(systemName: file.isDirectory ? "folder.fill" : fileIconName(for: file.name))
                                .foregroundColor(file.isDirectory ? .yellow : AppTheme.electricBlue)
                                .frame(width: 20)

                            Text(file.name)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Text(file.formattedSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 90, alignment: .trailing)

                            Text(file.modificationDateString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 130, alignment: .leading)

                            HStack {
                                Spacer()
                                if file.isDirectory {
                                    Button("Open") {
                                        Task { await viewModel.navigateToRemoteDirectory(file.fullPath) }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(viewModel.isLoadingFiles)
                                } else {
                                    Button {
                                        promptSaveToMac(remoteFile: file)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down.circle")
                                            Text("Save to Mac")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(viewModel.isLoadingFiles)
                                }
                            }
                            .frame(width: 105)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                .fill(AppTheme.elevatedSurface.opacity(0.35))
                        )
                    }
                }
            }
        }
        .cardStyled()
    }

    // MARK: - Native Confirmation Dialog / Modal Sheet (Aligned & Polished)

    private func conflictModalSheet(for conflict: FileConflictItem) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header with Alert Icon and Titles
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.statusUnauthorized.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppTheme.statusUnauthorized)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("File Already Exists")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("A file named \"\(conflict.fileName)\" already exists in this location.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Path & Consequence Info Box
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text("Location:")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)
                    Text(RemotePathModel(conflict.destinationDirectory, storageRoot: viewModel.selectedVolume.rootPath).friendlyDisplayPath)
                        .foregroundColor(.primary)
                        .fontWeight(.semibold)
                }
                .font(.caption)

                HStack(alignment: .top, spacing: 8) {
                    Text("File:")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)
                    Text(conflict.fileName)
                        .foregroundColor(.primary)
                        .font(.system(.caption, design: .monospaced))
                }
                .font(.caption)

                Divider()

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(AppTheme.statusUnauthorized)
                    Text("Replacing will overwrite the existing file on your device. This action cannot be undone.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .fill(AppTheme.elevatedSurface.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .stroke(AppTheme.subtleBorder, lineWidth: 1)
            )

            // Batch Checkbox
            if viewModel.hasPendingBatchConflicts {
                Toggle("Apply to all remaining conflicts in this batch", isOn: $applyToAllRemaining)
                    .font(.body)
                    .padding(.top, 2)
            }

            Divider()

            // Aligned Button Row
            HStack(spacing: 12) {
                Button("Cancel") {
                    let apply = applyToAllRemaining
                    applyToAllRemaining = false
                    viewModel.resolveConflict(with: .cancel, applyToAll: apply)
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.regular)

                Spacer()

                Button("Skip") {
                    let apply = applyToAllRemaining
                    applyToAllRemaining = false
                    viewModel.resolveConflict(with: .skip, applyToAll: apply)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button("Replace") {
                    let apply = applyToAllRemaining
                    applyToAllRemaining = false
                    viewModel.resolveConflict(with: .replace, applyToAll: apply)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.statusError)
                .controlSize(.regular)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    // MARK: - Go To Path Sheet

    private var goToPathSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Go to Folder")
                .font(.headline)

            Text("Enter any remote Android folder path to browse its contents:")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("e.g. /data/local/tmp", text: $customPathInput)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    showCustomPathSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Go") {
                    let target = customPathInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    showCustomPathSheet = false
                    if !target.isEmpty {
                        Task { await viewModel.navigateToRemoteDirectory(target) }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.electricBlue)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    // MARK: - Native Save Panel & Upload Helpers

    private func promptSaveToMac(remoteFile: RemoteFileItem) {
        let savePanel = NSSavePanel()
        savePanel.title = "Save \(remoteFile.name) to Mac"
        savePanel.nameFieldStringValue = remoteFile.name
        savePanel.canCreateDirectories = true

        if savePanel.runModal() == .OK, let targetURL = savePanel.url {
            let directoryURL = targetURL.deletingLastPathComponent()
            Task {
                await viewModel.pullFileToMac(remoteFile: remoteFile, destinationDirectory: directoryURL)
            }
        }
    }

    private func chooseAndUploadFiles() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.title = "Select Files to Send to Android"

        if openPanel.runModal() == .OK {
            let urls = openPanel.urls
            let targetDir = viewModel.currentRemotePath
            Task {
                await viewModel.pushFiles(fileURLs: urls, destinationDirectory: targetDir)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var resolvedURLs: [URL] = []
        let group = DispatchGroup()
        let targetDir = viewModel.currentRemotePath

        for provider in providers {
            group.enter()
            
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let url = item as? URL {
                        resolvedURLs.append(url)
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        resolvedURLs.append(url)
                    } else if let string = item as? String, let url = URL(string: string) {
                        resolvedURLs.append(url)
                    }
                }
            } else {
                provider.loadItem(forTypeIdentifier: UTType.item.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let url = item as? URL {
                        resolvedURLs.append(url)
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        resolvedURLs.append(url)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            let validURLs = resolvedURLs.filter { url in
                FileManager.default.fileExists(atPath: url.path)
            }
            if !validURLs.isEmpty {
                Task {
                    await viewModel.pushFiles(fileURLs: validURLs, destinationDirectory: targetDir)
                }
            }
        }

        return true
    }

    private func fileIconName(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "webp", "gif", "heic":
            return "photo"
        case "mp4", "mkv", "mov":
            return "film"
        case "mp3", "opus", "m4a", "wav":
            return "music.note"
        case "pdf":
            return "doc.richtext"
        case "apk":
            return "shippingbox"
        case "zip", "tar", "gz":
            return "archivebox"
        default:
            return "doc"
        }
    }
}
