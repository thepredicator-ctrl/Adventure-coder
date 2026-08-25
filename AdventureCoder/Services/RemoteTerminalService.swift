import Foundation
import Combine

/// Streaming terminal service for the remote PC.
@MainActor
public final class RemoteTerminalService: ObservableObject {
    public static let shared = RemoteTerminalService()

    @Published public var output: [TerminalLine] = []
    @Published public var isRunning: Bool = false
    @Published public var workingDirectory: String = ""

    public struct TerminalLine: Identifiable {
        public let id = UUID()
        public let text: String
        public let isStderr: Bool
        public let timestamp: Date
    }

    private var currentTask: Task<Void, Never>?
    private let ssh = SSHService.shared

    private init() {}

    public func setWorkingDirectory(_ path: String) {
        self.workingDirectory = path
    }

    /// Execute a command in the remote terminal with streaming output.
    public func execute(_ command: String) async {
        guard !command.isEmpty else { return }

        let prompt = makePrompt()
        output.append(TerminalLine(text: "\(prompt) \(command)", isStderr: false, timestamp: Date()))
        isRunning = true

        let cdCommand = workingDirectory.isEmpty ? "" : "cd '\(workingDirectory.replacingOccurrences(of: "'", with: "'\\''"))' && "
        let fullCommand = cdCommand + command

        currentTask = Task {
            do {
                let exitCode = try await ssh.executeStreaming(
                    fullCommand,
                    onStdout: { [weak self] chunk in
                        Task { @MainActor in
                            self?.output.append(TerminalLine(text: chunk, isStderr: false, timestamp: Date()))
                        }
                    },
                    onStderr: { [weak self] chunk in
                        Task { @MainActor in
                            self?.output.append(TerminalLine(text: chunk, isStderr: true, timestamp: Date()))
                        }
                    }
                )
                self.output.append(TerminalLine(text: "[Exit code: \(exitCode)]", isStderr: exitCode != 0, timestamp: Date()))
            } catch {
                self.output.append(TerminalLine(text: "Error: \(error.localizedDescription)", isStderr: true, timestamp: Date()))
            }
            await MainActor.run {
                self.isRunning = false
            }
        }
    }

    /// Stop the currently running command.
    public func stop() {
        currentTask?.cancel()
        currentTask = nil
        isRunning = false
        output.append(TerminalLine(text: "[Process stopped]", isStderr: true, timestamp: Date()))
    }

    /// Clear the terminal output.
    public func clear() {
        output = []
    }

    private func makePrompt() -> String {
        let machine = RemotePCStore.shared.activeMachine
        let user = machine?.username ?? "user"
        let host = machine?.name ?? "remote"
        let cwd = workingDirectory.isEmpty ? "~" : (workingDirectory as NSString).lastPathComponent
        return "\(user)@\(host) \(cwd)>"
    }
}
