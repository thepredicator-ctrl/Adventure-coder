import SwiftUI

/// The redesigned main workspace — a professional multi-panel coding environment.
///
/// Layout:
/// ┌──────────┬───────────────────────┬─────────────────┐
/// │ Sidebar  │     Code Editor       │   AI Assistant  │
/// │          │                       │                 │
/// ├──────────┴───────────────────────┴─────────────────┤
/// │              Bottom Panel (Terminal/Preview/etc)    │
/// └─────────────────────────────────────────────────────┘
public struct RedesignedWorkspace: View {
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var remoteStore = RemotePCStore.shared

    @State private var sidebarWidth: CGFloat = 240
    @State private var aiWidth: CGFloat = 340
    @State private var bottomPanelHeight: CGFloat = 220
    @State private var sidebarVisible: Bool = true
    @State private var aiVisible: Bool = true
    @State private var bottomPanelVisible: Bool = true
    @State private var bottomTab: BottomTab = .terminal
    @State private var showCommandPalette = false
    @State private var showRemotePCPopover = false
    @State private var showGlobalSearch = false

    @Environment(\.horizontalSizeClass) private var hSize

    enum BottomTab: String, CaseIterable, Hashable {
        case terminal, problems, preview, builds, git, remotePC
        var title: String {
            switch self {
            case .terminal: return "Terminal"
            case .problems: return "Problems"
            case .preview: return "Preview"
            case .builds: return "Builds"
            case .git: return "Git"
            case .remotePC: return "Remote PC"
            }
        }
        var icon: String {
            switch self {
            case .terminal: return "terminal"
            case .problems: return "exclamationmark.triangle"
            case .preview: return "eye"
            case .builds: return "hammer"
            case .git: return "arrow.triangle.branch"
            case .remotePC: return "pc"
            }
        }
    }

    public init() {}

    public var body: some View {
        ZStack {
            // CRT background
            SubtleCRTBackground()
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                topBar
                HairlineDivider()
                HStack(spacing: 0) {
                    if sidebarVisible {
                        RedesignedSidebar()
                            .frame(width: sidebarWidth)
                        PanelResizeBar { delta in
                            sidebarWidth = max(180, min(400, sidebarWidth + delta))
                        }
                    }
                    VStack(spacing: 0) {
                        EditorPaneView()
                        if bottomPanelVisible {
                            HairlineDivider()
                            PanelResizeBar(vertical: true) { delta in
                                bottomPanelHeight = max(120, min(500, bottomPanelHeight - delta))
                            }
                            bottomPanel
                                .frame(height: bottomPanelHeight)
                        }
                    }
                    if aiVisible && hSize == .regular {
                        PanelResizeBar { delta in
                            aiWidth = max(280, min(500, aiWidth - delta))
                        }
                        AIPanel()
                            .frame(width: aiWidth)
                    }
                }
            }
            .background(Color.black.opacity(0.85))

            // Overlays
            if showCommandPalette {
                CommandPaletteOverlay(onClose: { showCommandPalette = false })
            }
            if showGlobalSearch {
                GlobalSearchOverlay(onClose: { showGlobalSearch = false })
            }
            if showRemotePCPopover {
                RemotePCPopover(onClose: { showRemotePCPopover = false })
            }
        }
        .preferredColorScheme(settings.colorScheme ?? .dark)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: MonoSpace.md) {
            // Left: project + branch + remote
            HStack(spacing: MonoSpace.sm) {
                Button(action: { sidebarVisible.toggle() }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundColor(MonoColor.secondaryText)
                }
                .buttonStyle(.plain)

                if let project = workspace.currentProject {
                    Text(project.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(project.defaultBranch)
                        .font(.system(size: 12))
                        .foregroundColor(MonoColor.steel)
                }

                // Remote PC indicator
                Button(action: { showRemotePCPopover = true }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(remoteStore.isConnected ? Color.green : MonoColor.steel)
                            .frame(width: 6, height: 6)
                        if let machine = remoteStore.activeMachine {
                            Text(machine.name)
                                .font(.system(size: 12))
                                .foregroundColor(MonoColor.steel)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Right: actions
            HStack(spacing: MonoSpace.md) {
                TopBarButton(icon: "magnifyingglass", shortcut: "⌘F") { showGlobalSearch = true }
                TopBarButton(icon: "command", shortcut: "⌘K") { showCommandPalette = true }
                TopBarButton(icon: "arrow.triangle.branch") {}
                TopBarButton(icon: "hammer") { bottomTab = .builds; bottomPanelVisible = true }
                TopBarButton(icon: "sparkles") { aiVisible.toggle() }
            }
        }
        .padding(.horizontal, MonoSpace.md)
        .frame(height: 40)
        .background(Color.black.opacity(0.9))
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(BottomTab.allCases, id: \.self) { tab in
                    Button(action: { bottomTab = tab }) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 10))
                            Text(tab.title)
                                .font(.system(size: 12, weight: bottomTab == tab ? .semibold : .regular))
                        }
                        .foregroundColor(bottomTab == tab ? .white : MonoColor.steel)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(bottomTab == tab ? Color.white.opacity(0.05) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button(action: { bottomPanelVisible = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(MonoColor.steel)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
            }
            .background(Color.black.opacity(0.9))

            // Content
            Group {
                switch bottomTab {
                case .terminal:
                    if remoteStore.isConnected {
                        RemoteTerminalPanel()
                    } else {
                        TerminalPanelContent()
                    }
                case .problems:
                    ProblemsPanel()
                case .preview:
                    if remoteStore.isConnected {
                        RemotePreviewPanel()
                    } else {
                        PreviewView()
                    }
                case .builds:
                    BuildsView()
                case .git:
                    GitPanelView()
                case .remotePC:
                    RemoteDashboardView()
                }
            }
            .background(Color.black.opacity(0.95))
        }
    }
}

// MARK: - Top Bar Button

struct TopBarButton: View {
    let icon: String
    let shortcut: String?
    let action: () -> Void

    init(icon: String, shortcut: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.shortcut = shortcut
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(MonoColor.steel)
        }
        .buttonStyle(.plain)
        .help(shortcut ?? "")
    }
}

// MARK: - Resize Bar

struct PanelResizeBar: View {
    let vertical: Bool
    let onChange: (CGFloat) -> Void

    @State private var lastDrag: CGFloat = 0

    init(vertical: Bool = false, onChange: @escaping (CGFloat) -> Void) {
        self.vertical = vertical
        self.onChange = onChange
    }

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: vertical ? nil : 1, height: vertical ? 1 : nil)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let delta = vertical ? value.translation.height : value.translation.width
                        onChange(delta - lastDrag)
                        lastDrag = delta
                    }
                    .onEnded { _ in lastDrag = 0 }
            )
    }
}

// MARK: - Redesigned Sidebar

struct RedesignedSidebar: View {
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var remoteStore = RemotePCStore.shared
    @State private var section: SidebarSection = .files

    enum SidebarSection: String, CaseIterable, Hashable {
        case projects, files, search, sourceControl
        case remotePC, terminal, processes
        case preview, builds, logs

        var title: String {
            switch self {
            case .projects: return "Projects"
            case .files: return "Files"
            case .search: return "Search"
            case .sourceControl: return "Source Control"
            case .remotePC: return "Remote PC"
            case .terminal: return "Terminal"
            case .processes: return "Processes"
            case .preview: return "Preview"
            case .builds: return "Builds"
            case .logs: return "Logs"
            }
        }

        var icon: String {
            switch self {
            case .projects: return "folder"
            case .files: return "doc"
            case .search: return "magnifyingglass"
            case .sourceControl: return "arrow.triangle.branch"
            case .remotePC: return "pc"
            case .terminal: return "terminal"
            case .processes: return "list.bullet"
            case .preview: return "eye"
            case .builds: return "hammer"
            case .logs: return "text.alignleft"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section selector
            VStack(alignment: .leading, spacing: 0) {
                sidebarHeader("Workspace")
                sidebarButton(.projects)
                sidebarButton(.files)
                sidebarButton(.search)
                sidebarButton(.sourceControl)

                sidebarHeader("Remote")
                sidebarButton(.remotePC)
                sidebarButton(.terminal)
                sidebarButton(.processes)

                sidebarHeader("Development")
                sidebarButton(.preview)
                sidebarButton(.builds)
                sidebarButton(.logs)
            }
            .padding(.vertical, MonoSpace.sm)

            Divider()
                .background(Color.white.opacity(0.05))

            // Section content
            ScrollView {
                sectionContent
                    .padding(.vertical, MonoSpace.sm)
            }
        }
        .background(Color.black.opacity(0.9))
    }

    private func sidebarHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(MonoColor.steel)
            .padding(.horizontal, MonoSpace.md)
            .padding(.top, MonoSpace.sm)
            .padding(.bottom, MonoSpace.xxs)
    }

    private func sidebarButton(_ s: SidebarSection) -> some View {
        Button(action: { section = s }) {
            HStack(spacing: 8) {
                Image(systemName: s.icon)
                    .font(.system(size: 12))
                    .foregroundColor(section == s ? .white : MonoColor.steel)
                    .frame(width: 16)
                Text(s.title)
                    .font(.system(size: 13))
                    .foregroundColor(section == s ? .white : MonoColor.steel)
                Spacer()
            }
            .padding(.horizontal, MonoSpace.md)
            .padding(.vertical, 5)
            .background(section == s ? Color.white.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .projects:
            ProjectsListSection()
        case .files:
            FileTreeSection()
        case .search:
            SearchSection()
        case .sourceControl:
            SourceControlSection()
        case .remotePC:
            RemotePCSection()
        case .terminal:
            TerminalInfoSection()
        case .processes:
            ProcessesSection()
        case .preview:
            PreviewInfoSection()
        case .builds:
            BuildsListSection()
        case .logs:
            LogsSection()
        }
    }
}

// MARK: - Sidebar Sections

struct ProjectsListSection: View {
    @StateObject private var store = ProjectStore.shared
    @StateObject private var workspace = WorkspaceState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(store.projects) { project in
                Button(action: { workspace.openProject(project) }) {
                    HStack(spacing: 6) {
                        Image(systemName: project.icon)
                            .font(.system(size: 11))
                            .foregroundColor(MonoColor.steel)
                        Text(project.name)
                            .font(.system(size: 13))
                            .foregroundColor(workspace.currentProject?.id == project.id ? .white : MonoColor.steel)
                        Spacer()
                    }
                    .padding(.horizontal, MonoSpace.md)
                    .padding(.vertical, 3)
                    .background(workspace.currentProject?.id == project.id ? Color.white.opacity(0.04) : Color.clear)
                }
                .buttonStyle(.plain)
            }
            if store.projects.isEmpty {
                Text("No projects yet")
                    .font(.system(size: 12))
                    .foregroundColor(MonoColor.steel)
                    .padding(.horizontal, MonoSpace.md)
            }
        }
    }
}

struct FileTreeSection: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var nodes: [FileNode] = []
    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let project = workspace.currentProject {
                // Path indicator
                Text(project.rootPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(MonoColor.steel)
                    .padding(.horizontal, MonoSpace.md)
                    .padding(.bottom, 4)

                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 5, height: 5)
                    Text("Remote")
                        .font(.system(size: 10))
                        .foregroundColor(MonoColor.steel)
                }
                .padding(.horizontal, MonoSpace.md)
                .padding(.bottom, 4)

                // File tree
                ForEach(nodes, id: \.relativePath) { node in
                    fileRow(node, depth: 0)
                }
            } else {
                Text("No project open")
                    .font(.system(size: 12))
                    .foregroundColor(MonoColor.steel)
                    .padding(.horizontal, MonoSpace.md)
            }
        }
        .onAppear(perform: refresh)
        .onChange(of: workspace.currentProject?.id) { _ in refresh() }
    }

    @ViewBuilder
    private func fileRow(_ node: FileNode, depth: Int) -> some View {
        VStack(spacing: 0) {
            fileRowContent(node, depth: depth)
            if node.isDirectory && expanded.contains(node.relativePath) {
                ForEach(node.children, id: \.relativePath) { child in
                    AnyView(fileRow(child, depth: depth + 1))
                }
            }
        }
    }

    @ViewBuilder
    private func fileRowContent(_ node: FileNode, depth: Int) -> some View {
        let indent = CGFloat(depth) * 12
        Button(action: {
            if node.isDirectory {
                if expanded.contains(node.relativePath) {
                    expanded.remove(node.relativePath)
                } else {
                    expanded.insert(node.relativePath)
                }
            } else {
                workspace.openFile(node)
            }
        }) {
            HStack(spacing: 4) {
                if node.isDirectory {
                    Image(systemName: expanded.contains(node.relativePath) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(MonoColor.steel)
                }
                Image(systemName: node.isDirectory ? "folder" : node.fileIcon)
                    .font(.system(size: 10))
                    .foregroundColor(MonoColor.steel)
                Text(node.name)
                    .font(.system(size: 12, design: node.isDirectory ? .default : .monospaced))
                    .foregroundColor(workspace.activeFile?.relativePath == node.relativePath ? .white : MonoColor.steel)
                Spacer()
            }
            .padding(.horizontal, MonoSpace.md)
            .padding(.leading, indent)
            .padding(.vertical, 2)
            .background(workspace.activeFile?.relativePath == node.relativePath ? Color.white.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func refresh() {
        guard let project = workspace.currentProject else { return }
        nodes = (try? FileSystem.shared.list(directory: project.rootPath)) ?? []
    }
}

struct SearchSection: View {
    @State private var query = ""
    @State private var results: [FileSystem.SearchHit] = []
    @StateObject private var workspace = WorkspaceState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Search files…", text: $query, onCommit: search)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.horizontal, MonoSpace.md)

            ForEach(results.prefix(20), id: \.self) { hit in
                VStack(alignment: .leading, spacing: 1) {
                    Text(hit.relativePath)
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                    Text("L\(hit.line): \(hit.snippet)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(MonoColor.steel)
                        .lineLimit(1)
                }
                .padding(.horizontal, MonoSpace.md)
                .padding(.vertical, 2)
            }
        }
    }

    private func search() {
        guard let project = workspace.currentProject else { return }
        results = (try? FileSystem.shared.search(query: query, in: project.rootPath)) ?? []
    }
}

struct SourceControlSection: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var status = ""
    @State private var branch = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let project = workspace.currentProject {
                if !branch.isEmpty {
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10))
                            .foregroundColor(MonoColor.steel)
                        Text(branch)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, MonoSpace.md)
                }
                Text(status)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(MonoColor.steel)
                    .padding(.horizontal, MonoSpace.md)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.horizontal, MonoSpace.md)
            } else {
                Text("No project open")
                    .font(.system(size: 12))
                    .foregroundColor(MonoColor.steel)
                    .padding(.horizontal, MonoSpace.md)
            }
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        guard let project = workspace.currentProject else { return }
        if case .success(let s) = GitService.shared.status(project: project) {
            status = s
        }
        if case .success(let b) = GitService.shared.branches(project: project) {
            branch = b.first(where: { $0.isCurrent })?.name ?? ""
        }
    }
}

struct RemotePCSection: View {
    @StateObject private var store = RemotePCStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let machine = store.activeMachine {
                HStack {
                    Circle().fill(store.isConnected ? Color.green : MonoColor.steel).frame(width: 6, height: 6)
                    Text(machine.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, MonoSpace.md)

                infoRow("Host", machine.host)
                infoRow("User", machine.username)
                infoRow("Port", "\(machine.port)")
                if let env = store.environment {
                    infoRow("OS", env.os.displayName)
                    infoRow("Workspace", env.workspacePath)
                    infoRow("CPU", "\(Int(env.cpuUsage * 100))%")
                    infoRow("RAM", "\(Int(env.ramUsage * 100))%")
                    infoRow("Disk", "\(Int(env.diskUsage * 100))%")
                }
            } else {
                Text("No remote PC configured")
                    .font(.system(size: 12))
                    .foregroundColor(MonoColor.steel)
                    .padding(.horizontal, MonoSpace.md)
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(MonoColor.steel)
            Spacer()
            Text(value)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, MonoSpace.md)
        .padding(.vertical, 1)
    }
}

struct TerminalInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Terminal sessions appear in the bottom panel.")
                .font(.system(size: 12))
                .foregroundColor(MonoColor.steel)
                .padding(.horizontal, MonoSpace.md)
        }
    }
}

struct ProcessesSection: View {
    @State private var processes: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if RemotePCStore.shared.isConnected {
                Button(action: refresh) {
                    Label("Refresh Processes", systemImage: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, MonoSpace.md)

                Text(processes)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(MonoColor.steel)
                    .padding(.horizontal, MonoSpace.md)
            } else {
                Text("Not connected")
                    .font(.system(size: 12))
                    .foregroundColor(MonoColor.steel)
                    .padding(.horizontal, MonoSpace.md)
            }
        }
    }

    private func refresh() {
        Task {
            if let result = try? await SSHService.shared.execute("powershell -Command \"Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Id, Name, CPU | Format-Table -AutoSize\"") {
                await MainActor.run { processes = result.stdout }
            }
        }
    }
}

struct PreviewInfoSection: View {
    @StateObject private var previewService = RemotePreviewService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let preview = previewService.activePreview {
                Text("Preview Running")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(preview.url)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.green)
                Text("Port: \(preview.port)")
                    .font(.system(size: 11))
                    .foregroundColor(MonoColor.steel)
            } else {
                Text("No preview running")
                    .font(.system(size: 12))
                    .foregroundColor(MonoColor.steel)
            }
        }
        .padding(.horizontal, MonoSpace.md)
    }
}

struct BuildsListSection: View {
    var body: some View {
        Text("Recent builds appear in the bottom panel.")
            .font(.system(size: 12))
            .foregroundColor(MonoColor.steel)
            .padding(.horizontal, MonoSpace.md)
    }
}

struct LogsSection: View {
    @State private var logs: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if RemotePCStore.shared.isConnected {
                Button(action: refresh) {
                    Label("Refresh Logs", systemImage: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, MonoSpace.md)

                Text(logs)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(MonoColor.steel)
                    .padding(.horizontal, MonoSpace.md)
            } else {
                Text("Not connected")
                    .font(.system(size: 12))
                    .foregroundColor(MonoColor.steel)
                    .padding(.horizontal, MonoSpace.md)
            }
        }
    }

    private func refresh() {
        Task {
            if let result = try? await SSHService.shared.execute("tail -50 /tmp/process.log 2>/dev/null || powershell -Command \"Get-Content /tmp/process.log -Tail 50 2>$null\"") {
                await MainActor.run { logs = result.stdout }
            }
        }
    }
}

// MARK: - Git Panel

struct GitPanelView: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var status = ""
    @State private var diff = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let project = workspace.currentProject {
                Text("Git Status")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(status)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(MonoColor.steel)

                if !diff.isEmpty {
                    Text("Diff")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    ScrollView {
                        Text(diff)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(MonoColor.steel)
                    }
                }
            } else {
                Text("No project open")
                    .font(.system(size: 12))
                    .foregroundColor(MonoColor.steel)
            }
            Spacer()
        }
        .padding()
        .onAppear(perform: refresh)
    }

    private func refresh() {
        guard let project = workspace.currentProject else { return }
        if case .success(let s) = GitService.shared.status(project: project) { status = s }
        if case .success(let d) = GitService.shared.diff(project: project, staged: false) { diff = d }
    }
}

// MARK: - Overlays

struct CommandPaletteOverlay: View {
    @State private var query = ""
    @FocusState private var focused: Bool
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(MonoColor.steel)
                    TextField("Search commands…", text: $query)
                        .font(.system(size: 14))
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .submitLabel(.go)
                }
                .padding(12)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredCommands, id: \.id) { cmd in
                            Button(action: { cmd.action(); onClose() }) {
                                HStack {
                                    Image(systemName: cmd.icon)
                                        .foregroundColor(MonoColor.steel)
                                        .frame(width: 20)
                                    Text(cmd.title)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.03))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: 500)
            .frame(maxHeight: 400)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(40)
        }
        .onAppear { focused = true }
    }

    private var commands: [CommandManager.UserCommand] {
        CommandManager.shared.allCommands
    }

    private var filteredCommands: [CommandManager.UserCommand] {
        if query.isEmpty { return commands }
        return commands.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}

struct GlobalSearchOverlay: View {
    @State private var query = ""
    @FocusState private var focused: Bool
    @StateObject private var workspace = WorkspaceState.shared
    @State private var fileResults: [FileSystem.SearchHit] = []
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(MonoColor.steel)
                    TextField("Search files, projects, conversations…", text: $query, onCommit: search)
                        .font(.system(size: 14))
                        .textFieldStyle(.plain)
                        .focused($focused)
                }
                .padding(12)
                .background(Color.black)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(fileResults.prefix(30), id: \.self) { hit in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hit.relativePath)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                Text("L\(hit.line): \(hit.snippet)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(MonoColor.steel)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .frame(maxWidth: 600)
            .frame(maxHeight: 500)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(40)
        }
        .onAppear { focused = true }
    }

    private func search() {
        guard let project = workspace.currentProject else { return }
        fileResults = (try? FileSystem.shared.search(query: query, in: project.rootPath)) ?? []
    }
}

struct RemotePCPopover: View {
    @StateObject private var store = RemotePCStore.shared
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    if let machine = store.activeMachine {
                        Circle()
                            .fill(store.isConnected ? Color.green : MonoColor.steel)
                            .frame(width: 8, height: 8)
                        Text(machine.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundColor(MonoColor.steel)
                    }
                    .buttonStyle(.plain)
                }

                if let machine = store.activeMachine {
                    infoRow("Host", machine.host)
                    infoRow("User", machine.username)
                    if let env = store.environment {
                        infoRow("OS", "\(env.os.displayName) \(env.osVersion)")
                        infoRow("Workspace", env.workspacePath)

                        Divider().background(Color.white.opacity(0.05))

                        metricRow("CPU", env.cpuUsage)
                        metricRow("Memory", env.ramUsage)
                        metricRow("Disk", env.diskUsage)
                    }

                    Divider().background(Color.white.opacity(0.05))

                    HStack(spacing: 8) {
                        Button("Open Terminal") {}
                            .buttonStyle(.bordered)
                        Button("Open Workspace") {}
                            .buttonStyle(.bordered)
                        Spacer()
                        Button("Disconnect", role: .destructive) {
                            Task { await store.disconnect() }
                        }
                    }
                } else {
                    Text("No remote PC configured")
                        .font(.system(size: 13))
                        .foregroundColor(MonoColor.steel)
                }
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(40)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(MonoColor.steel)
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }

    private func metricRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(MonoColor.steel)
            Spacer()
            ProgressView(value: value)
                .frame(width: 100)
                .tint(value > 0.8 ? .red : (value > 0.6 ? .yellow : .green))
            Text("\(Int(value * 100))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(MonoColor.steel)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

// MARK: - AI Panel

struct AIPanel: View {
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @StateObject private var modelStore = CachedModelStore.shared
    @State private var draft = ""
    @State private var showModelPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI Assistant")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showModelPicker = true }) {
                    HStack(spacing: 4) {
                        Text(currentModelName)
                            .font(.system(size: 11))
                            .foregroundColor(MonoColor.steel)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(MonoColor.steel)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().background(Color.white.opacity(0.05))

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if let conv = workspace.currentConversation {
                            ForEach(conv.messages) { msg in
                                ChatMessageView(message: msg).id(msg.id)
                            }
                        }
                        if orchestrator.isRunning {
                            agentActivityView
                        }
                    }
                    .padding(12)
                }
                .onChange(of: workspace.currentConversation?.messages.count) { _ in
                    if let last = workspace.currentConversation?.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Input
            HStack(spacing: 8) {
                TextField("Ask anything…", text: $draft, axis: .vertical)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(draft.isEmpty ? Color.gray.opacity(0.3) : Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(draft.isEmpty)
            }
            .padding(12)
        }
        .background(Color.black.opacity(0.9))
        .sheet(isPresented: $showModelPicker) {
            CompactModelPicker()
                .presentationDetents([.medium])
        }
    }

    private var currentModelName: String {
        if let id = SettingsStore.shared.primaryModelId,
           let model = modelStore.find(modelId: id) {
            return model.displayName
        }
        return modelStore.freeModels.first?.displayName ?? "No model"
    }

    private var agentActivityView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Building your application")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)

            ForEach(orchestrator.activities) { activity in
                HStack(spacing: 6) {
                    switch activity.status {
                    case .completed:
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                    case .running:
                        Image(systemName: "arrow.right")
                            .foregroundColor(.yellow)
                    case .failed:
                        Image(systemName: "xmark")
                            .foregroundColor(.red)
                    default:
                        Image(systemName: "circle")
                            .foregroundColor(MonoColor.steel)
                    }
                    Text(activity.summary)
                        .font(.system(size: 11))
                        .foregroundColor(MonoColor.steel)
                }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
            workspace.currentConversation = updated
        }
    }
}

struct CompactModelPicker: View {
    @StateObject private var modelStore = CachedModelStore.shared
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Free Models") {
                    ForEach(modelStore.freeModels) { model in
                        Button(action: {
                            settings.primaryModelId = model.modelId
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.displayName)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                    Text(model.displayPrice)
                                        .font(.system(size: 10))
                                        .foregroundColor(MonoColor.steel)
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
            .navigationTitle("Models")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - First-Time Setup

struct FirstTimeConnectionView: View {
    @State private var host = ""
    @State private var username = ""
    @State private var password = ""
    @State private var port = "22"
    @State private var isConnecting = false
    @State private var error: String?
    @StateObject private var store = RemotePCStore.shared

    var body: some View {
        ZStack {
            SubtleCRTBackground()
                .ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("Connect your PC")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Use your iPad as a powerful\nremote development workstation.")
                        .font(.system(size: 14))
                        .foregroundColor(MonoColor.steel)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Host")
                            .font(.system(size: 12))
                            .foregroundColor(MonoColor.steel)
                        TextField("192.168.1.100", text: $host)
                            .font(.system(size: 14, design: .monospaced))
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username")
                            .font(.system(size: 12))
                            .foregroundColor(MonoColor.steel)
                        TextField("Neth", text: $username)
                            .font(.system(size: 14, design: .monospaced))
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.system(size: 12))
                            .foregroundColor(MonoColor.steel)
                        SecureField("•••••••••", text: $password)
                            .font(.system(size: 14, design: .monospaced))
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Port")
                            .font(.system(size: 12))
                            .foregroundColor(MonoColor.steel)
                        TextField("22", text: $port)
                            .font(.system(size: 14, design: .monospaced))
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .keyboardType(.numberPad)
                    }
                }
                .frame(maxWidth: 360)

                if let error = error {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }

                Button(action: connect) {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isConnecting ? "Connecting…" : "Connect")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(host.isEmpty ? Color.gray.opacity(0.3) : Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(host.isEmpty || isConnecting)
                .frame(maxWidth: 360)

                Text("Your credentials are stored securely in Keychain.")
                    .font(.system(size: 11))
                    .foregroundColor(MonoColor.steel)

                Button("Help — How to enable SSH on my PC") {}
                    .font(.system(size: 11))
                    .foregroundColor(MonoColor.steel)
            }
            .padding(40)
        }
    }

    private func connect() {
        isConnecting = true
        error = nil
        let machine = RemotePC(
            name: host,
            host: host,
            port: Int(port) ?? 22,
            username: username,
            authMethod: .password
        )
        store.addMachine(machine)
        store.savePassword(password, for: machine)
        Task {
            let result = await store.connect(to: machine)
            await MainActor.run {
                isConnecting = false
                if !result.success {
                    error = result.message
                    store.removeMachine(machine)
                }
            }
        }
    }
}
