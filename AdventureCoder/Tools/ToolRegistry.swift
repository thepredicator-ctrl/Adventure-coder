import Foundation

/// Registry of all available tools.
public final class ToolRegistry {
    public static let shared = ToolRegistry()

    public let tools: [Tool]

    private init() {
        let fs = FileSystem.shared
        tools = [
            ReadFileTool(fs: fs),
            WriteFileTool(fs: fs),
            EditFileTool(fs: fs),
            DeleteFileTool(fs: fs),
            ListFilesTool(fs: fs),
            SearchFilesTool(fs: fs),
            SearchProjectTool(fs: fs),
            WebSearchTool(),
            FetchURLTool(),
            SearchDocumentationTool(),
            SearchImagesTool(),
            GitStatusTool(),
            GitDiffTool(),
            GitCommitTool(),
            GitPushTool(),
            GitPullTool(),
            GitBranchesTool(),
            GitCheckoutTool(),
            GitHistoryTool(),
            GitHubSearchTool(),
            GitHubReposTool(),
            GitHubActionsStatusTool(),
            RunCommandTool(),
            BuildProjectTool(),
            RunTestsTool(),
            AnalyzeLogsTool(),
            GenerateDiffTool(),
            PreviewProjectTool(),
        ]
    }

    public func find(_ name: String) -> Tool? {
        tools.first { $0.definition.name == name }
    }

    public func definitions() -> [ToolDefinition] {
        tools.map { $0.definition }
    }

    public func tools(for agent: AgentDefinition) -> [Tool] {
        tools.filter { tool in
            agent.toolPermissions.contains(tool.definition.name) ||
            agent.toolPermissions.contains("*")
        }
    }
}
