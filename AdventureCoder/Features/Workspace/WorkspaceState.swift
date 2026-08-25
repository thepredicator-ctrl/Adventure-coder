import SwiftUI

/// The shared app state used across the workspace.
public final class WorkspaceState: ObservableObject {
    public static let shared = WorkspaceState()

    // Local project state
    @Published public var currentProject: Project?
    @Published public var openFiles: [FileNode] = []           // tabs in the editor
    @Published public var activeFile: FileNode?

    // Remote project state
    @Published public var currentRemoteProject: RemoteProject?
    @Published public var currentRemoteProjectTemplate: ProjectTemplate?
    @Published public var openRemoteFiles: [RemoteFileNode] = []
    @Published public var activeRemoteFile: RemoteFileNode?
    @Published public var remoteFileContents: [String: String] = [:]  // path -> content cache

    @Published public var currentConversation: Conversation?
    @Published public var bottomPanel: BottomPanelTab = .terminal
    @Published public var showCommandPalette = false
    @Published public var showGlobalSearch = false
    @Published public var sidebarCollapsed = false
    @Published public var chatCollapsed = false
    @Published public var terminalCollapsed = false
    @Published public var previewCollapsed = false
    @Published public var iPhoneTab: iPhoneTab = .projects
    @Published public var sidebarSection: SidebarSection = .files

    // Resizable panel widths (iPad only)
    @Published public var sidebarWidth: CGFloat = MonoSpace.sidebarDefault
    @Published public var chatWidth: CGFloat = MonoSpace.chatDefault
    @Published public var terminalHeight: CGFloat = MonoSpace.terminalDefault

    public enum SidebarSection: String, CaseIterable, Hashable {
        case files, search, git, projects, remote
        var title: String {
            switch self {
            case .files: return "Files"
            case .search: return "Search"
            case .git: return "Git"
            case .projects: return "Projects"
            case .remote: return "Remote"
            }
        }
        var icon: String {
            switch self {
            case .files: return MonoIcon.doc
            case .search: return MonoIcon.search
            case .git: return MonoIcon.branch
            case .projects: return MonoIcon.folder
            case .remote: return "pc"
            }
        }
    }

    public enum BottomPanelTab: String, CaseIterable, Hashable {
        case conversations, preview, terminal, problems, builds, settings, newProject, remoteTerminal, remotePreview, remoteDashboard

        public var title: String {
            switch self {
            case .conversations: return "Conversations"
            case .preview: return "Preview"
            case .terminal: return "Terminal"
            case .problems: return "Problems"
            case .builds: return "Builds"
            case .settings: return "Settings"
            case .newProject: return "New Project"
            case .remoteTerminal: return "Remote Terminal"
            case .remotePreview: return "Remote Preview"
            case .remoteDashboard: return "Dashboard"
            }
        }

        public var icon: String {
            switch self {
            case .conversations: return MonoIcon.bell
            case .preview: return MonoIcon.eye
            case .terminal: return MonoIcon.terminal
            case .problems: return MonoIcon.warning
            case .builds: return MonoIcon.build
            case .settings: return MonoIcon.settings
            case .newProject: return MonoIcon.docPlus
            case .remoteTerminal: return "terminal"
            case .remotePreview: return "play.rectangle"
            case .remoteDashboard: return "gauge"
            }
        }
    }

    public enum iPhoneTab: String, CaseIterable, Hashable {
        case projects, code, ai, preview, builds, settings

        public var title: String {
            switch self {
            case .projects: return "Projects"
            case .code: return "Code"
            case .ai: return "AI"
            case .preview: return "Preview"
            case .builds: return "Builds"
            case .settings: return "Settings"
            }
        }

        public var icon: String {
            switch self {
            case .projects: return MonoIcon.folder
            case .code: return MonoIcon.docText
            case .ai: return MonoIcon.sparkles
            case .preview: return MonoIcon.eye
            case .builds: return MonoIcon.build
            case .settings: return MonoIcon.settings
            }
        }
    }

    private init() {}

    // MARK: - Remote mode

    public var isRemoteMode: Bool {
        RemotePCStore.shared.isConnected && currentRemoteProject != nil
    }

    public func openRemoteProject(_ project: RemoteProject, template: ProjectTemplate = .web) {
        currentRemoteProject = project
        currentRemoteProjectTemplate = template
        openRemoteFiles = []
        activeRemoteFile = nil
        remoteFileContents = [:]
        RemoteTerminalService.shared.setWorkingDirectory(project.path)

        // Create or reuse conversation
        let projectId = UUID() // Generate a stable ID for remote projects
        currentConversation = ProjectStore.shared.conversations(for: projectId).first
        if currentConversation == nil {
            currentConversation = ProjectStore.shared.createConversation(projectId: projectId, title: project.name)
        }
    }

    public func openRemoteFile(_ node: RemoteFileNode) {
        if !openRemoteFiles.contains(where: { $0.path == node.path }) {
            openRemoteFiles.append(node)
        }
        activeRemoteFile = node

        // Load content from remote PC
        Task {
            if let content = try? await RemoteFileService.shared.readFile(node.path) {
                await MainActor.run {
                    remoteFileContents[node.path] = content
                }
            }
        }
    }

    public func closeRemoteFile(_ node: RemoteFileNode) {
        openRemoteFiles.removeAll { $0.path == node.path }
        remoteFileContents.removeValue(forKey: node.path)
        if activeRemoteFile?.path == node.path {
            activeRemoteFile = openRemoteFiles.last
        }
    }

    public func saveRemoteFile(_ node: RemoteFileNode, content: String) async {
        do {
            try await RemoteFileService.shared.writeFile(node.path, content: content)
            await MainActor.run {
                remoteFileContents[node.path] = content
            }
        } catch {
            // Handle error
        }
    }

    // MARK: - Local project

    public func openProject(_ project: Project) {
        currentProject = project
        ProjectStore.shared.touch(project)
        openFiles = []
        activeFile = nil
        currentConversation = ProjectStore.shared.conversations(for: project.id).first
        if currentConversation == nil {
            currentConversation = ProjectStore.shared.createConversation(projectId: project.id, title: "Conversation")
        }
    }

    public func openFile(_ node: FileNode) {
        if !openFiles.contains(where: { $0.relativePath == node.relativePath }) {
            openFiles.append(node)
        }
        activeFile = node
    }

    public func closeFile(_ node: FileNode) {
        openFiles.removeAll { $0.relativePath == node.relativePath }
        if activeFile?.relativePath == node.relativePath {
            activeFile = openFiles.last
        }
    }
}
