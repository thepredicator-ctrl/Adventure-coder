import SwiftUI

/// File explorer with full filesystem operations.
public struct FileExplorerView: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var nodes: [FileNode] = []
    @State private var expanded: Set<String> = []
    @State private var renaming: String?
    @State private var newName: String = ""
    @State private var creatingIn: String?
    @State private var newFileName: String = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.sm) {
            SectionHeader("Files") {
                AnyView(
                    HStack(spacing: MonoSpace.sm) {
                        Button(action: { creatingIn = ""; newFileName = "" }) {
                            Image(systemName: MonoIcon.docPlus)
                                .foregroundColor(MonoColor.tertiaryText)
                        }
                        .buttonStyle(.plain)
                        Button(action: { creatingIn = "."; newFileName = "" }) {
                            Image(systemName: MonoIcon.folderPlus)
                                .foregroundColor(MonoColor.tertiaryText)
                        }
                        .buttonStyle(.plain)
                    }
                )
            }
            if let project = workspace.currentProject {
                if let creatingIn {
                    HStack {
                        Image(systemName: MonoIcon.pencil)
                            .foregroundColor(MonoColor.tertiaryText)
                        TextField(creatingIn == "." ? "New folder name" : "New file name", text: $newFileName, onCommit: {
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
                OutlineGroup(nodes, id: \.relativePath, children: \.optionalChildren) { node in
                    fileRow(node, project: project)
                }
                .padding(.horizontal, MonoSpace.xs)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, MonoSpace.sm)
        .onAppear(perform: refresh)
        .onChange(of: workspace.currentProject?.id) { _ in refresh() }
    }

    @ViewBuilder
    private func fileRow(_ node: FileNode, project: Project) -> some View {
        HStack(spacing: MonoSpace.xs) {
            if node.isDirectory {
                Image(systemName: expanded.contains(node.relativePath) ? MonoIcon.chevronDown : MonoIcon.chevronRight)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(MonoColor.tertiaryText)
                    .onTapGesture {
                        if expanded.contains(node.relativePath) {
                            expanded.remove(node.relativePath)
                        } else {
                            expanded.insert(node.relativePath)
                        }
                    }
            } else {
                Spacer().frame(width: 11)
            }
            Image(systemName: node.fileIcon)
                .foregroundColor(MonoColor.secondaryText)
                .frame(width: 14)
            if renaming == node.relativePath {
                TextField("Name", text: $newName, onCommit: {
                    let abs = FileSystem.shared.join(project.rootPath, node.relativePath)
                    if let _ = try? FileSystem.shared.rename(abs, to: newName) {
                        refresh()
                    }
                    renaming = nil
                })
                .font(MonoType.body)
                .textFieldStyle(.plain)
            } else {
                Text(node.name)
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.primaryText)
                    .lineLimit(1)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MonoSpace.md)
        .padding(.vertical, MonoSpace.xs + 1)
        .background(workspace.activeFile?.relativePath == node.relativePath ? MonoColor.cloud : Color.clear)
        .overlay(alignment: .leading) {
            if workspace.activeFile?.relativePath == node.relativePath {
                Rectangle().fill(MonoColor.nearBlack).frame(width: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if node.isDirectory {
                if expanded.contains(node.relativePath) {
                    expanded.remove(node.relativePath)
                } else {
                    expanded.insert(node.relativePath)
                }
            } else {
                workspace.openFile(node)
            }
        }
        .contextMenu {
            if node.isDirectory {
                Button("New file") { creatingIn = node.relativePath; newFileName = "" }
                Button("New folder") { creatingIn = node.relativePath; newFileName = "" }
            } else {
                Button("Open") { workspace.openFile(node) }
            }
            Button("Rename") { renaming = node.relativePath; newName = node.name }
            Button("Duplicate") {
                let abs = FileSystem.shared.join(project.rootPath, node.relativePath)
                _ = try? FileSystem.shared.duplicate(abs)
                refresh()
            }
            Button("Delete", role: .destructive) {
                let abs = FileSystem.shared.join(project.rootPath, node.relativePath)
                try? FileSystem.shared.delete(abs)
                if workspace.activeFile?.relativePath == node.relativePath {
                    workspace.activeFile = nil
                }
                refresh()
            }
        }
    }

    private func create(in parent: String, name: String) {
        guard let project = workspace.currentProject, !name.isEmpty else { return }
        let abs = FileSystem.shared.join(project.rootPath, parent)
        let newAbs = (abs as NSString).appendingPathComponent(name)
        if name.contains(".") {
            try? FileSystem.shared.write(newAbs, content: "")
        } else {
            try? FileSystem.shared.createDirectory(newAbs)
        }
        expanded.insert(parent)
        refresh()
    }

    private func refresh() {
        guard let project = workspace.currentProject else { return }
        nodes = (try? FileSystem.shared.list(directory: project.rootPath)) ?? []
    }
}
