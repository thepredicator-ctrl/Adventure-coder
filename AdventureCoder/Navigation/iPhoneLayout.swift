import SwiftUI

/// iPhone tab-based layout.
public struct iPhoneLayout: View {
    @StateObject private var workspace = WorkspaceState.shared

    public init() {}

    public var body: some View {
        TabView(selection: $workspace.iPhoneTab) {
            ForEach(WorkspaceState.iPhoneTab.allCases, id: \.self) { tab in
                NavigationStack {
                    Group {
                        switch tab {
                        case .projects:
                            ProjectsListView()
                        case .code:
                            iPhoneCodeTab()
                        case .ai:
                            iPhoneAITab()
                        case .preview:
                            PreviewView()
                        case .builds:
                            BuildsView()
                        case .settings:
                            SettingsView()
                        }
                    }
                    .navigationTitle(tab.title)
                    .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
    }
}

struct iPhoneCodeTab: View {
    @StateObject private var workspace = WorkspaceState.shared
    var body: some View {
        VStack(spacing: 0) {
            if let project = workspace.currentProject {
                if let active = workspace.activeFile {
                    CodeEditorView(node: active)
                } else {
                    EmptyState(title: "No file open", message: "Browse files in the Projects tab or pick a file to start editing.", systemImage: MonoIcon.doc)
                }
                // Compact file drawer
                CompactFileDrawer(project: project)
            } else {
                EmptyState(title: "No project", message: "Open or create a project to start coding.", systemImage: MonoIcon.folder)
            }
        }
    }
}

struct CompactFileDrawer: View {
    let project: Project
    @State private var expanded = false
    @StateObject private var workspace = WorkspaceState.shared
    @State private var nodes: [FileNode] = []

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                expanded.toggle()
                if expanded { refresh() }
            }) {
                HStack {
                    Image(systemName: MonoIcon.folder)
                        .foregroundColor(MonoColor.secondaryText)
                    Text("Files")
                        .font(MonoType.headline)
                    Spacer()
                    Image(systemName: expanded ? MonoIcon.chevronDown : MonoIcon.chevronRight)
                        .foregroundColor(MonoColor.tertiaryText)
                }
                .padding(.horizontal, MonoSpace.md)
                .padding(.vertical, MonoSpace.sm)
                .background(MonoColor.panel)
            }
            .buttonStyle(.plain)
            if expanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(flatten(nodes), id: \.relativePath) { node in
                            HStack {
                                Image(systemName: node.fileIcon)
                                    .foregroundColor(MonoColor.secondaryText)
                                Text(node.relativePath)
                                    .font(MonoType.caption)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, MonoSpace.md)
                            .padding(.vertical, MonoSpace.xs + 1)
                            .background(workspace.activeFile?.relativePath == node.relativePath ? MonoColor.cloud : Color.clear)
                            .onTapGesture {
                                workspace.openFile(node)
                                expanded = false
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
    }

    private func refresh() {
        nodes = (try? FileSystem.shared.list(directory: project.rootPath)) ?? []
    }

    private func flatten(_ nodes: [FileNode]) -> [FileNode] {
        var result: [FileNode] = []
        for node in nodes {
            result.append(node)
            if node.isDirectory {
                result.append(contentsOf: flatten(node.children))
            }
        }
        return result
    }
}

struct iPhoneAITab: View {
    @StateObject private var workspace = WorkspaceState.shared
    var body: some View {
        if workspace.currentProject != nil {
            AIChatView()
        } else {
            EmptyState(title: "No project", message: "Open a project to start a conversation.", systemImage: MonoIcon.sparkles)
        }
    }
}
