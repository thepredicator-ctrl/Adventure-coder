import Foundation

/// Selects and compresses context for a specific agent invocation.
public struct ContextManager {
    public let project: Project
    public let fs: FileSystem

    public init(project: Project, fs: FileSystem = .shared) {
        self.project = project
        self.fs = fs
    }

    public struct SelectedContext {
        public var messages: [ProviderMessage]
        public var attachedFiles: [(path: String, content: String)]
        public var gitDiff: String?
        public var errorLogs: String?
        public var projectStructure: String?
        public var tokenEstimate: Int
    }

    /// Build the provider message list for an agent invocation.
    public func buildContext(
        agent: AgentDefinition,
        userMessage: String,
        relevantPaths: [String] = [],
        errorLogs: String? = nil,
        gitDiff: String? = nil,
        conversation: [ChatMessage] = []
    ) async -> SelectedContext {
        var attached: [(String, String)] = []
        var tokens = 0

        if agent.contextRequirements.includeProjectStructure {
            let structure = projectStructureSummary()
            attached.append(("PROJECT_STRUCTURE", structure))
            tokens += estimateTokens(structure)
        }

        // Always attach the explicitly relevant files first
        for path in relevantPaths.prefix(agent.contextRequirements.maxFiles) {
            let abs = fs.join(project.rootPath, path)
            if let content = try? fs.read(abs) {
                let truncated = truncate(content, maxTokens: 2000)
                attached.append((path, truncated))
                tokens += estimateTokens(truncated)
            }
        }

        // If we still have budget and the agent wants snippets, do a content search
        if attached.count < agent.contextRequirements.maxFiles {
            let query = extractKeywords(from: userMessage)
            if !query.isEmpty {
                if let hits = try? fs.search(query: query, in: project.rootPath, maxResults: 5) {
                    for hit in hits {
                        if attached.count >= agent.contextRequirements.maxFiles { break }
                        if attached.contains(where: { $0.0 == hit.relativePath }) { continue }
                        if let content = try? fs.read(hit.path) {
                            let snippet = snippetAround(line: hit.line, in: content, radius: 12)
                            let entry = "\(hit.relativePath) (around line \(hit.line)):\n\(snippet)"
                            attached.append((hit.relativePath, entry))
                            tokens += estimateTokens(entry)
                        }
                    }
                }
            }
        }

        if agent.contextRequirements.includeGitDiff, let diff = gitDiff {
            attached.append(("GIT_DIFF", diff))
            tokens += estimateTokens(diff)
        }

        if agent.contextRequirements.includeErrorLogs, let logs = errorLogs {
            let truncated = truncate(logs, maxTokens: 2000)
            attached.append(("ERROR_LOGS", truncated))
            tokens += estimateTokens(truncated)
        }

        // Build messages
        var messages: [ProviderMessage] = []
        messages.append(ProviderMessage(role: "system", content: agent.systemInstructions))
        if !attached.isEmpty {
            let combined = attached.map { "--- \($0.0) ---\n\($0.1)" }.joined(separator: "\n\n")
            messages.append(ProviderMessage(role: "system", content: "Project context (relevant excerpts only):\n\n\(combined)"))
        }

        // Compress conversation history
        let recent = recentConversationPrefix(conversation, maxTokens: 1500)
        for m in recent {
            messages.append(ProviderMessage(role: m.role.rawValue, content: m.content))
        }

        messages.append(ProviderMessage(role: "user", content: userMessage))

        return SelectedContext(
            messages: messages,
            attachedFiles: attached,
            gitDiff: gitDiff,
            errorLogs: errorLogs,
            projectStructure: agent.contextRequirements.includeProjectStructure ? projectStructureSummary() : nil,
            tokenEstimate: tokens
        )
    }

    // MARK: - Helpers

    public func projectStructureSummary() -> String {
        guard let tree = try? fs.tree(at: project.rootPath, maxDepth: 3) else { return "" }
        var lines: [String] = []
        func render(_ nodes: [FileNode], depth: Int) {
            for node in nodes {
                lines.append(String(repeating: "  ", count: depth) + (node.isDirectory ? "📁 " : "📄 ") + node.name)
                if node.isDirectory && depth < 3 {
                    render(node.children, depth: depth + 1)
                }
            }
        }
        render(tree, depth: 0)
        return lines.joined(separator: "\n")
    }

    public func estimateTokens(_ text: String) -> Int {
        // Approximation: 4 chars per token
        max(1, text.count / 4)
    }

    public func truncate(_ text: String, maxTokens: Int) -> String {
        let maxChars = maxTokens * 4
        if text.count <= maxChars { return text }
        return String(text.prefix(maxChars)) + "\n… [truncated]"
    }

    public func snippetAround(line: Int, in content: String, radius: Int) -> String {
        let lines = content.components(separatedBy: .newlines)
        let start = max(0, line - 1 - radius)
        let end = min(lines.count - 1, line - 1 + radius)
        guard start <= end, start < lines.count else { return "" }
        let slice = lines[start...end]
        return slice.enumerated().map { idx, l in "\(start + idx + 1): \(l)" }.joined(separator: "\n")
    }

    public func extractKeywords(from text: String) -> String {
        let stopwords: Set<String> = ["the", "a", "an", "and", "or", "but", "if", "then", "else", "for", "of", "to", "in", "on", "at", "with", "by", "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did", "will", "would", "should", "could", "may", "might", "can", "this", "that", "these", "those", "i", "you", "he", "she", "it", "we", "they", "my", "your", "his", "her", "its", "our", "their", "as", "from", "about", "into", "out", "up", "down", "no", "not", "so", "too", "very", "just", "only", "than"]
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }
        let filtered = words.map { String($0) }.filter { $0.count > 2 && !stopwords.contains($0) }
        return filtered.first ?? ""
    }

    public func recentConversationPrefix(_ messages: [ChatMessage], maxTokens: Int) -> [ChatMessage] {
        var picked: [ChatMessage] = []
        var tokens = 0
        for msg in messages.reversed() {
            let t = estimateTokens(msg.content)
            if tokens + t > maxTokens { break }
            picked.insert(msg, at: 0)
            tokens += t
        }
        return picked
    }
}
