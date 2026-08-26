import SwiftUI

/// Root view that adapts between iPad and iPhone layouts.
/// Uses a clean page-based navigation system with separate full-screen pages.
public struct AdaptiveLayout: View {
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    public init() {}

    public var body: some View {
        if hSize == .regular {
            // iPad - sidebar navigation with full-screen pages
            CleanIPadLayout()
        } else {
            // iPhone - tab bar navigation
            CleaniPhoneLayout()
        }
    }
}

// MARK: - iPad Layout (Sidebar Navigation)

/// Clean iPad layout with a sidebar for navigation and full-screen content pages.
public struct CleanIPadLayout: View {
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var settings = SettingsStore.shared
    @State private var selectedPage: AppPage = .projects
    @State private var showCommandPalette = false

    public init() {}

    public var body: some View {
        NavigationSplitView {
            // Sidebar
            AppSidebar(selectedPage: $selectedPage)
                .navigationTitle("Adventure Coder")
                .navigationBarTitleDisplayMode(.inline)
        } detail: {
            // Full-screen content page
            AppPageView(page: selectedPage)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showCommandPalette = true }) {
                            Image(systemName: "magnifyingglass")
                        }
                        .keyboardShortcut("k", modifiers: .command)
                    }
                }
        }
        .preferredColorScheme(settings.colorScheme)
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
        }
    }
}

// MARK: - iPhone Layout (Tab Bar)

/// Clean iPhone layout with a tab bar for navigation.
public struct CleaniPhoneLayout: View {
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var settings = SettingsStore.shared
    @State private var selectedTab: AppPage = .projects

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppPage.allCases, id: \.self) { page in
                NavigationStack {
                    AppPageView(page: page)
                }
                .tabItem {
                    Label(page.title, systemImage: page.icon)
                }
                .tag(page)
            }
        }
        .preferredColorScheme(settings.colorScheme)
    }
}

// MARK: - App Pages

/// All available pages in the app.
public enum AppPage: String, CaseIterable, Hashable {
    case projects, editor, ai, terminal, preview, builds, agents, settings

    public var title: String {
        switch self {
        case .projects: return "Projects"
        case .editor: return "Editor"
        case .ai: return "AI"
        case .terminal: return "Terminal"
        case .preview: return "Preview"
        case .builds: return "Builds"
        case .agents: return "Agents"
        case .settings: return "Settings"
        }
    }

    public var icon: String {
        switch self {
        case .projects: return "folder"
        case .editor: return "doc.text"
        case .ai: return "sparkles"
        case .terminal: return "terminal"
        case .preview: return "eye"
        case .builds: return "hammer"
        case .agents: return "person.3"
        case .settings: return "gearshape"
        }
    }
}

/// Sidebar for iPad navigation.
struct AppSidebar: View {
    @Binding var selectedPage: AppPage
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var remoteStore = RemotePCStore.shared

    var body: some View {
        List(selection: $selectedPage) {
            Section("Workspace") {
                ForEach(AppPage.allCases, id: \.self) { page in
                    NavigationLink(value: page) {
                        Label(page.title, systemImage: page.icon)
                    }
                }
            }

            if let project = workspace.currentProject {
                Section("Current Project") {
                    Label(project.name, systemImage: project.icon)
                        .font(MonoType.body)
                    if let conv = workspace.currentConversation {
                        Label(conv.title, systemImage: "bubble.left")
                            .font(MonoType.caption)
                    }
                }
            }

            Section("Remote") {
                if remoteStore.isConnected {
                    Label("Connected", systemImage: "pc")
                        .foregroundColor(MonoColor.success)
                } else {
                    Label("Disconnected", systemImage: "pc")
                        .foregroundColor(MonoColor.tertiaryText)
                }
            }
        }
    }
}

/// Full-screen page view that displays the selected page.
struct AppPageView: View {
    let page: AppPage

    var body: some View {
        switch page {
        case .projects:
            ProjectsPage()
        case .editor:
            EditorPage()
        case .ai:
            AIPage()
        case .terminal:
            TerminalPage()
        case .preview:
            PreviewPage()
        case .builds:
            BuildsPage()
        case .agents:
            AgentsPage()
        case .settings:
            SettingsPage()
        }
    }
}

// MARK: - Page Views

/// Projects page - full screen project management.
struct ProjectsPage: View {
    @StateObject private var projectStore = ProjectStore.shared
    @StateObject private var workspace = WorkspaceState.shared
    @State private var showNewProject = false

    var body: some View {
        List {
            if projectStore.projects.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder",
                        description: Text("Create a new project to get started.")
                    )
                }
            }

            Section("Local Projects") {
                ForEach(projectStore.projects) { project in
                    Button(action: { workspace.openProject(project) }) {
                        HStack {
                            Image(systemName: project.icon)
                                .foregroundColor(MonoColor.secondaryText)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.name)
                                    .font(MonoType.body)
                                    .foregroundColor(MonoColor.primaryText)
                                Text("\(project.primaryLanguage) · \(project.template.displayName)")
                                    .font(MonoType.caption)
                                    .foregroundColor(MonoColor.tertiaryText)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            try? projectStore.delete(project)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Section("Remote Projects") {
                if RemotePCStore.shared.isConnected {
                    RemoteProjectsList()
                } else {
                    Text("Connect a Remote PC in Settings")
                        .font(MonoType.caption)
                        .foregroundColor(MonoColor.tertiaryText)
                }
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showNewProject = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectView()
        }
    }
}

/// Editor page - full screen code editor.
struct EditorPage: View {
    @StateObject private var workspace = WorkspaceState.shared

    var body: some View {
        VStack(spacing: 0) {
            if let file = workspace.activeFile {
                EditorTabBar()
                HairlineDivider()
                CodeEditorView(node: file)
            } else if workspace.openFiles.isEmpty {
                ContentUnavailableView(
                    "No File Open",
                    systemImage: "doc.text",
                    description: Text("Select a file from the Projects page.")
                )
            } else {
                EditorTabBar()
                HairlineDivider()
                if let file = workspace.openFiles.first {
                    CodeEditorView(node: file)
                }
            }
        }
        .navigationTitle("Editor")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// AI page - full screen AI chat.
struct AIPage: View {
    @StateObject private var workspace = WorkspaceState.shared

    var body: some View {
        AIChatView()
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Terminal page - full screen terminal.
struct TerminalPage: View {
    var body: some View {
        TerminalPanelContent()
            .navigationTitle("Terminal")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Preview page - full screen preview.
struct PreviewPage: View {
    var body: some View {
        PreviewView()
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Builds page - full screen builds.
struct BuildsPage: View {
    var body: some View {
        BuildsView()
            .navigationTitle("Builds")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Agents page - full screen agents list.
struct AgentsPage: View {
    var body: some View {
        AgentsListView()
            .navigationTitle("Agents")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Settings page - full screen settings.
struct SettingsPage: View {
    var body: some View {
        SettingsView()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Remote projects list for the projects page.
struct RemoteProjectsList: View {
    @StateObject private var store = RemotePCStore.shared
    @State private var projects: [RemoteProject] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                ForEach(projects) { project in
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(MonoColor.secondaryText)
                        Text(project.name)
                            .font(MonoType.body)
                    }
                }
            }
        }
        .onAppear {
            if let env = store.environment {
                isLoading = true
                Task {
                    projects = (try? await RemoteProjectService.shared.listProjects(in: env.workspacePath)) ?? []
                    isLoading = false
                }
            }
        }
    }
}
