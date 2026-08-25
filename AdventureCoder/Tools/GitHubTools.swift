import Foundation

// MARK: - GitHub tools

public struct GitHubSearchTool: Tool {
    public let definition = ToolDefinition.find("github_search") ?? ToolDefinition(name: "github_search", category: .github, summary: "Search GitHub", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let query = parameters["query"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'query'.")
        }
        do {
            let repos = try await GitHubService.shared.searchRepositories(query: query)
            let arr: [[String: Any]] = repos.map {
                ["full_name": $0.fullName, "url": $0.htmlURL, "stars": $0.stars, "description": $0.description ?? ""]
            }
            let data = try JSONSerialization.data(withJSONObject: arr, options: [.prettyPrinted])
            return ToolResult(toolName: definition.name, success: true, output: String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct GitHubReposTool: Tool {
    public let definition = ToolDefinition.find("github_repos") ?? ToolDefinition(name: "github_repos", category: .github, summary: "List my repos", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let token = KeychainService.load(.githubToken) else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "GitHub token is not set.")
        }
        do {
            let repos = try await GitHubService.shared.listRepositories(token: token)
            let arr: [[String: Any]] = repos.map {
                ["full_name": $0.fullName, "url": $0.htmlURL, "default_branch": $0.defaultBranch, "private": $0.isPrivate]
            }
            let data = try JSONSerialization.data(withJSONObject: arr, options: [.prettyPrinted])
            return ToolResult(toolName: definition.name, success: true, output: String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct GitHubActionsStatusTool: Tool {
    public let definition = ToolDefinition.find("github_actions_status") ?? ToolDefinition(name: "github_actions_status", category: .github, summary: "List workflow runs", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let repo = parameters["repo"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'repo'.")
        }
        guard let token = KeychainService.load(.githubToken) else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "GitHub token is not set.")
        }
        do {
            let runs = try await GitHubService.shared.listWorkflowRuns(repo: repo, token: token)
            let arr: [[String: Any]] = runs.map {
                ["number": $0.number, "branch": $0.branch, "status": $0.status.rawValue, "conclusion": $0.conclusion?.rawValue ?? NSNull(), "duration": $0.durationText]
            }
            let data = try JSONSerialization.data(withJSONObject: arr, options: [.prettyPrinted])
            return ToolResult(toolName: definition.name, success: true, output: String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}
