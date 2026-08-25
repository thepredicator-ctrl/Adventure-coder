import SwiftUI

/// Terminal view — top-level wrapper (used as a tab on iPhone). The bottom-panel
/// version lives in TerminalPanel.
public struct TerminalView: View {
    public init() {}
    public var body: some View {
        TerminalPanelContent()
    }
}

/// Reusable terminal content used by both the bottom panel and the iPhone tab.
public struct TerminalPanelContent: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var history: [TerminalHistoryItem] = []
    @State private var input: String = ""
    @FocusState private var inputFocused: Bool

    public struct TerminalHistoryItem: Identifiable {
        public let id = UUID()
        public let command: String
        public let output: String
        public let exitCode: Int
    }

    public init() {}

    public var body: some View {
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
        .background(MonoColor.canvas)
        .onAppear {
            if let project = workspace.currentProject {
                history.append(TerminalHistoryItem(command: "pwd", output: project.rootPath, exitCode: 0))
                history.append(TerminalHistoryItem(command: "env", output: "Available commands: \(TerminalEngine.shared.allowedCommands.joined(separator: ", "))", exitCode: 0))
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
