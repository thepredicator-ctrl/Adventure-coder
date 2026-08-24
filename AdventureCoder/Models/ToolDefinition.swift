import Foundation

/// Definition of a tool exposed to agents.
public struct ToolDefinition: Identifiable, Codable, Hashable {
    public var id: String { name }
    public var name: String
    public var category: ToolCategory
    public var summary: String
    public var description: String
    public var parameters: [Parameter]
    public var returns: String
    public var requiresConfirmation: Bool
    public var isDestructive: Bool
    public var icon: String

    public init(
        name: String,
        category: ToolCategory,
        summary: String,
        description: String,
        parameters: [Parameter] = [],
        returns: String = "String",
        requiresConfirmation: Bool = false,
        isDestructive: Bool = false,
        icon: String = MonoIcon.bolt
    ) {
        self.name = name
        self.category = category
        self.summary = summary
        self.description = description
        self.parameters = parameters
        self.returns = returns
        self.requiresConfirmation = requiresConfirmation
        self.isDestructive = isDestructive
        self.icon = icon
    }

    public struct Parameter: Codable, Hashable {
        public var name: String
        public var type: String
        public var required: Bool
        public var description: String
        public var defaultValue: String?

        public init(name: String, type: String, required: Bool, description: String, defaultValue: String? = nil) {
            self.name = name
            self.type = type
            self.required = required
            self.description = description
            self.defaultValue = defaultValue
        }
    }
}

public enum ToolCategory: String, Codable, CaseIterable {
    case file
    case search
    case web
    case git
    case github
    case terminal
    case build
    case test
    case preview
    case analysis

    public var displayName: String {
        switch self {
        case .file: return "File"
        case .search: return "Search"
        case .web: return "Web"
        case .git: return "Git"
        case .github: return "GitHub"
        case .terminal: return "Terminal"
        case .build: return "Build"
        case .test: return "Test"
        case .preview: return "Preview"
        case .analysis: return "Analysis"
        }
    }

    public var icon: String {
        switch self {
        case .file: return MonoIcon.doc
        case .search: return MonoIcon.search
        case .web: return MonoIcon.globe
        case .git: return MonoIcon.branch
        case .github: return MonoIcon.github
        case .terminal: return MonoIcon.terminal
        case .build: return MonoIcon.build
        case .test: return MonoIcon.test
        case .preview: return MonoIcon.eye
        case .analysis: return MonoIcon.chart
        }
    }
}

/// Catalog of every tool the application exposes.
public enum ToolCatalog {
    public static let all: [ToolDefinition] = [
        // File operations
        .init(name: "read_file", category: .file,
              summary: "Read the contents of a file",
              description: "Reads text content from a file inside the project sandbox.",
              parameters: [
                .init(name: "path", type: "string", required: true, description: "Relative path from the project root.")
              ],
              returns: "String (file contents)"),
        .init(name: "write_file", category: .file,
              summary: "Create or overwrite a file",
              description: "Writes text content to a file inside the project sandbox. Creates parent directories as needed.",
              parameters: [
                .init(name: "path", type: "string", required: true, description: "Relative path from the project root."),
                .init(name: "content", type: "string", required: true, description: "Full file content to write.")
              ],
              returns: "Confirmation message",
              isDestructive: true),
        .init(name: "edit_file", category: .file,
              summary: "Apply a targeted edit to a file",
              description: "Replaces the first occurrence of `find` with `replace` inside the given file.",
              parameters: [
                .init(name: "path", type: "string", required: true, description: "Relative path from the project root."),
                .init(name: "find", type: "string", required: true, description: "Exact text to locate."),
                .init(name: "replace", type: "string", required: true, description: "Replacement text.")
              ],
              returns: "Diff summary",
              isDestructive: true),
        .init(name: "delete_file", category: .file,
              summary: "Delete a file or empty directory",
              description: "Removes a file or empty directory from the project sandbox.",
              parameters: [
                .init(name: "path", type: "string", required: true, description: "Relative path from the project root.")
              ],
              returns: "Confirmation message",
              isDestructive: true),
        .init(name: "list_files", category: .file,
              summary: "List files in a directory",
              description: "Returns the immediate children of a directory.",
              parameters: [
                .init(name: "path", type: "string", required: false, description: "Relative path. Defaults to project root.", defaultValue: ".")
              ],
              returns: "JSON array of file nodes"),
        .init(name: "search_files", category: .search,
              summary: "Search file contents by pattern",
              description: "Performs a case-insensitive substring search across the project and returns matches with line numbers.",
              parameters: [
                .init(name: "query", type: "string", required: true, description: "Text to search for."),
                .init(name: "extensions", type: "string", required: false, description: "Comma-separated extensions to restrict to.", defaultValue: nil)
              ],
              returns: "JSON array of matches"),
        .init(name: "search_project", category: .search,
              summary: "Project-wide search with regex",
              description: "Performs a regex search across project files and returns up to 100 matches.",
              parameters: [
                .init(name: "pattern", type: "string", required: true, description: "Regex pattern."),
                .init(name: "file_glob", type: "string", required: false, description: "Glob to restrict files.", defaultValue: "**/*")
              ],
              returns: "JSON array of matches"),
        // Web
        .init(name: "web_search", category: .web,
              summary: "Search the web",
              description: "Performs a web search and returns ranked results.",
              parameters: [
                .init(name: "query", type: "string", required: true, description: "Search query."),
                .init(name: "limit", type: "int", required: false, description: "Maximum results to return.", defaultValue: "8")
              ],
              returns: "JSON array of {title, url, snippet}"),
        .init(name: "fetch_url", category: .web,
              summary: "Fetch a URL",
              description: "Retrieves the body of a URL and returns up to 10,000 characters of text content.",
              parameters: [
                .init(name: "url", type: "string", required: true, description: "Absolute URL to fetch.")
              ],
              returns: "String (page text)"),
        .init(name: "search_documentation", category: .web,
              summary: "Search developer documentation",
              description: "Searches Apple Developer, MDN, Swift.org, and other curated documentation sources.",
              parameters: [
                .init(name: "query", type: "string", required: true, description: "Documentation query."),
                .init(name: "source", type: "string", required: false, description: "apple | swift | mdn | github", defaultValue: "apple")
              ],
              returns: "JSON array of doc results"),
        .init(name: "search_images", category: .web,
              summary: "Search for images",
              description: "Searches the web for images and returns thumbnail URLs.",
              parameters: [
                .init(name: "query", type: "string", required: true, description: "Image search query.")
              ],
              returns: "JSON array of {title, url, thumbnail}"),
        // Git
        .init(name: "git_status", category: .git, summary: "Get git status", description: "Returns the working tree status.",
              parameters: []),
        .init(name: "git_diff", category: .git, summary: "Get git diff", description: "Returns the unstaged diff.",
              parameters: [
                .init(name: "staged", type: "bool", required: false, description: "If true, return staged diff.", defaultValue: "false")
              ]),
        .init(name: "git_commit", category: .git, summary: "Create a commit", description: "Stages all changes and commits.",
              parameters: [
                .init(name: "message", type: "string", required: true, description: "Commit message.")
              ],
              requiresConfirmation: true),
        .init(name: "git_push", category: .git, summary: "Push to remote", description: "Pushes current branch to remote.",
              parameters: [], requiresConfirmation: true),
        .init(name: "git_pull", category: .git, summary: "Pull from remote", description: "Pulls current branch from remote.",
              parameters: [], requiresConfirmation: true),
        .init(name: "git_branches", category: .git, summary: "List branches", description: "Lists local and remote branches.",
              parameters: []),
        .init(name: "git_checkout", category: .git, summary: "Checkout a branch", description: "Switches to the named branch.",
              parameters: [
                .init(name: "branch", type: "string", required: true, description: "Branch name.")
              ]),
        .init(name: "git_history", category: .git, summary: "Show commit history", description: "Returns the most recent commits.",
              parameters: [
                .init(name: "limit", type: "int", required: false, description: "Number of commits to return.", defaultValue: "30")
              ]),
        // GitHub
        .init(name: "github_search", category: .github, summary: "Search GitHub repositories",
              description: "Searches GitHub repositories by query.",
              parameters: [
                .init(name: "query", type: "string", required: true, description: "Search query.")
              ]),
        .init(name: "github_repos", category: .github, summary: "List user's repositories",
              description: "Lists repositories accessible to the configured GitHub token.",
              parameters: []),
        .init(name: "github_actions_status", category: .github, summary: "List workflow runs",
              description: "Returns recent workflow runs for a repository.",
              parameters: [
                .init(name: "repo", type: "string", required: true, description: "owner/name")
              ]),
        // Terminal
        .init(name: "run_command", category: .terminal, summary: "Run a sandboxed command",
              description: "Executes a whitelisted command inside the project sandbox. Dangerous commands are denied.",
              parameters: [
                .init(name: "command", type: "string", required: true, description: "Command to execute."),
                .init(name: "timeout", type: "int", required: false, description: "Timeout in seconds.", defaultValue: "15")
              ],
              requiresConfirmation: true),
        // Build / test / preview
        .init(name: "build_project", category: .build, summary: "Build the project",
              description: "Runs the project's build command locally when supported; otherwise triggers a remote GitHub Actions build.",
              parameters: [
                .init(name: "configuration", type: "string", required: false, description: "debug | release", defaultValue: "debug")
              ]),
        .init(name: "run_tests", category: .test, summary: "Run tests",
              description: "Runs the project's test command.",
              parameters: []),
        .init(name: "analyze_logs", category: .analysis, summary: "Analyze build/runtime logs",
              description: "Parses logs and extracts errors, warnings, and contextual hints.",
              parameters: [
                .init(name: "logs", type: "string", required: true, description: "Log text to analyze.")
              ]),
        .init(name: "generate_diff", category: .file, summary: "Generate a diff between two strings",
              description: "Returns a unified diff.",
              parameters: [
                .init(name: "old_text", type: "string", required: true, description: "Original text."),
                .init(name: "new_text", type: "string", required: true, description: "New text."),
                .init(name: "path", type: "string", required: false, description: "File path label.", defaultValue: "file")
              ]),
        .init(name: "preview_project", category: .preview, summary: "Render a preview",
              description: "Builds and renders a live preview of the project when supported.",
              parameters: [
                .init(name: "device", type: "string", required: false, description: "Target device label.", defaultValue: "default")
              ]),
    ]

    public static func find(_ name: String) -> ToolDefinition? {
        all.first { $0.name == name }
    }
}
