import SwiftUI

// MARK: - Home Page

/// Minimal, spacious home page with overview and quick actions.
public struct HomePage: View {
    let onNavigate: (AppNavPage) -> Void
    @StateObject private var projectStore = ProjectStore.shared
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var auth = AuthManager.shared
    @StateObject private var remoteStore = RemotePCStore.shared

    public init(onNavigate: @escaping (AppNavPage) -> Void) {
        self.onNavigate = onNavigate
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Welcome
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back, \(auth.currentUser?.displayName ?? "Developer")")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Your AI coding workspace is ready.")
                        .font(.system(size: 15))
                        .foregroundColor(Color(white: 0.45))
                }
                .padding(.top, 24)

                // Quick actions
                HStack(spacing: 12) {
                    QuickActionCard(icon: "plus.folder", title: "New Project", subtitle: "Start something new") {
                        onNavigate(.projects)
                    }
                    QuickActionCard(icon: "sparkles", title: "Ask AI", subtitle: "Start a conversation") {
                        onNavigate(.ai)
                    }
                    QuickActionCard(icon: "pc", title: "Connect PC", subtitle: remoteStore.isConnected ? "Connected" : "Set up SSH") {
                        onNavigate(.pcSSH)
                    }
                }

                // Current project
                if let project = workspace.currentProject {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Current Project")
                        Button(action: { onNavigate(.code) }) {
                            HStack(spacing: 12) {
                                Image(systemName: project.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(white: 0.5))
                                    .frame(width: 40)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(project.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("\(project.primaryLanguage) · \(project.template.displayName)")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(white: 0.4))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.3))
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Recent projects
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel("Recent Projects")
                    if projectStore.projects.isEmpty {
                        Text("No projects yet. Create one to get started.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.35))
                            .padding(.vertical, 8)
                    } else {
                        ForEach(projectStore.projects.prefix(4)) { project in
                            Button(action: { workspace.openProject(project); onNavigate(.code) }) {
                                HStack(spacing: 10) {
                                    Image(systemName: project.icon)
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(white: 0.4))
                                        .frame(width: 24)
                                    Text(project.name)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(project.primaryLanguage)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(white: 0.35))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // System status
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel("System Status")
                    HStack(spacing: 24) {
                        StatusIndicator(
                            label: "AI Provider",
                            isOK: KeychainService.has(.openRouterAPIKey) || KeychainService.has(.huggingFaceToken),
                            okText: "Connected",
                            notOKText: "Not set"
                        )
                        StatusIndicator(
                            label: "Remote PC",
                            isOK: remoteStore.isConnected,
                            okText: "Connected",
                            notOKText: "Offline"
                        )
                        StatusIndicator(
                            label: "GitHub",
                            isOK: KeychainService.has(.githubToken),
                            okText: "Connected",
                            notOKText: "Not set"
                        )
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .background(Color.black.opacity(0.85))
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.white.opacity(0.05) : Color.white.opacity(0.03))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(Color(white: 0.35))
    }
}

struct StatusIndicator: View {
    let label: String
    let isOK: Bool
    let okText: String
    let notOKText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.4))
            HStack(spacing: 5) {
                Circle()
                    .fill(isOK ? Color.green : Color(white: 0.2))
                    .frame(width: 6, height: 6)
                Text(isOK ? okText : notOKText)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - AI Chat Page

/// Full-page AI chat experience.
public struct AIChatPage: View {
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var modelStore = CachedModelStore.shared
    @State private var draft = ""
    @State private var showModelPicker = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("AI Assistant")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Button(action: { showModelPicker = true }) {
                    HStack(spacing: 4) {
                        Text(currentModelName)
                            .font(.system(size: 12))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(Color(white: 0.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                if let project = workspace.currentProject {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                        Text(project.name)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Color(white: 0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider().background(Color.white.opacity(0.06))

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if let conv = workspace.currentConversation {
                            ForEach(conv.messages) { msg in
                                ChatMessageView(message: msg)
                                    .id(msg.id)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.95)).animation(.spring(response: 0.4, dampingFraction: 0.8)),
                                        removal: .opacity
                                    ))
                            }
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 36))
                                    .foregroundColor(Color(white: 0.2))
                                Text("Start a conversation")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(white: 0.3))
                                Text("Ask me to build, fix, or explain anything.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(white: 0.2))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                        }
                    }
                    .padding(20)
                }
                .onChange(of: workspace.currentConversation?.messages.count) { _ in
                    if let last = workspace.currentConversation?.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Input
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.06))
                HStack(spacing: 10) {
                    Button(action: {}) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 16))
                            .foregroundColor(Color(white: 0.35))
                    }
                    .buttonStyle(.plain)

                    TextField("Ask anything about your project…", text: $draft, axis: .vertical)
                        .font(.system(size: 14))
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)

                    Button(action: send) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(draft.isEmpty ? Color.gray.opacity(0.2) : Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(draft.isEmpty)
                    .scaleEffect(draft.isEmpty ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: draft.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .background(Color.black.opacity(0.85))
        .sheet(isPresented: $showModelPicker) {
            ModelPickerSheet()
                .presentationDetents([.medium])
        }
    }

    private var currentModelName: String {
        if let id = SettingsStore.shared.primaryModelId,
           let model = modelStore.find(modelId: id) {
            return model.displayName
        }
        return modelStore.freeModels.first?.displayName ?? "Select model"
    }

    private func send() {
        guard let conv = workspace.currentConversation, !draft.isEmpty else { return }
        let userMsg = ChatMessage(role: .user, content: draft)
        ProjectStore.shared.appendMessage(userMsg, to: conv)
        let request = draft
        draft = ""
        Task {
            var mutableConv = conv
            mutableConv.messages.append(userMsg)
            let updated = await AgentOrchestrator.shared.streamSimpleChat(request, project: workspace.currentProject!, conversation: mutableConv) { _ in }
            await MainActor.run {
                workspace.currentConversation = updated
            }
        }
    }
}

struct ModelPickerSheet: View {
    @StateObject private var modelStore = CachedModelStore.shared
    @StateObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Free Models") {
                    ForEach(modelStore.freeModels) { model in
                        Button(action: { settings.primaryModelId = model.modelId; dismiss() }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.displayName)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                    Text(model.displayPrice)
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(white: 0.4))
                                }
                                Spacer()
                                if settings.primaryModelId == model.modelId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.black.opacity(0.95))
        }
    }
}

// MARK: - Projects Page

public struct ProjectsPage: View {
    let onNavigate: (AppNavPage) -> Void
    @StateObject private var projectStore = ProjectStore.shared
    @StateObject private var workspace = WorkspaceState.shared
    @State private var searchQuery = ""
    @State private var showNewProject = false

    public init(onNavigate: @escaping (AppNavPage) -> Void) {
        self.onNavigate = onNavigate
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Projects")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showNewProject = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("New Project")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.35))
                TextField("Search projects…", text: $searchQuery)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))
            .cornerRadius(7)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredProjects) { project in
                        ProjectCard(project: project, isActive: workspace.currentProject?.id == project.id) {
                            workspace.openProject(project)
                            onNavigate(.code)
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)).animation(.spring(response: 0.4, dampingFraction: 0.8)),
                            removal: .opacity
                        ))
                    }
                    if filteredProjects.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 36))
                                .foregroundColor(Color(white: 0.15))
                            Text("No projects found")
                                .font(.system(size: 15))
                                .foregroundColor(Color(white: 0.3))
                            Button("Create your first project") { showNewProject = true }
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color.black.opacity(0.85))
        .sheet(isPresented: $showNewProject) {
            NewProjectView()
        }
    }

    private var filteredProjects: [Project] {
        if searchQuery.isEmpty { return projectStore.projects }
        return projectStore.projects.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }
}

struct ProjectCard: View {
    let project: Project
    let isActive: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: project.icon)
                    .font(.system(size: 22))
                    .foregroundColor(Color(white: 0.4))
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    HStack(spacing: 8) {
                        Text(project.primaryLanguage)
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.4))
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.2))
                        Text(project.template.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.4))
                        if let lastOpened = project.lastOpenedAt {
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.2))
                            Text(lastOpened.formatted(.relative(presentation: .named)))
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.35))
                        }
                    }
                }

                Spacer()

                if isActive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.25))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.white.opacity(0.05) : Color.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isActive ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Code Workspace

public struct CodeWorkspacePage: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var subTab: WorkspaceTab = .editor

    enum WorkspaceTab: String, CaseIterable, Hashable {
        case editor, preview, files, ai
        var title: String {
            switch self {
            case .editor: return "Code"
            case .preview: return "Preview"
            case .files: return "Files"
            case .ai: return "AI"
            }
        }
        var icon: String {
            switch self {
            case .editor: return "chevron.left.slash.chevron.right"
            case .preview: return "eye"
            case .files: return "doc"
            case .ai: return "sparkles"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Sub-tab bar
            HStack(spacing: 2) {
                ForEach(WorkspaceTab.allCases, id: \.self) { tab in
                    Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { subTab = tab } }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11))
                            Text(tab.title)
                                .font(.system(size: 13, weight: subTab == tab ? .medium : .regular))
                        }
                        .foregroundColor(subTab == tab ? .white : Color(white: 0.4))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(subTab == tab ? Color.white.opacity(0.08) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().background(Color.white.opacity(0.06))

            // Content
            Group {
                switch subTab {
                case .editor:
                    EditorPaneView()
                        .transition(.opacity)
                case .preview:
                    PreviewView()
                        .transition(.opacity)
                case .files:
                    FileExplorerView()
                        .transition(.opacity)
                case .ai:
                    AIChatPage()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: subTab)
        }
        .background(Color.black.opacity(0.85))
    }
}

// MARK: - Preview Workspace Page

public struct PreviewWorkspacePage: View {
    public init() {}
    public var body: some View {
        PreviewView()
            .background(Color.black.opacity(0.85))
    }
}

// MARK: - Files Workspace Page

public struct FilesWorkspacePage: View {
    public init() {}
    public var body: some View {
        FileExplorerView()
            .background(Color.black.opacity(0.85))
    }
}

// MARK: - PC / SSH Page

public struct PCSSHPage: View {
    @StateObject private var store = RemotePCStore.shared
    @State private var showAddMachine = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remote PC")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Connect your computer via SSH for remote development")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.4))
                }
                Spacer()
                Button(action: { showAddMachine = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add PC")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // Machine list
            ScrollView {
                LazyVStack(spacing: 12) {
                    if store.machines.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "pc")
                                .font(.system(size: 40))
                                .foregroundColor(Color(white: 0.15))
                            Text("No PCs connected")
                                .font(.system(size: 16))
                                .foregroundColor(Color(white: 0.3))
                            Text("Add your computer to start developing remotely")
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.2))
                            Button("Add PC") { showAddMachine = true }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.top, 80)
                    }

                    ForEach(store.machines) { machine in
                        MachineCard(machine: machine, isActive: store.activeMachineId == machine.id, isConnected: store.isConnected && store.activeMachineId == machine.id) {
                            Task {
                                if store.isConnected && store.activeMachineId == machine.id {
                                    await store.disconnect()
                                } else {
                                    store.setActive(machine)
                                    _ = await store.connect(to: machine)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color.black.opacity(0.85))
        .sheet(isPresented: $showAddMachine) {
            RemoteMachineEditView(machine: nil, isPresented: $showAddMachine)
        }
    }
}

struct MachineCard: View {
    let machine: RemotePC
    let isActive: Bool
    let isConnected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            if isConnected, let env = RemotePCStore.shared.environment {
                metricsSection(env: env)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.white.opacity(0.04) : Color.white.opacity(0.02))
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            pcIcon
            machineInfo
            Spacer()
            connectButton
        }
    }

    private var pcIcon: some View {
        Image(systemName: "pc")
            .font(.system(size: 28))
            .foregroundColor(isConnected ? .green : Color(white: 0.3))
            .frame(width: 40)
    }

    private var machineInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(machine.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                if isConnected {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                }
            }
            Text(machine.username + "@" + machine.host + ":" + String(machine.port))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(white: 0.4))
        }
    }

    private var connectButton: some View {
        Button(action: action) {
            Text(isConnected ? "Disconnect" : "Connect")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isConnected ? .red : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isConnected ? Color.red.opacity(0.1) : Color.white.opacity(0.08))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func metricsSection(env: RemoteEnvironment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().background(Color.white.opacity(0.05))
            HStack(spacing: 20) {
                metricItem("OS", env.os.displayName)
                metricItem("CPU", String(Int(env.cpuUsage * 100)) + "%")
                metricItem("RAM", String(Int(env.ramUsage * 100)) + "%")
                metricItem("Disk", String(Int(env.diskUsage * 100)) + "%")
            }
            Text(env.workspacePath)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(white: 0.35))
        }
    }

    private func metricItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.35))
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Connections Page

public struct ConnectionsPage: View {
    @StateObject private var modelStore = CachedModelStore.shared
    @StateObject private var settings = SettingsStore.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connections")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    Text("AI providers and integrations")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.4))
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // OpenRouter
                    ProviderCard(
                        name: "OpenRouter",
                        icon: "network",
                        description: "Access 100+ AI models including free options",
                        isConnected: KeychainService.has(.openRouterAPIKey),
                        onConfigure: {},
                        onTest: {}
                    )

                    // Hugging Face
                    ProviderCard(
                        name: "Hugging Face",
                        icon: "face.smiling",
                        description: "Free inference for open-source models",
                        isConnected: KeychainService.has(.huggingFaceToken),
                        onConfigure: {},
                        onTest: {}
                    )

                    // GitHub
                    ProviderCard(
                        name: "GitHub",
                        icon: "network",
                        description: "Repository access and Actions integration",
                        isConnected: KeychainService.has(.githubToken),
                        onConfigure: {},
                        onTest: {}
                    )

                    // Model preferences
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Model Preferences")
                        VStack(spacing: 8) {
                            Toggle(isOn: $settings.freeModelsOnly) {
                                Text("Free models only")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                            Toggle(isOn: $settings.allowPaidModels) {
                                Text("Allow paid models")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color.black.opacity(0.85))
    }
}

struct ProviderCard: View {
    let name: String
    let icon: String
    let description: String
    let isConnected: Bool
    let onConfigure: () -> Void
    let onTest: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isConnected ? .green : Color(white: 0.3))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.4))
            }

            Spacer()

            if isConnected {
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Connected")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.4))
                }
            }

            Button("Configure") { onConfigure() }
                .font(.system(size: 13))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.white.opacity(0.04) : Color.white.opacity(0.02))
        )
        .onHover { isHovered = $0 }
    }
}
