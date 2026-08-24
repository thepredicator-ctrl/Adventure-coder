import SwiftUI

/// Left sidebar: project navigation, file explorer, search, git, projects list.
public struct SidebarView: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var section: Section = .files

    enum Section: String, CaseIterable, Hashable {
        case files, search, git, projects
        var title: String {
            switch self {
            case .files: return "Files"
            case .search: return "Search"
            case .git: return "Git"
            case .projects: return "Projects"
            }
        }
        var icon: String {
            switch self {
            case .files: return MonoIcon.doc
            case .search: return MonoIcon.search
            case .git: return MonoIcon.branch
            case .projects: return MonoIcon.folder
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ProjectHeader()
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
                case .files: FileExplorerView()
                case .search: SearchSidebarSection()
                case .git: GitSidebarSection()
                case .projects: ProjectsSidebarSection()
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

enum NavRoute: Hashable {
    case newProject
    case settings
    case commandPalette
}
