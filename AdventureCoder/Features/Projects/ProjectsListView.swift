import SwiftUI

/// New project sheet with functional templates.
public struct NewProjectView: View {
    @State private var name: String = ""
    @State private var template: ProjectTemplate = .swiftUI
    @State private var error: String?
    @State private var creating = false
    @State private var created: Project?
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Project")
                    .font(MonoType.title2)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: MonoIcon.close)
                        .foregroundColor(MonoColor.tertiaryText)
                }
                .buttonStyle(.plain)
            }
            .padding()
            HairlineDivider()
            Form {
                Section("Name") {
                    TextField("my-project", text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section("Template") {
                    ForEach(ProjectTemplate.allCases) { t in
                        Button(action: { template = t }) {
                            HStack {
                                Image(systemName: t.icon)
                                    .foregroundColor(MonoColor.secondaryText)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.displayName)
                                        .font(MonoType.body)
                                        .foregroundColor(MonoColor.primaryText)
                                    Text(t.description)
                                        .font(MonoType.caption)
                                        .foregroundColor(MonoColor.tertiaryText)
                                }
                                Spacer()
                                if template == t {
                                    Image(systemName: MonoIcon.check)
                                        .foregroundColor(MonoColor.active)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(MonoColor.error)
                            .font(MonoType.footnote)
                    }
                }
            }
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Create") {
                    createProject()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || creating)
            }
            .padding()
        }
        .background(MonoColor.canvas)
    }

    private func createProject() {
        creating = true
        error = nil
        Task.detached {
            do {
                let project = try ProjectStore.shared.createProject(name: name, template: template)
                await MainActor.run {
                    created = project
                    WorkspaceState.shared.openProject(project)
                    creating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    creating = false
                }
            }
        }
    }
}

/// Projects list (used on iPhone).
public struct ProjectsListView: View {
    @StateObject private var projectStore = ProjectStore.shared
    @StateObject private var workspace = WorkspaceState.shared
    @State private var showNew = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if projectStore.projects.isEmpty {
                    ContentUnavailableView(
                        "No projects yet",
                        systemImage: MonoIcon.folder,
                        description: Text("Tap + to create your first project.")
                    )
                }
                ForEach(projectStore.projects) { project in
                    Button(action: { workspace.openProject(project) }) {
                        HStack {
                            Image(systemName: project.icon)
                                .foregroundColor(MonoColor.secondaryText)
                                .frame(width: 24)
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
                            Label("Delete", systemImage: MonoIcon.trash)
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showNew = true }) { Image(systemName: MonoIcon.plus) }
                }
            }
            .sheet(isPresented: $showNew) {
                NewProjectView()
            }
        }
    }
}

/// Agents list view (also reachable from the command palette).
public struct AgentsListView: View {
    @State private var query: String = ""

    public init() {}

    public var body: some View {
        List {
            ForEach(AgentCategory.allCases, id: \.self) { category in
                let agents = AgentRegistry.shared.agents(in: category)
                    .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
                if !agents.isEmpty {
                    Section(category.displayName) {
                        ForEach(agents) { agent in
                            NavigationLink(value: agent.agentId) {
                                HStack {
                                    Image(systemName: agent.icon)
                                        .foregroundColor(MonoColor.secondaryText)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(agent.name)
                                            .font(MonoType.body)
                                        Text(agent.role)
                                            .font(MonoType.caption)
                                            .foregroundColor(MonoColor.tertiaryText)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Agents (\(AgentRegistry.shared.count))")
        .searchable(text: $query)
        .navigationDestination(for: String.self) { id in
            if let agent = AgentRegistry.shared.find(id) {
                AgentDetailView(agent: agent)
            }
        }
    }
}

public struct AgentDetailView: View {
    let agent: AgentDefinition
    public init(agent: AgentDefinition) { self.agent = agent }
    public var body: some View {
        Form {
            Section("Role") {
                Text(agent.role)
            }
            Section("Description") {
                Text(agent.description)
            }
            Section("Default Model") {
                Text(agent.defaultModelPreference.rawValue)
            }
            Section("Tool Permissions") {
                ForEach(agent.toolPermissions, id: \.self) { p in
                    Text(p).font(MonoType.codeBody)
                }
            }
            Section("Input Schema") {
                ForEach(agent.inputSchema, id: \.self) { f in
                    Text(f).font(MonoType.codeBody)
                }
            }
            Section("Output Schema") {
                ForEach(agent.outputSchema, id: \.self) { f in
                    Text(f).font(MonoType.codeBody)
                }
            }
            Section("Handoff Rules") {
                ForEach(agent.handoffRules, id: \.self) { r in
                    Text(r)
                }
            }
        }
        .navigationTitle(agent.name)
    }
}
