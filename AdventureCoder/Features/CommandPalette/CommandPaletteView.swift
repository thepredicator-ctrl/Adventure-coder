import SwiftUI

/// Command palette (⌘K). Lets the user search and trigger commands.
public struct CommandPaletteView: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var query: String = ""
    @FocusState private var focused: Bool

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { workspace.showCommandPalette = false }
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: MonoIcon.command)
                        .foregroundColor(MonoColor.tertiaryText)
                    TextField("Type a command…", text: $query)
                        .font(MonoType.body)
                        .textFieldStyle(.plain)
                        .focused($focused)
                }
                .padding(.horizontal, MonoSpace.md)
                .padding(.vertical, MonoSpace.md)
                .background(MonoColor.elevated)
                .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadiusLg))
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredCommands, id: \.id) { cmd in
                            Button(action: {
                                cmd.action()
                                workspace.showCommandPalette = false
                            }) {
                                HStack {
                                    Image(systemName: cmd.icon)
                                        .foregroundColor(MonoColor.secondaryText)
                                        .frame(width: 20)
                                    Text(cmd.title)
                                        .font(MonoType.body)
                                        .foregroundColor(MonoColor.primaryText)
                                    Spacer()
                                    if let shortcut = cmd.shortcut {
                                        Text(shortcut)
                                            .font(MonoType.caption2)
                                            .foregroundColor(MonoColor.tertiaryText)
                                    }
                                }
                                .padding(.horizontal, MonoSpace.md)
                                .padding(.vertical, MonoSpace.sm)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: 560)
            .frame(maxHeight: 420)
            .background(MonoColor.elevated)
            .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadiusLg))
            .overlay(
                RoundedRectangle(cornerRadius: MonoSpace.cornerRadiusLg)
                    .stroke(MonoColor.hairline, lineWidth: 1)
            )
            .padding()
        }
        .onAppear { focused = true }
    }

    struct Command {
        let id: String
        let title: String
        let icon: String
        let shortcut: String?
        let action: () -> Void
    }

    private var commands: [Command] {
        [
            Command(id: "new_project", title: "New Project", icon: MonoIcon.docPlus, shortcut: "⌘N") {
                workspace.bottomPanel = .newProject
            },
            Command(id: "open_file", title: "Open File", icon: MonoIcon.doc, shortcut: "⌘O") {},
            Command(id: "ask_ai", title: "Ask AI", icon: MonoIcon.sparkles, shortcut: "⌘J") {
                workspace.chatCollapsed = false
            },
            Command(id: "run_build", title: "Run Build", icon: MonoIcon.build, shortcut: "⌘B") {
                workspace.bottomPanel = .builds
            },
            Command(id: "run_tests", title: "Run Tests", icon: MonoIcon.test, shortcut: "⌘U") {},
            Command(id: "open_terminal", title: "Open Terminal", icon: MonoIcon.terminal, shortcut: "⌘T") {
                workspace.bottomPanel = .terminal
                workspace.terminalCollapsed = false
            },
            Command(id: "git_status", title: "Git Status", icon: MonoIcon.branch, shortcut: "⌃G") {
                workspace.bottomPanel = .terminal
            },
            Command(id: "git_commit", title: "Git Commit", icon: MonoIcon.commit, shortcut: "⌃⇧C") {},
            Command(id: "git_push", title: "Git Push", icon: MonoIcon.push, shortcut: "⌃⇧P") {},
            Command(id: "search_documentation", title: "Search Documentation", icon: MonoIcon.docText, shortcut: "⌃D") {},
            Command(id: "open_preview", title: "Open Preview", icon: MonoIcon.eye, shortcut: "⌃P") {
                workspace.bottomPanel = .preview
            },
            Command(id: "switch_model", title: "Switch Model", icon: MonoIcon.model, shortcut: "⌃M") {},
            Command(id: "switch_agent", title: "Switch Agent", icon: MonoIcon.agent, shortcut: "⌃A") {},
            Command(id: "search_files", title: "Search Files", icon: MonoIcon.search, shortcut: "⌃F") {
                workspace.showGlobalSearch = true
            },
            Command(id: "command_palette", title: "Command Palette", icon: MonoIcon.command, shortcut: "⌘K") {},
            Command(id: "settings", title: "Settings", icon: MonoIcon.settings, shortcut: "⌘,") {
                workspace.bottomPanel = .settings
            },
        ]
    }

    private var filteredCommands: [Command] {
        if query.isEmpty { return commands }
        return commands.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}

/// Global search across files, conversations, agents, commands, etc.
public struct GlobalSearchView: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var query: String = ""
    @FocusState private var focused: Bool

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { workspace.showGlobalSearch = false }
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: MonoIcon.search)
                        .foregroundColor(MonoColor.tertiaryText)
                    TextField("Search files, conversations, agents, commands…", text: $query)
                        .font(MonoType.body)
                        .textFieldStyle(.plain)
                        .focused($focused)
                }
                .padding(.horizontal, MonoSpace.md)
                .padding(.vertical, MonoSpace.md)
                .background(MonoColor.elevated)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonoSpace.sm) {
                        if let project = workspace.currentProject, !query.isEmpty {
                            let hits = (try? FileSystem.shared.search(query: query, in: project.rootPath, maxResults: 30)) ?? []
                            if !hits.isEmpty {
                                SectionHeader("Files")
                                ForEach(hits, id: \.self) { hit in
                                    HStack {
                                        Image(systemName: MonoIcon.doc).foregroundColor(MonoColor.tertiaryText)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(hit.relativePath).font(MonoType.body)
                                            Text("Line \(hit.line): \(hit.snippet)")
                                                .font(MonoType.caption)
                                                .foregroundColor(MonoColor.tertiaryText)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.horizontal, MonoSpace.md)
                                    .padding(.vertical, MonoSpace.xs)
                                }
                            }
                            let convs = ProjectStore.shared.conversations(for: project.id)
                                .filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.messages.contains { $0.content.localizedCaseInsensitiveContains(query) } }
                            if !convs.isEmpty {
                                SectionHeader("Conversations")
                                ForEach(convs) { c in
                                    HStack {
                                        Image(systemName: MonoIcon.bell).foregroundColor(MonoColor.tertiaryText)
                                        Text(c.title).font(MonoType.body)
                                    }
                                    .padding(.horizontal, MonoSpace.md)
                                    .padding(.vertical, MonoSpace.xs)
                                    .onTapGesture { workspace.currentConversation = c }
                                }
                            }
                        }
                        let agents = AgentRegistry.shared.all.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.role.localizedCaseInsensitiveContains(query) }
                        if !agents.isEmpty {
                            SectionHeader("Agents")
                            ForEach(agents) { a in
                                HStack {
                                    Image(systemName: a.icon).foregroundColor(MonoColor.tertiaryText)
                                    Text(a.name).font(MonoType.body)
                                    Spacer()
                                    Text(a.category.displayName)
                                        .font(MonoType.caption)
                                        .foregroundColor(MonoColor.tertiaryText)
                                }
                                .padding(.horizontal, MonoSpace.md)
                                .padding(.vertical, MonoSpace.xs)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 640)
            .frame(maxHeight: 520)
            .background(MonoColor.elevated)
            .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadiusLg))
            .overlay(
                RoundedRectangle(cornerRadius: MonoSpace.cornerRadiusLg)
                    .stroke(MonoColor.hairline, lineWidth: 1)
            )
            .padding()
        }
        .onAppear { focused = true }
    }
}
