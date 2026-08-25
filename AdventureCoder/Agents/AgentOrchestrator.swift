import Foundation
import SwiftUI

/// Central orchestration engine. Coordinates the planner, specialized agents, and tools.
@MainActor
public final class AgentOrchestrator: ObservableObject {
    public static let shared = AgentOrchestrator()

    @Published public var activities: [AgentActivity] = []
    @Published public var pendingDiffs: [FileDiff] = []
    @Published public var isRunning = false

    private init() {}

    // MARK: - Public entry point

    /// Run a user request end-to-end: plan → execute → review → return summary.
    /// Returns the updated conversation (passed by value because async work can't
    /// safely mutate an `inout` parameter).
    @discardableResult
    public func runRequest(
        _ userMessage: String,
        project: Project,
        conversation: Conversation
    ) async -> Conversation {
        var conversation = conversation
        guard !isRunning else { return conversation }
        isRunning = true
        defer { isRunning = false }

        activities = []
        let userActivity = AgentActivity(
            agentId: "orchestrator",
            agentName: "Orchestrator",
            status: .running,
            summary: "Working on: \(userMessage)",
            startedAt: Date()
        )
        activities.append(userActivity)
        update(activity: userActivity, status: .running, summary: "Analyzing request")

        do {
            // Step 1: route model for orchestration
            let preference = ModelRouter.shared.route(forTaskDescription: userMessage)
            guard let resolution = ModelRouter.shared.resolve(preference: preference) else {
                appendAssistantMessage(to: &conversation, content: "I couldn't find a configured AI model. Add an OpenRouter or Hugging Face API key in Settings to get started.", project: project)
                finish(activity: userActivity, status: .failed, summary: "No model configured")
                return conversation
            }

            // Step 2: planning pass — use the planner agent
            update(activity: userActivity, status: .running, summary: "Planning with \(resolution.model.displayName)")
            let planner = AgentRegistry.shared.find("planning.project_planner")!
            let planContext = await ContextManager(project: project).buildContext(
                agent: planner,
                userMessage: userMessage,
                conversation: conversation.messages
            )
            let planCompletion: ProviderCompletion
            do {
                planCompletion = try await resolution.provider.chat(
                    messages: planContext.messages,
                    model: resolution.model.modelId,
                    temperature: 0.2,
                    maxTokens: 1500
                )
            } catch {
                appendAssistantMessage(to: &conversation, content: "Planning failed: \(error.localizedDescription)", project: project)
                finish(activity: userActivity, status: .failed, summary: "Planning failed")
                return conversation
            }

            // Step 3: pick a coding agent based on project's primary language
            let codingAgent = pickCodingAgent(for: project)
            update(activity: userActivity, status: .running, summary: "Handing off to \(codingAgent.name)")

            let codingActivity = AgentActivity(
                agentId: codingAgent.agentId,
                agentName: codingAgent.name,
                status: .running,
                summary: "Implementing changes",
                startedAt: Date()
            )
            activities.append(codingActivity)

            // Step 4: ask the coding agent to produce file edits
            let codingContext = await ContextManager(project: project).buildContext(
                agent: codingAgent,
                userMessage: userMessage + "\n\nPlan:\n" + planCompletion.content,
                conversation: conversation.messages
            )
            let codingResolution = ModelRouter.shared.resolve(preference: codingAgent.defaultModelPreference) ?? resolution
            let codingCompletion: ProviderCompletion
            do {
                codingCompletion = try await codingResolution.provider.chat(
                    messages: codingContext.messages,
                    model: codingResolution.model.modelId,
                    temperature: 0.2,
                    maxTokens: 2500
                )
            } catch {
                finish(activity: codingActivity, status: .failed, summary: "Coding failed: \(error.localizedDescription)")
                appendAssistantMessage(to: &conversation, content: "Coding agent failed: \(error.localizedDescription)", project: project)
                finish(activity: userActivity, status: .failed, summary: "Coding failed")
                return conversation
            }

            // Step 5: extract file edits from the coding agent's response and apply them
            let edits = EditExtractor.extract(from: codingCompletion.content, project: project)
            var appliedDiffs: [FileDiff] = []

            // Check if we're in remote mode
            let isRemoteMode = await MainActor.run(body: { RemotePCStore.shared.isConnected && WorkspaceState.shared.currentRemoteProject != nil })

            if isRemoteMode {
                // Apply edits to the remote PC
                for edit in edits {
                    let diff = await applyRemoteEdit(edit, agent: codingAgent)
                    if let diff = diff {
                        appliedDiffs.append(diff)
                        pendingDiffs.append(diff)
                    }
                }
            } else {
                // Apply edits locally
                for edit in edits {
                    let diff = applyEdit(edit, project: project, agent: codingAgent)
                    if let diff = diff {
                        appliedDiffs.append(diff)
                        pendingDiffs.append(diff)
                    }
                }
            }
            update(activity: codingActivity, filesAffected: edits.map { $0.path })
            finish(activity: codingActivity, status: .completed, summary: "Applied \(appliedDiffs.count) edit(s)")

            // Step 6: build & verify
            let buildActivity = AgentActivity(agentId: "tools.build", agentName: "Build Agent", status: .running, summary: "Building project", startedAt: Date())
            activities.append(buildActivity)

            let buildOutput: String
            let buildSuccess: Bool
            if isRemoteMode {
                // Build on the remote PC
                finish(activity: buildActivity, status: .running, summary: "Building on remote PC")
                let remoteProject = await MainActor.run(body: { WorkspaceState.shared.currentRemoteProject })
                if let remoteProject = remoteProject {
                    let result = try? await SSHService.shared.execute("cd '\(remoteProject.path.replacingOccurrences(of: "'", with: "'\\''"))' && (npm run build 2>&1 || cargo build 2>&1 || echo 'No build system detected')", timeout: 300)
                    buildOutput = result?.stdout ?? "Build completed"
                    buildSuccess = result?.success ?? true

                    // If build succeeded, try to install deps and start preview
                    if buildSuccess {
                        // Install dependencies first if needed
                        let hasPackageJson = (try? await SSHService.shared.execute("test -f '\(remoteProject.path.replacingOccurrences(of: "'", with: "'\\''"))/package.json' && echo yes"))?.stdout.contains("yes") ?? false
                        if hasPackageJson {
                            _ = try? await SSHService.shared.execute("cd '\(remoteProject.path.replacingOccurrences(of: "'", with: "'\\''"))' && npm install 2>&1", timeout: 120)
                        }
                        // Start preview
                        let template = await MainActor.run(body: { WorkspaceState.shared.currentRemoteProjectTemplate ?? .web })
                        _ = await RemotePreviewService.shared.startPreview(projectPath: remoteProject.path, template: template)
                    }
                } else {
                    buildOutput = "No remote project selected"
                    buildSuccess = false
                }
            } else {
                // Build locally
                let buildOutcome = BuildService.shared.build(project: project, configuration: "debug")
                switch buildOutcome {
                case .success(let output):
                    buildOutput = output
                    buildSuccess = true
                case .failure(let err):
                    buildOutput = err
                    buildSuccess = false
                }
            }

            if buildSuccess {
                finish(activity: buildActivity, status: .completed, summary: "Build OK")
                appendAssistantMessage(to: &conversation, content: composeSummary(plan: planCompletion.content, code: codingCompletion.content, build: buildOutput, diffs: appliedDiffs), project: project, diffs: appliedDiffs)
            } else {
                finish(activity: buildActivity, status: .failed, summary: "Build failed")
                // Step 7: auto-repair if enabled
                if SettingsStore.shared.autoRepairBuilds {
                    let repaired = await attemptAutoRepair(errorLog: buildOutput, project: project)
                    if repaired {
                        appendAssistantMessage(to: &conversation, content: composeSummary(plan: planCompletion.content, code: codingCompletion.content, build: "Build repaired successfully.", diffs: appliedDiffs), project: project, diffs: appliedDiffs)
                    } else {
                        appendAssistantMessage(to: &conversation, content: composeSummary(plan: planCompletion.content, code: codingCompletion.content, build: "Build failed and auto-repair could not fully resolve the issues:\n\n\(buildOutput)", diffs: appliedDiffs), project: project, diffs: appliedDiffs)
                    }
                } else {
                    appendAssistantMessage(to: &conversation, content: composeSummary(plan: planCompletion.content, code: codingCompletion.content, build: "Build failed:\n\n\(buildOutput)", diffs: appliedDiffs), project: project, diffs: appliedDiffs)
                }
            }
            finish(activity: userActivity, status: .completed, summary: "Done")
        }
        return conversation
    }

    /// Stream a simple chat response without orchestration. Used when the user just asks a question.
    /// Returns the updated conversation (the input conversation is not mutated in place because
    /// streaming requires escaping closures that can't capture an `inout` parameter).
    @discardableResult
    public func streamSimpleChat(
        _ userMessage: String,
        project: Project,
        conversation: Conversation,
        onDelta: @escaping (String) -> Void
    ) async -> Conversation {
        var working = conversation
        guard let resolution = ModelRouter.shared.resolve(preference: ModelRouter.shared.route(forTaskDescription: userMessage)) else {
            working.messages.append(ChatMessage(role: .assistant, content: "I couldn't find a configured AI model. Add an OpenRouter or Hugging Face API key in Settings to get started."))
            ProjectStore.shared.update(working)
            return working
        }
        var messages: [ProviderMessage] = []
        messages.append(ProviderMessage(role: "system", content: "You are Adventure Coder, a minimalist AI coding assistant. Answer concisely and helpfully."))
        let cm = ContextManager(project: project)
        let recent = cm.recentConversationPrefix(working.messages, maxTokens: 2000)
        for m in recent {
            messages.append(ProviderMessage(role: m.role.rawValue, content: m.content))
        }
        messages.append(ProviderMessage(role: "user", content: userMessage))

        var assistantMessage = ChatMessage(role: .assistant, content: "", modelId: resolution.model.modelId, providerId: resolution.model.providerId, streaming: true)
        working.messages.append(assistantMessage)
        ProjectStore.shared.update(working)
        let assistantIdx = working.messages.count - 1

        // Capture a mutable box so the escaping onDelta closure can update it.
        let conversationBox = ConversationBox(working)
        do {
            let completion = try await resolution.provider.streamChat(
                messages: messages,
                model: resolution.model.modelId,
                temperature: 0.3,
                maxTokens: 1200,
                onDelta: { delta in
                    assistantMessage.content += delta
                    onDelta(delta)
                    conversationBox.value.messages[assistantIdx] = assistantMessage
                }
            )
            assistantMessage.streaming = false
            assistantMessage.content = completion.content
            conversationBox.value.messages[assistantIdx] = assistantMessage
            ProjectStore.shared.update(conversationBox.value)
            return conversationBox.value
        } catch {
            assistantMessage.streaming = false
            assistantMessage.content = "Error: \(error.localizedDescription)"
            conversationBox.value.messages[assistantIdx] = assistantMessage
            ProjectStore.shared.update(conversationBox.value)
            return conversationBox.value
        }
    }

    // MARK: - Auto repair

    private func attemptAutoRepair(errorLog: String, project: Project) async -> Bool {
        // Apply build-error agent's fixes; doesn't need the conversation reference.
        let agent = AgentRegistry.shared.find("debugging.build_error")!
        let context = await ContextManager(project: project).buildContext(
            agent: agent,
            userMessage: "Build failed. Diagnose and propose fixes.",
            errorLogs: errorLog
        )
        guard let resolution = ModelRouter.shared.resolve(preference: agent.defaultModelPreference) else { return false }
        do {
            let completion = try await resolution.provider.chat(messages: context.messages, model: resolution.model.modelId, temperature: 0.1, maxTokens: 2000)
            // Try to extract edits and apply
            let edits = EditExtractor.extract(from: completion.content, project: project)
            for edit in edits {
                _ = applyEdit(edit, project: project, agent: agent)
            }
            // Re-build
            let outcome = BuildService.shared.build(project: project, configuration: "debug")
            if case .success = outcome { return true }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    private func pickCodingAgent(for project: Project) -> AgentDefinition {
        switch project.primaryLanguage.lowercased() {
        case "swift":
            return AgentRegistry.shared.find("coding.swiftui") ?? AgentRegistry.shared.find("coding.swift")!
        case "typescript":
            return AgentRegistry.shared.find("coding.typescript") ?? AgentRegistry.shared.find("coding.react")!
        case "javascript":
            return AgentRegistry.shared.find("coding.javascript") ?? AgentRegistry.shared.find("coding.html_css")!
        case "python":
            return AgentRegistry.shared.find("coding.python")!
        case "rust":
            return AgentRegistry.shared.find("coding.rust")!
        default:
            return AgentRegistry.shared.find("coding.swift")!
        }
    }

    private func applyEdit(_ edit: EditExtractor.Edit, project: Project, agent: AgentDefinition) -> FileDiff? {
        let fs = FileSystem.shared
        let abs = fs.join(project.rootPath, edit.path)
        let original = (try? fs.read(abs)) ?? ""
        let modified: String
        if edit.kind == .create || original.isEmpty {
            modified = edit.newContent
        } else if let find = edit.findText, let replace = edit.replaceText {
            modified = original.replacingOccurrences(of: find, with: replace)
        } else {
            modified = edit.newContent
        }
        do {
            try fs.write(abs, content: modified)
        } catch {
            return nil
        }
        let hunks = DiffAlgorithm.computeHunks(oldLines: original.components(separatedBy: .newlines), newLines: modified.components(separatedBy: .newlines))
        let diff = FileDiff(
            filePath: edit.path,
            agentId: agent.agentId,
            agentName: agent.name,
            hunks: hunks,
            originalContent: original,
            modifiedContent: modified
        )
        return diff
    }

    /// Apply an edit to a file on the remote PC via SSH.
    private func applyRemoteEdit(_ edit: EditExtractor.Edit, agent: AgentDefinition) async -> FileDiff? {
        let original = (try? await RemoteFileService.shared.readFile(edit.path)) ?? ""
        let modified: String
        if edit.kind == .create || original.isEmpty {
            modified = edit.newContent
        } else if let find = edit.findText, let replace = edit.replaceText {
            modified = original.replacingOccurrences(of: find, with: replace)
        } else {
            modified = edit.newContent
        }
        do {
            try await RemoteFileService.shared.writeFile(edit.path, content: modified)
        } catch {
            return nil
        }
        let hunks = DiffAlgorithm.computeHunks(oldLines: original.components(separatedBy: .newlines), newLines: modified.components(separatedBy: .newlines))
        return FileDiff(
            filePath: edit.path,
            agentId: agent.agentId,
            agentName: agent.name,
            hunks: hunks,
            originalContent: original,
            modifiedContent: modified
        )
    }

    private func appendAssistantMessage(to conversation: inout Conversation, content: String, project: Project, diffs: [FileDiff] = []) {
        let message = ChatMessage(role: .assistant, content: content, diffs: diffs)
        conversation.messages.append(message)
        ProjectStore.shared.update(conversation)
    }

    private func composeSummary(plan: String, code: String, build: String, diffs: [FileDiff]) -> String {
        var lines: [String] = []
        lines.append("Here's what I did:")
        if !diffs.isEmpty {
            lines.append("\n**Changes:**")
            for diff in diffs {
                lines.append("• \(diff.filePath) — \(diff.summary) (by \(diff.agentName))")
            }
        }
        lines.append("\n**Build:**")
        lines.append(build)
        lines.append("\nReview the changes in the Diff pane. You can accept or reject each one.")
        return lines.joined(separator: "\n")
    }

    private func update(activity: AgentActivity, status: AgentActivity.Status? = nil, summary: String? = nil, filesAffected: [String]? = nil) {
        if let idx = activities.firstIndex(where: { $0.id == activity.id }) {
            var copy = activities[idx]
            if let s = status { copy.status = s }
            if let s = summary { copy.summary = s }
            if let f = filesAffected { copy.filesAffected = f }
            activities[idx] = copy
        }
    }

    private func finish(activity: AgentActivity, status: AgentActivity.Status, summary: String) {
        if let idx = activities.firstIndex(where: { $0.id == activity.id }) {
            var copy = activities[idx]
            copy.status = status
            copy.summary = summary
            copy.finishedAt = Date()
            activities[idx] = copy
        }
    }
}

/// Parses an LLM response and extracts file edits.
public enum EditExtractor {
    public struct Edit {
        public enum Kind { case create, modify, replace }
        public let path: String
        public let kind: Kind
        public let newContent: String
        public let findText: String?
        public let replaceText: String?
    }

    public static func extract(from response: String, project: Project) -> [Edit] {
        var edits: [Edit] = []
        // Look for fenced code blocks with file paths in the info string:
        // ```swift path=Sources/Foo.swift
        // or ```swift file=Sources/Foo.swift
        // or // FILE: Sources/Foo.swift
        let pattern = #"```[a-zA-Z0-9]*\s*(?:path|file)=([^\n]+)\n([\s\S]*?)```"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let ns = response as NSString
            regex.enumerateMatches(in: response, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
                guard let match = match, match.numberOfRanges >= 3 else { return }
                let path = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let content = ns.substring(with: match.range(at: 2))
                let kind: Edit.Kind = (FileManager.default.fileExists(atPath: FileSystem.shared.join(project.rootPath, path))) ? .modify : .create
                edits.append(Edit(path: path, kind: kind, newContent: content, findText: nil, replaceText: nil))
            }
        }
        // Also extract inline edit blocks of the form:
        // EDIT path=Foo.swift
        // FIND:
        // ...
        // REPLACE:
        // ...
        let editPattern = #"EDIT\s+(?:path|file)=([^\n]+)\s*\nFIND:\n([\s\S]*?)\nREPLACE:\n([\s\S]*?)(?:\nEND_EDIT|\nEDIT\s|$)"#
        if let regex = try? NSRegularExpression(pattern: editPattern, options: []) {
            let ns = response as NSString
            regex.enumerateMatches(in: response, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
                guard let match = match, match.numberOfRanges >= 4 else { return }
                let path = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let find = ns.substring(with: match.range(at: 2))
                let replace = ns.substring(with: match.range(at: 3))
                edits.append(Edit(path: path, kind: .replace, newContent: replace, findText: find, replaceText: replace))
            }
        }
        return edits
    }
}

/// Mutable reference-type box for `Conversation`, used so escaping closures
/// (such as the streaming `onDelta` callback) can update the conversation
/// without capturing an `inout` parameter.
final class ConversationBox {
    var value: Conversation
    init(_ value: Conversation) { self.value = value }
}
