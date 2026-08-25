import SwiftUI

/// Left sidebar: project navigation, file explorer, search, git, projects list, remote.
public struct SidebarView: View {
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var remoteStore = RemotePCStore.shared
    @State private var section: Section = .files

    enum Section: String, CaseIterable, Hashable {
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

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ProjectHeader()
            // Remote PC status indicator
            HStack {
                RemotePCStatusIndicator()
                Spacer()
            }
            .padding(.horizontal, MonoSpace.md)
            .padding(.vertical, MonoSpace.xs)
            HStack(spacing: 0) {
                ForEach(Section.allCases, id: \.self) { s in
                    Button(action: { section = s }) {
                        Image(systemName: s.icon)
                            .font(.system(size: 13, weight: .regular))
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .foregroundColor(section == s ? MonoColor.primaryText : MonoColor.tertiaryText)
                            .background(section == s ? MonoColor.cloud : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(alignment: .top) { HairlineDivider() }
            .overlay(alignment: .bottom) { HairlineDivider() }

            ScrollView {
                switch section {
                case .files:
                    if remoteStore.isConnected && workspace.currentRemoteProject != nil {
                        RemoteFileExplorerView()
                    } else {
                        FileExplorerView()
                    }
                case .search: SearchSidebarSection()
                case .git:
                    if remoteStore.isConnected && workspace.currentRemoteProject != nil {
                        RemoteGitSidebarSection()
                    } else {
                        GitSidebarSection()
                    }
                case .projects: ProjectsSidebarSection()
                case .remote: RemoteSidebarSection()
                }
            }
            Spacer(minLength: 0)
        }
        .background(MonoColor.panel)
    }
}

struct ProjectHeader: View {
    @StateObject private var workspace = WorkspaceState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.xs) {
            HStack {
                Image(systemName: workspace.currentProject?.icon ?? MonoIcon.stack)
                    .foregroundColor(MonoColor.primaryText)
                Text(workspace.currentProject?.name ?? "No Project")
                    .font(MonoType.title2)
                    .foregroundColor(MonoColor.primaryText)
                Spacer()
                Button(action: { workspace.sidebarCollapsed = true }) {
                    Image(systemName: MonoIcon.sidebar)
                        .foregroundColor(MonoColor.tertiaryText)
                }
                .buttonStyle(.plain)
                .help("Collapse sidebar")
            }
            if let project = workspace.currentProject {
                HStack(spacing: 6) {
                    Circle().fill(MonoColor.success).frame(width: 6, height: 6)
                    Text(project.defaultBranch)
                        .font(MonoType.caption)
                        .foregroundColor(MonoColor.secondaryText)
                    if let repo = project.githubRepo {
                        Text("· \(repo)")
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.tertiaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, MonoSpace.md)
        .padding(.vertical, MonoSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonoColor.panel)
    }
}

struct SearchSidebarSection: View {
    @State private var query: String = ""
    @State private var results: [FileSystem.SearchHit] = []
    @StateObject private var workspace = WorkspaceState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.sm) {
            SectionHeader("Search")
            HStack {
                Image(systemName: MonoIcon.search)
                    .foregroundColor(MonoColor.tertiaryText)
                TextField("Search files…", text: $query, onCommit: performSearch)
                    .font(MonoType.body)
                    .submitLabel(.search)
            }
            .padding(.horizontal, MonoSpace.md)
            .padding(.vertical, MonoSpace.xs + 2)
            .background(MonoColor.inset)
            .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))
            .padding(.horizontal, MonoSpace.md)

            if results.isEmpty && !query.isEmpty {
                Text("No matches")
                    .font(MonoType.footnote)
                    .foregroundColor(MonoColor.tertiaryText)
                    .padding(.horizontal, MonoSpace.md)
            }
            ForEach(results.prefix(100), id: \.self) { hit in
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.relativePath)
                        .font(MonoType.caption.weight(.medium))
                        .foregroundColor(MonoColor.primaryText)
                    Text("Line \(hit.line): \(hit.snippet)")
                        .font(MonoType.caption)
                        .foregroundColor(MonoColor.secondaryText)
                        .lineLimit(2)
                }
                .padding(.horizontal, MonoSpace.md)
                .padding(.vertical, MonoSpace.xs)
                .onTapGesture {
                    if let project = workspace.currentProject,
                       let node = try? FileSystem.shared.list(directory: project.rootPath).first(where: { $0.relativePath == hit.relativePath }) {
                        workspace.openFile(node)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, MonoSpace.sm)
    }

    private func performSearch() {
        guard let project = workspace.currentProject else { return }
        results = (try? FileSystem.shared.search(query: query, in: project.rootPath, maxResults: 200)) ?? []
    }
}

struct GitSidebarSection: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var status: String = ""
    @State private var branches: [GitReference] = []

    var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.sm) {
            SectionHeader("Git") {
                AnyView(
                    Button(action: refresh) {
                        Image(systemName: MonoIcon.refresh)
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                    .buttonStyle(.plain)
                )
            }

            if let project = workspace.currentProject {
                if !GitService.shared.isRepo(project) {
                    VStack(alignment: .leading, spacing: MonoSpace.sm) {
                        Text("Not a git repository")
                            .font(MonoType.footnote)
                            .foregroundColor(MonoColor.tertiaryText)
                        Button("Initialize repository") {
                            if case .success = GitService.shared.initialize(project) {
                                refresh()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, MonoSpace.md)
                } else {
                    VStack(alignment: .leading, spacing: MonoSpace.sm) {
                        Text(status)
                            .font(MonoType.codeSmall)
                            .foregroundColor(MonoColor.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(MonoSpace.sm)
                            .background(MonoColor.inset)
                            .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))
                            .padding(.horizontal, MonoSpace.md)

                        SectionHeader("Branches")
                        ForEach(branches, id: \.name) { ref in
                            HStack {
                                Image(systemName: ref.isCurrent ? MonoIcon.check : MonoIcon.branch)
                                    .foregroundColor(ref.isCurrent ? MonoColor.active : MonoColor.tertiaryText)
                                Text(ref.name)
                                    .font(MonoType.body)
                                    .foregroundColor(MonoColor.primaryText)
                                Spacer()
                                Text(String(ref.sha.prefix(7)))
                                    .font(MonoType.caption)
                                    .foregroundColor(MonoColor.tertiaryText)
                            }
                            .padding(.horizontal, MonoSpace.md)
                            .padding(.vertical, MonoSpace.xs)
                            .onTapGesture {
                                if case .success = GitService.shared.checkout(project: project, branch: ref.name) {
                                    refresh()
                                }
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, MonoSpace.sm)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        guard let project = workspace.currentProject else { return }
        if case .success(let s) = GitService.shared.status(project: project) {
            status = s
        }
        if case .success(let b) = GitService.shared.branches(project: project) {
            branches = b
        }
    }
}

struct ProjectsSidebarSection: View {
    @StateObject private var projectStore = ProjectStore.shared
    @StateObject private var workspace = WorkspaceState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.sm) {
            SectionHeader("Projects") {
                AnyView(
                    NavigationLink(value: NavRoute.newProject) {
                        Image(systemName: MonoIcon.plus)
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                    .buttonStyle(.plain)
                )
            }
            ForEach(projectStore.projects) { project in
                SelectableRow(isSelected: workspace.currentProject?.id == project.id, action: { workspace.openProject(project) }) {
                    HStack {
                        Image(systemName: project.icon)
                            .foregroundColor(MonoColor.secondaryText)
                        Text(project.name)
                            .font(MonoType.body)
                            .foregroundColor(MonoColor.primaryText)
                        Spacer()
                        Text(project.primaryLanguage)
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                }
            }
            if projectStore.projects.isEmpty {
                Text("No projects yet. Tap + to create one.")
                    .font(MonoType.footnote)
                    .foregroundColor(MonoColor.tertiaryText)
                    .padding(.horizontal, MonoSpace.md)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, MonoSpace.sm)
    }
}

struct RemoteSidebarSection: View {
    @StateObject private var store = RemotePCStore.shared
    @StateObject private var workspace = WorkspaceState.shared
    @State private var remoteProjects: [RemoteProject] = []
    @State private var isLoading = false
    @State private var showNewProject = false

    var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.sm) {
            SectionHeader("Remote Projects") {
                AnyView(
                    Button(action: { showNewProject = true }) {
                        Image(systemName: MonoIcon.plus)
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.isConnected)
                )
            }

            if !store.isConnected {
                Text("Not connected to a remote PC.")
                    .font(MonoType.footnote)
                    .foregroundColor(MonoColor.tertiaryText)
                    .padding(.horizontal, MonoSpace.md)
                NavigationLink {
                    RemoteSettingsView()
                } label: {
                    Label("Configure Remote PC", systemImage: "pc")
                        .font(MonoType.body)
                }
                .padding(.horizontal, MonoSpace.md)
            } else if isLoading {
                ProgressView()
                    .padding(.horizontal, MonoSpace.md)
            } else {
                ForEach(remoteProjects) { project in
                    let isActive = workspace.currentRemoteProject?.path == project.path
                    SelectableRow(isSelected: isActive, action: {
                        Task {
                            let template = await RemoteProjectService.shared.detectTemplate(at: project.path)
                            await MainActor.run {
                                workspace.openRemoteProject(project, template: template)
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: MonoIcon.folder)
                                .foregroundColor(MonoColor.secondaryText)
                            Text(project.name)
                                .font(MonoType.body)
                                .foregroundColor(MonoColor.primaryText)
                            Spacer()
                        }
                    }
                }
                if remoteProjects.isEmpty {
                    Text("No projects on the remote PC yet.")
                        .font(MonoType.footnote)
                        .foregroundColor(MonoColor.tertiaryText)
                        .padding(.horizontal, MonoSpace.md)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, MonoSpace.sm)
        .onAppear(perform: loadProjects)
        .sheet(isPresented: $showNewProject) {
            RemoteNewProjectSheet(isPresented: $showNewProject)
        }
    }

    private func loadProjects() {
        guard store.isConnected, let env = store.environment else { return }
        isLoading = true
        Task {
            do {
                remoteProjects = try await RemoteProjectService.shared.listProjects(in: env.workspacePath)
            } catch {
                remoteProjects = []
            }
            await MainActor.run { isLoading = false }
        }
    }
}

struct RemoteNewProjectSheet: View {
    @Binding var isPresented: Bool
    @State private var name: String = ""
    @State private var template: ProjectTemplate = .react
    @State private var isCreating = false
    @State private var error: String?
    @StateObject private var store = RemotePCStore.shared
    @StateObject private var workspace = WorkspaceState.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("New Remote Project") {
                    TextField("Project name", text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Picker("Template", selection: $template) {
                        ForEach(ProjectTemplate.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                }
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(MonoColor.error)
                    }
                }
                if isCreating {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Creating project on \(store.activeMachine?.name ?? "remote PC")…")
                        }
                    }
                }
            }
            .navigationTitle("New Remote Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createProject() }
                        .disabled(name.isEmpty || isCreating)
                }
            }
        }
    }

    private func createProject() {
        guard let env = store.environment else { return }
        isCreating = true
        error = nil
        Task {
            do {
                let path = try await RemoteProjectService.shared.createProject(name: name, template: template, in: env.workspacePath)
                let project = RemoteProject(name: name.replacingOccurrences(of: " ", with: "_"), path: path, modifiedAt: Date())
                await MainActor.run {
                    workspace.openRemoteProject(project, template: template)
                    isCreating = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

struct RemoteGitSidebarSection: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var status: String = ""
    @State private var branch: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.sm) {
            SectionHeader("Remote Git") {
                AnyView(
                    Button(action: refresh) {
                        Image(systemName: MonoIcon.refresh)
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                    .buttonStyle(.plain)
                )
            }

            if let project = workspace.currentRemoteProject {
                VStack(alignment: .leading, spacing: MonoSpace.sm) {
                    Text(status)
                        .font(MonoType.codeSmall)
                        .foregroundColor(MonoColor.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(MonoSpace.sm)
                        .background(MonoColor.inset)
                        .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))
                        .padding(.horizontal, MonoSpace.md)

                    if !branch.isEmpty {
                        HStack {
                            Image(systemName: MonoIcon.branch)
                                .foregroundColor(MonoColor.secondaryText)
                            Text(branch)
                                .font(MonoType.body)
                                .foregroundColor(MonoColor.primaryText)
                        }
                        .padding(.horizontal, MonoSpace.md)
                    }

                    HStack(spacing: MonoSpace.sm) {
                        Button("Commit") { Task { await commit() } }
                            .buttonStyle(.bordered)
                            .font(MonoType.caption)
                        Button("Push") { Task { await push() } }
                            .buttonStyle(.bordered)
                            .font(MonoType.caption)
                        Button("Pull") { Task { await pull() } }
                            .buttonStyle(.bordered)
                            .font(MonoType.caption)
                    }
                    .padding(.horizontal, MonoSpace.md)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, MonoSpace.sm)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        guard let project = workspace.currentRemoteProject else { return }
        Task {
            do {
                let result = try await SSHService.shared.execute("cd '\(project.path.replacingOccurrences(of: "'", with: "'\\''"))' && git status 2>&1")
                let branchResult = try await SSHService.shared.execute("cd '\(project.path.replacingOccurrences(of: "'", with: "'\\''"))' && git branch --show-current 2>/dev/null")
                await MainActor.run {
                    status = result.stdout
                    branch = branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } catch {}
        }
    }

    private func commit() {
        guard let project = workspace.currentRemoteProject else { return }
        Task {
            _ = try? await SSHService.shared.execute("cd '\(project.path.replacingOccurrences(of: "'", with: "'\\''"))' && git add -A && git commit -m 'Adventure Coder: update files'")
            refresh()
        }
    }

    private func push() {
        guard let project = workspace.currentRemoteProject else { return }
        Task {
            _ = try? await SSHService.shared.execute("cd '\(project.path.replacingOccurrences(of: "'", with: "'\\''"))' && git push")
            refresh()
        }
    }

    private func pull() {
        guard let project = workspace.currentRemoteProject else { return }
        Task {
            _ = try? await SSHService.shared.execute("cd '\(project.path.replacingOccurrences(of: "'", with: "'\\''"))' && git pull")
            refresh()
        }
    }
}

enum NavRoute: Hashable {
    case newProject
    case settings
    case commandPalette
}
