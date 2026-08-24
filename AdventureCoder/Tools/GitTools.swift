import Foundation

// MARK: - Git tools (use libgit2-free shell-outs to git binary where available, otherwise file-level emulation)

public struct GitStatusTool: Tool {
    public let definition = ToolDefinition.find("git_status") ?? ToolDefinition(name: "git_status", category: .git, summary: "Git status", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let result = GitService.shared.status(project: context.project)
        switch result {
        case .success(let status):
            return ToolResult(toolName: definition.name, success: true, output: status)
        case .notARepo:
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Not a git repository. Initialize one first.")
        case .failure(let err):
            return ToolResult(toolName: definition.name, success: false, output: "", error: err)
        }
    }
}

public struct GitDiffTool: Tool {
    public let definition = ToolDefinition.find("git_diff") ?? ToolDefinition(name: "git_diff", category: .git, summary: "Git diff", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let staged = (parameters["staged"] as? Bool) ?? false
        let result = GitService.shared.diff(project: context.project, staged: staged)
        switch result {
        case .success(let diff):
            return ToolResult(toolName: definition.name, success: true, output: diff)
        case .notARepo:
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Not a git repository.")
        case .failure(let err):
            return ToolResult(toolName: definition.name, success: false, output: "", error: err)
        }
    }
}

public struct GitCommitTool: Tool {
    public let definition = ToolDefinition.find("git_commit") ?? ToolDefinition(name: "git_commit", category: .git, summary: "Git commit", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let message = parameters["message"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'message'.")
        }
        if SecretDetector.containsSecrets(message) {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Commit message appears to contain secrets. Refusing to commit.")
        }
        let ok = await context.requestConfirmation("Commit all changes with message: \(message)?")
        guard ok else { return ToolResult(toolName: definition.name, success: false, output: "", error: "Cancelled.") }
        let result = GitService.shared.commit(project: context.project, message: message)
        switch result {
        case .success(let sha):
            return ToolResult(toolName: definition.name, success: true, output: "Committed as \(sha).")
        case .notARepo:
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Not a git repository.")
        case .failure(let err):
            return ToolResult(toolName: definition.name, success: false, output: "", error: err)
        }
    }
}

public struct GitPushTool: Tool {
    public let definition = ToolDefinition.find("git_push") ?? ToolDefinition(name: "git_push", category: .git, summary: "Git push", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let ok = await context.requestConfirmation("Push current branch to remote?")
        guard ok else { return ToolResult(toolName: definition.name, success: false, output: "", error: "Cancelled.") }
        let result = GitService.shared.push(project: context.project)
        switch result {
        case .success(let summary):
            return ToolResult(toolName: definition.name, success: true, output: summary)
        case .notARepo:
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Not a git repository.")
        case .failure(let err):
            return ToolResult(toolName: definition.name, success: false, output: "", error: err)
        }
    }
}

public struct GitPullTool: Tool {
    public let definition = ToolDefinition.find("git_pull") ?? ToolDefinition(name: "git_pull", category: .git, summary: "Git pull", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let ok = await context.requestConfirmation("Pull current branch from remote?")
        guard ok else { return ToolResult(toolName: definition.name, success: false, output: "", error: "Cancelled.") }
        let result = GitService.shared.pull(project: context.project)
        switch result {
        case .success(let summary):
            return ToolResult(toolName: definition.name, success: true, output: summary)
        case .notARepo:
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Not a git repository.")
        case .failure(let err):
            return ToolResult(toolName: definition.name, success: false, output: "", error: err)
        }
    }
}

public struct GitBranchesTool: Tool {
    public let definition = ToolDefinition.find("git_branches") ?? ToolDefinition(name: "git_branches", category: .git, summary: "List branches", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let result = GitService.shared.branches(project: context.project)
        switch result {
        case .success(let branches):
            let lines = branches.map { ref -> String in
                let marker = ref.isCurrent ? "* " : "  "
                let kind = ref.isBranch ? "branch" : "tag"
                return "\(marker)\(kind)\t\(ref.name)\t\(ref.sha.prefix(7))"
            }
            return ToolResult(toolName: definition.name, success: true, output: lines.joined(separator: "\n"))
        case .notARepo:
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Not a git repository.")
        case .failure(let err):
            return ToolResult(toolName: definition.name, success: false, output: "", error: err)
        }
    }
}

public struct GitCheckoutTool: Tool {
    public let definition = ToolDefinition.find("git_checkout") ?? ToolDefinition(name: "git_checkout", category: .git, summary: "Checkout branch", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let branch = parameters["branch"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'branch'.")
        }
        let result = GitService.shared.checkout(project: context.project, branch: branch)
        switch result {
        case .success:
            return ToolResult(toolName: definition.name, success: true, output: "Checked out \(branch).")
        case .notARepo:
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Not a git repository.")
        case .failure(let err):
            return ToolResult(toolName: definition.name, success: false, output: "", error: err)
        }
    }
}

public struct GitHistoryTool: Tool {
    public let definition = ToolDefinition.find("git_history") ?? ToolDefinition(name: "git_history", category: .git, summary: "Show history", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let limit = (parameters["limit"] as? Int) ?? 30
        let result = GitService.shared.history(project: context.project, limit: limit)
        switch result {
        case .success(let commits):
            let lines = commits.map { "\($0.shortSha)\t\($0.author)\t\($0.date)\t\($0.message)" }
            return ToolResult(toolName: definition.name, success: true, output: lines.joined(separator: "\n"))
        case .notARepo:
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Not a git repository.")
        case .failure(let err):
            return ToolResult(toolName: definition.name, success: false, output: "", error: err)
        }
    }
}
