import SwiftUI

/// The shared app state used across the workspace.
public final class WorkspaceState: ObservableObject {
    public static let shared = WorkspaceState()

    @Published public var currentProject: Project?
    @Published public var openFiles: [FileNode] = []           // tabs in the editor
    @Published public var activeFile: FileNode?
    @Published public var currentConversation: Conversation?
    @Published public var bottomPanel: BottomPanelTab = .terminal
    @Published public var showCommandPalette = false
    @Published public var showGlobalSearch = false
    @Published public var sidebarCollapsed = false
    @Published public var chatCollapsed = false
    @Published public var terminalCollapsed = false
    @Published public var previewCollapsed = false
    @Published public var iPhoneTab: iPhoneTab = .projects

    // Resizable panel widths (iPad only)
    @Published public var sidebarWidth: CGFloat = MonoSpace.sidebarDefault
    @Published public var chatWidth: CGFloat = MonoSpace.chatDefault
    @Published public var terminalHeight: CGFloat = MonoSpace.terminalDefault

    public enum BottomPanelTab: String, CaseIterable, Hashable {
        case conversations, preview, terminal, problems, builds, settings, newProject

        public var title: String {
            switch self {
            case .conversations: return "Conversations"
            case .preview: return "Preview"
            case .terminal: return "Terminal"
            case .problems: return "Problems"
            case .builds: return "Builds"
            case .settings: return "Settings"
            case .newProject: return "New Project"
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
