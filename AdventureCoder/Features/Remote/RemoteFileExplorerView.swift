import SwiftUI

/// Remote file explorer view.
public struct RemoteFileExplorerView: View {
    @StateObject private var store = RemotePCStore.shared
    @StateObject private var workspace = WorkspaceState.shared
    @State private var nodes: [RemoteFileNode] = []
    @State private var currentPath: String = ""
    @State private var isLoading = false
    @State private var creatingIn: String?
    @State private var newFileName: String = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.sm) {
            SectionHeader("Remote Files") {
                AnyView(
                    HStack(spacing: MonoSpace.sm) {
                        Button(action: { creatingIn = currentPath; newFileName = "" }) {
                            Image(systemName: MonoIcon.docPlus)
                                .foregroundColor(MonoColor.tertiaryText)
                        }
                        .buttonStyle(.plain)
                        Button(action: { creatingIn = currentPath; newFileName = "" }) {
                            Image(systemName: MonoIcon.folderPlus)
                                .foregroundColor(MonoColor.tertiaryText)
                        }
                        .buttonStyle(.plain)
                        Button(action: refresh) {
                            Image(systemName: MonoIcon.refresh)
                                .foregroundColor(MonoColor.tertiaryText)
                        }
                        .buttonStyle(.plain)
                    }
                )
            }

            // Breadcrumb
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MonoSpace.xs) {
                    ForEach(breadcrumbs, id: \.self) { crumb in
                        Text(crumb)
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.tertiaryText)
                        Image(systemName: MonoIcon.chevronRight)
                            .font(.system(size: 8))
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                }
                .padding(.horizontal, MonoSpace.md)
            }

            if !store.isConnected {
                EmptyState(
                    title: "Not connected",
                    message: "Connect to a remote PC to browse files.",
                    systemImage: MonoIcon.folder
                )
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    OutlineGroup(nodes, id: \.path, children: \.optionalChildren) { node in
                        fileRow(node)
                    }
                    .padding(.horizontal, MonoSpace.xs)
                }
            }

            if let creatingIn = creatingIn {
                HStack {
                    Image(systemName: MonoIcon.pencil)
                        .foregroundColor(MonoColor.tertiaryText)
                    TextField("New file/folder name", text: $newFileName, onCommit: {
                        create(in: creatingIn, name: newFileName)
                        self.creatingIn = nil
                    })
                    .font(MonoType.body)
                    Button("Cancel") { self.creatingIn = nil }
                        .font(MonoType.caption)
                        .foregroundColor(MonoColor.tertiaryText)
                }
                .padding(.horizontal, MonoSpace.md)
                .padding(.vertical, MonoSpace.xs)
                .background(MonoColor.inset)
                .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))
                .padding(.horizontal, MonoSpace.md)
            }
        }
        .padding(.vertical, MonoSpace.sm)
        .onAppear {
            if currentPath.isEmpty, let env = store.environment {
                currentPath = env.workspacePath
            }
            refresh()
        }
    }

    @ViewBuilder
    private func fileRow(_ node: RemoteFileNode) -> some View {
        HStack(spacing: MonoSpace.xs) {
            Image(systemName: node.fileIcon)
                .foregroundColor(MonoColor.secondaryText)
                .frame(width: 14)
            Text(node.name)
                .font(MonoType.body)
                .foregroundColor(MonoColor.primaryText)
                .lineLimit(1)
            Spacer()
            if !node.isDirectory {
                Text(formatSize(node.size))
                    .font(MonoType.caption2)
                    .foregroundColor(MonoColor.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MonoSpace.md)
        .padding(.vertical, MonoSpace.xs + 1)
        .background(isActiveFile(node) ? MonoColor.cloud : Color.clear)
        .overlay(alignment: .leading) {
            if isActiveFile(node) {
                Rectangle().fill(MonoColor.nearBlack).frame(width: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !node.isDirectory {
                workspace.openRemoteFile(node)
            }
        }
        .contextMenu {
            Button("Open") { workspace.openRemoteFile(node) }
            Button("Download") { Task { try? await RemoteDownloadService.shared.downloadProjectSource(at: node.path) } }
            if node.isDirectory {
                Button("New File Here") { creatingIn = node.path; newFileName = "" }
            }
            Button("Delete", role: .destructive) {
                Task { try? await RemoteFileService.shared.deleteFile(node.path); refresh() }
            }
        }
    }

    private func isActiveFile(_ node: RemoteFileNode) -> Bool {
        workspace.activeRemoteFile?.path == node.path
    }

    private var breadcrumbs: [String] {
        guard !currentPath.isEmpty else { return [] }
        let parts = currentPath.split(separator: "\\").map { String($0) }
        if parts.count > 1 {
            return [parts.suffix(3).joined(separator: " › ")]
        }
        let unixParts = currentPath.split(separator: "/").map { String($0) }
        return [unixParts.suffix(3).joined(separator: " › ")]
    }

    private func refresh() {
        guard store.isConnected, !currentPath.isEmpty else { return }
        isLoading = true
        Task {
            do {
                nodes = try await RemoteFileService.shared.fileTree(at: currentPath, maxDepth: 2)
            } catch {
                nodes = []
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func create(in parent: String, name: String) {
        guard !name.isEmpty else { return }
        let path = (parent as NSString).appendingPathComponent(name)
        Task {
            if name.contains(".") {
                try? await RemoteFileService.shared.writeFile(path, content: "")
            } else {
                try? await RemoteFileService.shared.createDirectory(path)
            }
            refresh()
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576.0)
    }
}
