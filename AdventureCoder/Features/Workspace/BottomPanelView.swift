import SwiftUI
import WebKit

/// Bottom panel with multiple tabs: conversations, preview, terminal, problems, builds, settings, new project.
public struct BottomPanelView: View {
    @StateObject private var workspace = WorkspaceState.shared

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(WorkspaceState.BottomPanelTab.allCases, id: \.self) { tab in
                    Button(action: { workspace.bottomPanel = tab }) {
                        HStack(spacing: MonoSpace.xs) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 10))
                            Text(tab.title)
                                .font(MonoType.caption.weight(workspace.bottomPanel == tab ? .semibold : .regular))
                        }
                        .foregroundColor(workspace.bottomPanel == tab ? MonoColor.primaryText : MonoColor.tertiaryText)
                        .padding(.horizontal, MonoSpace.md)
                        .frame(height: MonoSpace.tabBarHeight)
                        .background(workspace.bottomPanel == tab ? MonoColor.canvas : MonoColor.panel)
                        .overlay(alignment: .bottom) {
                            if workspace.bottomPanel == tab {
                                Rectangle().fill(MonoColor.nearBlack).frame(height: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Rectangle().fill(MonoColor.hairline).frame(width: 1)
                }
                Spacer()
                Button(action: { workspace.terminalCollapsed = true }) {
                    Image(systemName: MonoIcon.close)
                        .foregroundColor(MonoColor.tertiaryText)
                        .padding(.horizontal, MonoSpace.md)
                }
                .buttonStyle(.plain)
            }
            .background(MonoColor.panel)
            HairlineDivider()
            switch workspace.bottomPanel {
            case .conversations: ConversationsPanel()
            case .preview: PreviewPanel()
            case .terminal: TerminalPanel()
            case .problems: ProblemsPanel()
            case .builds: BuildsPanel()
            case .settings: SettingsPanel()
            case .newProject: NewProjectPanel()
            case .remoteTerminal: RemoteTerminalPanel()
            case .remotePreview: RemotePreviewPanel()
            case .remoteDashboard: RemoteDashboardView()
            }
        }
        .background(MonoColor.canvas)
    }
}

struct ConversationsPanel: View {
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var projectStore = ProjectStore.shared
    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: MonoIcon.search).foregroundColor(MonoColor.tertiaryText)
                TextField("Search conversations…", text: $query)
                    .font(MonoType.body)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, MonoSpace.md)
            .padding(.vertical, MonoSpace.sm)
            .background(MonoColor.panel)
            HairlineDivider()
            ScrollView {
                let convs = (workspace.currentProject.flatMap { projectStore.conversations(for: $0.id) } ?? [])
                    .filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(convs) { conv in
                        let isActive = workspace.currentConversation?.id == conv.id
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(conv.title)
                                    .font(MonoType.body.weight(isActive ? .semibold : .regular))
                                    .foregroundColor(MonoColor.primaryText)
                                Text(conv.updatedAt.formatted(.relative(presentation: .named)))
                                    .font(MonoType.caption)
                                    .foregroundColor(MonoColor.tertiaryText)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, MonoSpace.md)
                        .padding(.vertical, MonoSpace.md)
                        .background(isActive ? MonoColor.cloud : Color.clear)
                        .overlay(alignment: .leading) {
                            if isActive {
                                Rectangle().fill(MonoColor.nearBlack).frame(width: 2)
                            }
                        }
                        .onTapGesture {
                            workspace.currentConversation = conv
                        }
                    }
                }
            }
        }
    }
}

struct TerminalPanel: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var history: [TerminalHistoryItem] = []
    @State private var input: String = ""
    @FocusState private var inputFocused: Bool

    struct TerminalHistoryItem: Identifiable {
        let id = UUID()
        let command: String
        let output: String
        let exitCode: Int
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: MonoSpace.xxs) {
                        ForEach(history) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: MonoSpace.xs) {
                                    Text("$")
                                        .font(MonoType.codeSmall)
                                        .foregroundColor(MonoColor.success)
                                    Text(item.command)
                                        .font(MonoType.codeSmall)
                                        .foregroundColor(MonoColor.primaryText)
                                }
                                Text(item.output)
                                    .font(MonoType.codeSmall)
                                    .foregroundColor(item.exitCode == 0 ? MonoColor.secondaryText : MonoColor.error)
                                    .textSelection(.enabled)
                            }
                            .padding(.horizontal, MonoSpace.md)
                            .padding(.vertical, MonoSpace.xxs)
                            .id(item.id)
                        }
                    }
                    .padding(.vertical, MonoSpace.sm)
                }
                .onChange(of: history.count) { _ in
                    if let last = history.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            HStack(spacing: MonoSpace.sm) {
                Text("$")
                    .font(MonoType.codeSmall)
                    .foregroundColor(MonoColor.success)
                TextField("Type a command (ls, cat, grep, find, tree, …)", text: $input, onCommit: run)
                    .font(MonoType.codeBody)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                Button(action: run) {
                    Image(systemName: MonoIcon.arrow)
                        .foregroundColor(MonoColor.tertiaryText)
                }
                .buttonStyle(.plain)
                .disabled(input.isEmpty)
            }
            .padding(.horizontal, MonoSpace.md)
            .padding(.vertical, MonoSpace.sm)
            .background(MonoColor.panel)
        }
        .onAppear {
            if let project = workspace.currentProject {
                history.append(TerminalHistoryItem(command: "pwd", output: project.rootPath, exitCode: 0))
                history.append(TerminalHistoryItem(command: "tree", output: "Tip: use 'tree .' to see the file structure.", exitCode: 0))
            }
        }
    }

    private func run() {
        guard let project = workspace.currentProject, !input.isEmpty else { return }
        let cmd = input
        input = ""
        let result = TerminalEngine.shared.run(command: cmd, in: project.rootPath)
        history.append(TerminalHistoryItem(command: cmd, output: result.output, exitCode: result.exitCode))
    }
}

struct ProblemsPanel: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var diagnostics: [SwiftSyntaxDiagnostic] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MonoSpace.xs) {
                if diagnostics.isEmpty {
                    Text("No problems detected.")
                        .font(MonoType.footnote)
                        .foregroundColor(MonoColor.tertiaryText)
                        .padding(.horizontal, MonoSpace.md)
                        .padding(.vertical, MonoSpace.sm)
                } else {
                    ForEach(diagnostics.indices, id: \.self) { idx in
                        let diag = diagnostics[idx]
                        HStack(alignment: .top, spacing: MonoSpace.sm) {
                            Image(systemName: diag.severity == .error ? MonoIcon.error : MonoIcon.warning)
                                .foregroundColor(diag.severity == .error ? MonoColor.error : MonoColor.warning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workspace.activeFile?.name ?? "")
                                    .font(MonoType.caption.weight(.medium))
                                Text("Line \(diag.line):\(diag.column) — \(diag.message)")
                                    .font(MonoType.caption)
                                    .foregroundColor(MonoColor.secondaryText)
                            }
                        }
                        .padding(.horizontal, MonoSpace.md)
                        .padding(.vertical, MonoSpace.sm)
                    }
                }
            }
        }
        .onAppear(perform: refresh)
        .onChange(of: workspace.activeFile?.relativePath) { _ in refresh() }
    }

    private func refresh() {
        guard let node = workspace.activeFile else { diagnostics = []; return }
        let content = (try? FileSystem.shared.read(node.absolutePath)) ?? ""
        diagnostics = SwiftSyntaxChecker.check(content: content, path: node.name)
    }
}

struct SettingsPanel: View {
    var body: some View {
        SettingsView()
    }
}

struct NewProjectPanel: View {
    var body: some View {
        NewProjectView()
    }
}

struct BuildsPanel: View {
    var body: some View {
        BuildsView()
    }
}

struct PreviewPanel: View {
    var body: some View {
        PreviewView()
    }
}
