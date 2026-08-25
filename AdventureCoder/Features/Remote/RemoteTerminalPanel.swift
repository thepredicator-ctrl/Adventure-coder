import SwiftUI

/// Remote terminal panel with streaming SSH output.
public struct RemoteTerminalPanel: View {
    @StateObject private var terminal = RemoteTerminalService.shared
    @StateObject private var store = RemotePCStore.shared
    @State private var input: String = ""
    @FocusState private var inputFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if !store.isConnected {
                EmptyState(
                    title: "Not connected",
                    message: "Connect to a remote PC in Settings → Remote PC to use the terminal.",
                    systemImage: MonoIcon.terminal
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: MonoSpace.xxs) {
                            ForEach(terminal.output) { line in
                                Text(line.text)
                                    .font(MonoType.codeSmall)
                                    .foregroundColor(line.isStderr ? MonoColor.error : MonoColor.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, MonoSpace.md)
                                    .padding(.vertical, 1)
                                    .id(line.id)
                            }
                        }
                        .padding(.vertical, MonoSpace.sm)
                    }
                    .onChange(of: terminal.output.count) { _ in
                        if let last = terminal.output.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                HStack(spacing: MonoSpace.sm) {
                    Text(prompt)
                        .font(MonoType.codeSmall)
                        .foregroundColor(MonoColor.success)
                    TextField("Type a command…", text: $input, onCommit: execute)
                        .font(MonoType.codeBody)
                        .textFieldStyle(.plain)
                        .focused($inputFocused)
                    if terminal.isRunning {
                        Button(action: { terminal.stop() }) {
                            Image(systemName: MonoIcon.stop)
                                .foregroundColor(MonoColor.error)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: execute) {
                            Image(systemName: MonoIcon.arrow)
                                .foregroundColor(MonoColor.tertiaryText)
                        }
                        .buttonStyle(.plain)
                        .disabled(input.isEmpty)
                    }
                    Button(action: { terminal.clear() }) {
                        Image(systemName: "trash")
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, MonoSpace.md)
                .padding(.vertical, MonoSpace.sm)
                .background(MonoColor.panel)
            }
        }
        .background(MonoColor.canvas)
    }

    private var prompt: String {
        let machine = store.activeMachine
        let user = machine?.username ?? "user"
        let host = machine?.name ?? "remote"
        let cwd = terminal.workingDirectory.isEmpty ? "~" : (terminal.workingDirectory as NSString).lastPathComponent
        return "\(user)@\(host) \(cwd)>"
    }

    private func execute() {
        guard !input.isEmpty else { return }
        let cmd = input
        input = ""
        Task {
            await terminal.execute(cmd)
        }
    }
}
