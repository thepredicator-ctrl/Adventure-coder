import Foundation

// MARK: - API Reference Documentation
//
// This file contains comprehensive documentation for the Adventure Coder API.
// It serves as both inline documentation and a programmatic reference that
// can be displayed in the Help system.

/// Documentation for a single API element.
public struct APIReferenceEntry: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let type: EntryType
    public let summary: String
    public let parameters: [ParameterDoc]
    public let returnValue: String
    public let example: String
    public let availability: Availability
    public let relatedEntries: [String]

    public enum EntryType: String {
        case `class`, `struct`, `enum`, `protocol`, `func`, `property`, `method`, `initializer`
    }

    public struct ParameterDoc: Hashable {
        public let name: String
        public let type: String
        public let description: String
        public let isRequired: Bool
        public let defaultValue: String?
    }

    public struct Availability: Hashable {
        public let iOS: String
        public let iPadOS: String
        public let macOS: String?
        public let introducedIn: String
    }
}

/// Comprehensive API reference for Adventure Coder.
public enum APIReference {
    // MARK: - Core Types

    public static let project = APIReferenceEntry(
        name: "Project",
        type: .struct,
        summary: "Represents a coding project managed by Adventure Coder.",
        parameters: [
            .init(name: "id", type: "UUID", description: "Unique identifier for the project.", isRequired: true, defaultValue: nil),
            .init(name: "name", type: "String", description: "Human-readable project name.", isRequired: true, defaultValue: nil),
            .init(name: "rootPath", type: "String", description: "Absolute path to the project's root directory in the sandbox.", isRequired: true, defaultValue: nil),
            .init(name: "template", type: "ProjectTemplate", description: "The template used to create the project.", isRequired: true, defaultValue: nil),
            .init(name: "primaryLanguage", type: "String", description: "The primary programming language of the project.", isRequired: true, defaultValue: "Swift"),
            .init(name: "defaultBranch", type: "String", description: "The default git branch name.", isRequired: true, defaultValue: "main"),
            .init(name: "githubRepo", type: "String?", description: "GitHub repository identifier (owner/name) if linked.", isRequired: false, defaultValue: nil),
        ],
        returnValue: "A new Project instance.",
        example: """
        let project = Project(
            name: "MyApp",
            rootPath: "/path/to/project",
            template: .swiftUI
        )
        """,
        availability: .init(iOS: "17.0", iPadOS: "17.0", macOS: nil, introducedIn: "1.0.0"),
        relatedEntries: ["ProjectTemplate", "ProjectStore"]
    )

    public static let conversation = APIReferenceEntry(
        name: "Conversation",
        type: .struct,
        summary: "A chat conversation scoped to a project, containing messages between the user and AI.",
        parameters: [
            .init(name: "id", type: "UUID", description: "Unique identifier.", isRequired: true, defaultValue: nil),
            .init(name: "projectId", type: "UUID", description: "The project this conversation belongs to.", isRequired: true, defaultValue: nil),
            .init(name: "title", type: "String", description: "Display title for the conversation.", isRequired: true, defaultValue: nil),
            .init(name: "messages", type: "[ChatMessage]", description: "Array of messages in the conversation.", isRequired: true, defaultValue: "[]"),
            .init(name: "summary", type: "String?", description: "Optional summary for context compression.", isRequired: false, defaultValue: nil),
        ],
        returnValue: "A new Conversation instance.",
        example: """
        let conversation = Conversation(
            projectId: project.id,
            title: "Build a habit tracker"
        )
        """,
        availability: .init(iOS: "17.0", iPadOS: "17.0", macOS: nil, introducedIn: "1.0.0"),
        relatedEntries: ["ChatMessage", "ProjectStore"]
    )

    public static let agentDefinition = APIReferenceEntry(
        name: "AgentDefinition",
        type: .struct,
        summary: "Defines a specialized AI agent with role, instructions, tools, and context requirements.",
        parameters: [
            .init(name: "agentId", type: "String", description: "Unique identifier (e.g. 'coding.swift').", isRequired: true, defaultValue: nil),
            .init(name: "name", type: "String", description: "Display name.", isRequired: true, defaultValue: nil),
            .init(name: "category", type: "AgentCategory", description: "Category for grouping.", isRequired: true, defaultValue: nil),
            .init(name: "role", type: "String", description: "One-line description of the agent's role.", isRequired: true, defaultValue: nil),
            .init(name: "systemInstructions", type: "String", description: "Full system prompt for the agent.", isRequired: true, defaultValue: nil),
            .init(name: "toolPermissions", type: "[String]", description: "List of tool names the agent can use.", isRequired: true, defaultValue: nil),
            .init(name: "contextRequirements", type: "ContextRequirements", description: "What context the agent needs.", isRequired: true, defaultValue: nil),
            .init(name: "defaultModelPreference", type: "ModelPreference", description: "Preferred model type.", isRequired: true, defaultValue: ".fastFree"),
        ],
        returnValue: "A new AgentDefinition instance.",
        example: """
        let agent = AgentDefinition(
            agentId: "coding.swift",
            name: "Swift Coder",
            category: .coding,
            role: "Writes Swift code",
            systemInstructions: "You are a Swift coder...",
            toolPermissions: ["read_file", "write_file"]
        )
        """,
        availability: .init(iOS: "17.0", iPadOS: "17.0", macOS: nil, introducedIn: "1.0.0"),
        relatedEntries: ["AgentRegistry", "AgentCategory", "ContextRequirements"]
    )

    public static let toolDefinition = APIReferenceEntry(
        name: "ToolDefinition",
        type: .struct,
        summary: "Defines a tool that agents can invoke.",
        parameters: [
            .init(name: "name", type: "String", description: "Unique tool name (e.g. 'read_file').", isRequired: true, defaultValue: nil),
            .init(name: "category", type: "ToolCategory", description: "Tool category for grouping.", isRequired: true, defaultValue: nil),
            .init(name: "summary", type: "String", description: "Short summary.", isRequired: true, defaultValue: nil),
            .init(name: "description", type: "String", description: "Full description.", isRequired: true, defaultValue: nil),
            .init(name: "parameters", type: "[Parameter]", description: "Tool parameters.", isRequired: true, defaultValue: "[]"),
            .init(name: "requiresConfirmation", type: "Bool", description: "Whether user confirmation is required.", isRequired: false, defaultValue: "false"),
            .init(name: "isDestructive", type: "Bool", description: "Whether the tool can destroy data.", isRequired: false, defaultValue: "false"),
        ],
        returnValue: "A new ToolDefinition instance.",
        example: """
        let tool = ToolDefinition(
            name: "read_file",
            category: .file,
            summary: "Read a file",
            description: "Reads text content from a file.",
            parameters: [.init(name: "path", type: "string", required: true, description: "File path")]
        )
        """,
        availability: .init(iOS: "17.0", iPadOS: "17.0", macOS: nil, introducedIn: "1.0.0"),
        relatedEntries: ["ToolRegistry", "ToolCategory", "Tool"]
    )

    // MARK: - Services

    public static let keychainService = APIReferenceEntry(
        name: "KeychainService",
        type: .class,
        summary: "Secure storage for API keys and tokens using the iOS Keychain.",
        parameters: [
            .init(name: "key", type: "Key", description: "The key to store/load/delete.", isRequired: true, defaultValue: nil),
            .init(name: "value", type: "String", description: "The value to store.", isRequired: true, defaultValue: nil),
        ],
        returnValue: "Bool indicating success.",
        example: """
        // Save a key
        KeychainService.save(.openRouterAPIKey, value: "sk-or-v1-...")

        // Load a key
        if let key = KeychainService.load(.openRouterAPIKey) {
            print("Key loaded")
        }

        // Delete a key
        KeychainService.delete(.openRouterAPIKey)

        // Get masked display
        let masked = KeychainService.masked(.openRouterAPIKey)
        // "sk-or-v1-••••••••3f7a"
        """,
        availability: .init(iOS: "17.0", iPadOS: "17.0", macOS: nil, introducedIn: "1.0.0"),
        relatedEntries: ["SettingsStore", "ProviderRegistry"]
    )

    public static let fileSystem = APIReferenceEntry(
        name: "FileSystem",
        type: .class,
        summary: "Wraps FileManager operations on the in-sandbox project directory.",
        parameters: [
            .init(name: "path", type: "String", description: "File path (absolute or relative to project root).", isRequired: true, defaultValue: nil),
            .init(name: "content", type: "String", description: "File content for write operations.", isRequired: false, defaultValue: nil),
        ],
        returnValue: "Varies by operation (String for reads, Bool for writes, [FileNode] for listings).",
        example: """
        // Read a file
        let content = try FileSystem.shared.read("/path/to/file.swift")

        // Write a file
        try FileSystem.shared.write("/path/to/file.swift", content: "let x = 1")

        // List directory
        let nodes = try FileSystem.shared.list(directory: "/path/to/project")

        // Search files
        let hits = try FileSystem.shared.search(query: "TODO", in: "/path/to/project")
        """,
        availability: .init(iOS: "17.0", iPadOS: "17.0", macOS: nil, introducedIn: "1.0.0"),
        relatedEntries: ["FileNode", "FileSystem.SearchHit"]
    )

    public static let gitService = APIReferenceEntry(
        name: "GitService",
        type: .class,
        summary: "File-system-backed mini-git for local Git operations.",
        parameters: [
            .init(name: "project", type: "Project", description: "The project to operate on.", isRequired: true, defaultValue: nil),
            .init(name: "message", type: "String", description: "Commit message (for commit operation).", isRequired: false, defaultValue: nil),
            .init(name: "branch", type: "String", description: "Branch name (for checkout operation).", isRequired: false, defaultValue: nil),
        ],
        returnValue: "Result<T> where T depends on the operation.",
        example: """
        // Initialize a repo
        if case .success = GitService.shared.initialize(project) {}

        // Get status
        if case .success(let status) = GitService.shared.status(project: project) {
            print(status)
        }

        // Commit
        if case .success(let sha) = GitService.shared.commit(project: project, message: "initial commit") {
            print("Committed: \(sha)")
        }

        // History
        if case .success(let history) = GitService.shared.history(project: project, limit: 30) {
            for commit in history { print(commit.message) }
        }
        """,
        availability: .init(iOS: "17.0", iPadOS: "17.0", macOS: nil, introducedIn: "1.0.0"),
        relatedEntries: ["GitCommit", "GitReference"]
    )

    public static let sshService = APIReferenceEntry(
        name: "SSHService",
        type: .class,
        summary: "Real SSH client built on Apple's swift-nio-ssh library for remote PC connectivity.",
        parameters: [
            .init(name: "host", type: "String", description: "Remote PC hostname or IP address.", isRequired: true, defaultValue: nil),
            .init(name: "port", type: "Int", description: "SSH port (default: 22).", isRequired: false, defaultValue: "22"),
            .init(name: "username", type: "String", description: "SSH username.", isRequired: true, defaultValue: nil),
            .init(name: "password", type: "String?", description: "SSH password (stored in Keychain).", isRequired: false, defaultValue: nil),
        ],
        returnValue: "Connection status and command results.",
        example: """
        // Connect
        try await SSHService.shared.connect(
            host: "192.168.1.100",
            port: 22,
            username: "Neth",
            password: "secret"
        )

        // Execute a command
        let result = try await SSHService.shared.execute("dir C:\\Neth\\coder")
        print(result.stdout)

        // Read a remote file
        let content = try await SSHService.shared.readFile("C:\\Neth\\coder\\app\\main.py")

        // Write a remote file
        try await SSHService.shared.writeFile("C:\\Neth\\coder\\app\\main.py", content: "print('hello')")

        // Disconnect
        await SSHService.shared.disconnect()
        """,
        availability: .init(iOS: "17.0", iPadOS: "17.0", macOS: nil, introducedIn: "1.1.0"),
        relatedEntries: ["RemotePCStore", "RemoteFileService", "RemoteTerminalService"]
    )

    public static let agentOrchestrator = APIReferenceEntry(
        name: "AgentOrchestrator",
        type: .class,
        summary: "Central orchestration engine that coordinates the planner, specialized agents, and tools.",
        parameters: [
            .init(name: "userMessage", type: "String", description: "The user's request.", isRequired: true, defaultValue: nil),
            .init(name: "project", type: "Project", description: "The active project.", isRequired: true, defaultValue: nil),
            .init(name: "conversation", type: "Conversation", description: "The conversation to append to.", isRequired: true, defaultValue: nil),
        ],
        returnValue: "Updated Conversation with assistant response.",
        example: """
        // Run a full orchestration
        let updated = await AgentOrchestrator.shared.runRequest(
            "Build a habit tracker",
            project: project,
            conversation: conversation
        )

        // Simple streaming chat
        let updated = await AgentOrchestrator.shared.streamSimpleChat(
            "What does this code do?",
            project: project,
            conversation: conversation
        ) { delta in
            print(delta, terminator: "")
        }
        """,
        availability: .init(iOS: "17.0", iPadOS: "17.0", macOS: nil, introducedIn: "1.0.0"),
        relatedEntries: ["AgentRegistry", "ModelRouter", "ContextManager"]
    )

    // MARK: - All Entries

    public static let allEntries: [APIReferenceEntry] = [
        project, conversation, agentDefinition, toolDefinition,
        keychainService, fileSystem, gitService, sshService, agentOrchestrator
    ]

    /// Search entries by name or summary.
    public static func search(_ query: String) -> [APIReferenceEntry] {
        if query.isEmpty { return allEntries }
        return allEntries.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.summary.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - Tool Reference Documentation

/// Detailed documentation for each tool in the catalog.
public enum ToolReference {
    public struct ToolDoc: Identifiable, Hashable {
        public let id = UUID()
        public let name: String
        public let category: String
        public let summary: String
        public let description: String
        public let parameters: [APIReferenceEntry.ParameterDoc]
        public let example: String
        public let requiresConfirmation: Bool
        public let isDestructive: Bool
    }

    public static let allDocs: [ToolDoc] = [
        ToolDoc(
            name: "read_file",
            category: "File",
            summary: "Read the contents of a file",
            description: "Reads text content from a file inside the project sandbox. Returns the full file content as a UTF-8 string.",
            parameters: [
                .init(name: "path", type: "string", description: "Relative path from the project root.", isRequired: true, defaultValue: nil)
            ],
            example: #"{"path": "Sources/App.swift"}"#,
            requiresConfirmation: false,
            isDestructive: false
        ),
        ToolDoc(
            name: "write_file",
            category: "File",
            summary: "Create or overwrite a file",
            description: "Writes text content to a file inside the project sandbox. Creates parent directories as needed. Detects secrets before writing.",
            parameters: [
                .init(name: "path", type: "string", description: "Relative path from the project root.", isRequired: true, defaultValue: nil),
                .init(name: "content", type: "string", description: "Full file content to write.", isRequired: true, defaultValue: nil)
            ],
            example: #"{"path": "Sources/NewFile.swift", "content": "let x = 1\n"}"#,
            requiresConfirmation: false,
            isDestructive: true
        ),
        ToolDoc(
            name: "edit_file",
            category: "File",
            summary: "Apply a targeted edit to a file",
            description: "Replaces the first occurrence of `find` with `replace` inside the given file. Returns a unified diff of the change.",
            parameters: [
                .init(name: "path", type: "string", description: "Relative path from the project root.", isRequired: true, defaultValue: nil),
                .init(name: "find", type: "string", description: "Exact text to locate.", isRequired: true, defaultValue: nil),
                .init(name: "replace", type: "string", description: "Replacement text.", isRequired: true, defaultValue: nil)
            ],
            example: #"{"path": "App.swift", "find": "old text", "replace": "new text"}"#,
            requiresConfirmation: false,
            isDestructive: true
        ),
        ToolDoc(
            name: "search_files",
            category: "Search",
            summary: "Search file contents by pattern",
            description: "Performs a case-insensitive substring search across the project and returns matches with line numbers and snippets.",
            parameters: [
                .init(name: "query", type: "string", description: "Text to search for.", isRequired: true, defaultValue: nil),
                .init(name: "extensions", type: "string", description: "Comma-separated extensions to restrict to (e.g. 'swift,py').", isRequired: false, defaultValue: nil)
            ],
            example: #"{"query": "TODO", "extensions": "swift"}"#,
            requiresConfirmation: false,
            isDestructive: false
        ),
        ToolDoc(
            name: "web_search",
            category: "Web",
            summary: "Search the web",
            description: "Performs a web search using DuckDuckGo and returns ranked results with titles, URLs, and snippets.",
            parameters: [
                .init(name: "query", type: "string", description: "Search query.", isRequired: true, defaultValue: nil),
                .init(name: "limit", type: "int", description: "Maximum results to return.", isRequired: false, defaultValue: "8")
            ],
            example: #"{"query": "SwiftUI NavigationStack tutorial", "limit": 5}"#,
            requiresConfirmation: false,
            isDestructive: false
        ),
        ToolDoc(
            name: "git_commit",
            category: "Git",
            summary: "Create a git commit",
            description: "Stages all changes and creates a commit with the given message. Checks for secrets in the commit message.",
            parameters: [
                .init(name: "message", type: "string", description: "Commit message.", isRequired: true, defaultValue: nil)
            ],
            example: #"{"message": "Fix navigation bug"}"#,
            requiresConfirmation: true,
            isDestructive: false
        ),
        ToolDoc(
            name: "run_command",
            category: "Terminal",
            summary: "Run a sandboxed command",
            description: "Executes a whitelisted command inside the project sandbox. Commands outside the whitelist are denied.",
            parameters: [
                .init(name: "command", type: "string", description: "Command to execute.", isRequired: true, defaultValue: nil),
                .init(name: "timeout", type: "int", description: "Timeout in seconds.", isRequired: false, defaultValue: "15")
            ],
            example: #"{"command": "ls -la", "timeout": 10}"#,
            requiresConfirmation: true,
            isDestructive: false
        ),
        ToolDoc(
            name: "remote_execute_command",
            category: "Terminal",
            summary: "Execute a command on the remote PC",
            description: "Runs a shell command on the connected remote PC via SSH and returns stdout, stderr, and exit code.",
            parameters: [
                .init(name: "command", type: "string", description: "Command to execute on the remote PC.", isRequired: true, defaultValue: nil)
            ],
            example: #"{"command": "npm install"}"#,
            requiresConfirmation: true,
            isDestructive: false
        ),
        ToolDoc(
            name: "analyze_complexity",
            category: "Analysis",
            summary: "Analyze code complexity",
            description: "Calculates cyclomatic complexity, cognitive complexity, and maintainability index for a Swift file.",
            parameters: [
                .init(name: "path", type: "string", description: "File to analyze.", isRequired: true, defaultValue: nil)
            ],
            example: #"{"path": "Sources/App.swift"}"#,
            requiresConfirmation: false,
            isDestructive: false
        ),
        ToolDoc(
            name: "security_scan",
            category: "Analysis",
            summary: "Security scan",
            description: "Scans a file for security issues including secrets, insecure HTTP URLs, eval() usage, and force unwrapping.",
            parameters: [
                .init(name: "path", type: "string", description: "File to scan.", isRequired: true, defaultValue: nil)
            ],
            example: #"{"path": "Sources/Network.swift"}"#,
            requiresConfirmation: false,
            isDestructive: false
        ),
    ]

    /// Search tool docs by name.
    public static func search(_ query: String) -> [ToolDoc] {
        if query.isEmpty { return allDocs }
        return allDocs.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.summary.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - Agent Reference Documentation

/// Detailed documentation for agent categories.
public enum AgentReference {
    public struct CategoryDoc: Identifiable, Hashable {
        public let id = UUID()
        public let category: AgentCategory
        public let description: String
        public let agentCount: Int
        public let capabilities: [String]
        public let commonWorkflows: [String]
    }

    public static let categoryDocs: [CategoryDoc] = [
        CategoryDoc(
            category: .planning,
            description: "Planning agents break down user requests into structured plans, identify requirements, and sequence tasks for execution.",
            agentCount: 8,
            capabilities: [
                "Project planning with milestones",
                "Requirements analysis (functional and non-functional)",
                "Architecture design",
                "Task decomposition",
                "Dependency planning",
                "Risk analysis",
                "Implementation sequencing",
                "Technical research"
            ],
            commonWorkflows: [
                "User request → Project Planner → Task Decomposer → Specialized agents",
                "Requirements → Architecture Planner → Implementation Planner → Coding agents"
            ]
        ),
        CategoryDoc(
            category: .coding,
            description: "Coding agents write code in 40+ programming languages and frameworks, from Swift to Solidity.",
            agentCount: 0,  // Filled dynamically
            capabilities: [
                "Swift / SwiftUI / SwiftData / Vapor",
                "TypeScript / React / Next.js / Vue / Svelte",
                "Python / Django / FastAPI",
                "Rust / Go / Java / Kotlin / C#",
                "Flutter / React Native / .NET MAUI",
                "HTML / CSS / JavaScript",
                "SQL / GraphQL / gRPC / tRPC",
                "Docker / Terraform / Kubernetes / Helm",
                "Solidity / Solana (Rust) / Web3",
                "Unity / Unreal / Godot / SpriteKit / SceneKit"
            ],
            commonWorkflows: [
                "Spec → Coding agent → Code Reviewer → Build",
                "Bug report → Debugging agent → Coding agent → Fix Verification"
            ]
        ),
        CategoryDoc(
            category: .codeUnderstanding,
            description: "Code understanding agents analyze, review, and improve existing code without changing its behavior.",
            agentCount: 0,
            capabilities: [
                "Code review (blocker, major, minor, nit)",
                "Refactoring (extract, rename, simplify)",
                "Static analysis",
                "Bug detection",
                "Dependency analysis",
                "API analysis",
                "Type error diagnosis",
                "Performance profiling",
                "Security auditing",
                "Architecture review",
                "Complexity analysis",
                "Duplicate detection",
                "Dead code detection",
                "Code smell detection",
                "Technical debt estimation",
                "Maintainability scoring",
                "Test coverage analysis",
                "Mutation testing",
                "Memory leak detection",
                "Concurrency analysis",
                "Thread safety verification",
                "Async/await auditing",
                "Resource leak detection",
                "Code style enforcement",
                "Naming convention checks",
                "Documentation generation",
                "API documentation",
                "Changelog generation",
                "License compliance",
                "Vulnerability scanning",
                "SBOM generation",
                "Dependency auditing",
                "Supply chain security",
                "Code metrics calculation",
                "Quality gate evaluation",
                "SonarQube integration",
                "Linting",
                "Formatting"
            ],
            commonWorkflows: [
                "Code → Code Reviewer → (fix issues) → merge",
                "Code → Complexity Analyzer → Refactoring Agent → verify"
            ]
        ),
        CategoryDoc(
            category: .debugging,
            description: "Debugging agents diagnose and fix build errors, runtime errors, crashes, and test failures.",
            agentCount: 8,
            capabilities: [
                "Build error diagnosis",
                "Runtime error diagnosis",
                "Crash report analysis",
                "Log analysis",
                "Test failure diagnosis",
                "Regression detection",
                "Debugging strategy planning",
                "Fix verification"
            ],
            commonWorkflows: [
                "Build failure → Build Error Agent → Coding Agent → Fix Verification",
                "Crash → Crash Analyzer → Runtime Error Agent → Coding Agent"
            ]
        ),
        CategoryDoc(
            category: .research,
            description: "Research agents search the web, documentation, and code for solutions and references.",
            agentCount: 10,
            capabilities: [
                "Web search",
                "Developer documentation search",
                "GitHub repository search",
                "Package search",
                "Knowledge base research",
                "Web page reading",
                "URL fetching",
                "Image search",
                "File search",
                "Project exploration"
            ],
            commonWorkflows: [
                "Question → Web Search Agent → synthesize answer",
                "Bug → Documentation Search Agent → Coding Agent"
            ]
        ),
        CategoryDoc(
            category: .devTools,
            description: "Development tool agents interact with the terminal, git, GitHub, build system, and package managers.",
            agentCount: 8,
            capabilities: [
                "Terminal command execution",
                "Git operations (status, diff, commit, push, pull)",
                "GitHub API operations",
                "Project building",
                "Test execution",
                "Package management",
                "Environment inspection",
                "File editing"
            ],
            commonWorkflows: [
                "Code changes → Git Agent → commit → push",
                "Build → Build Agent → (fail) → Build Error Agent"
            ]
        ),
        CategoryDoc(
            category: .product,
            description: "Product and UI agents design, review, and optimize the user interface and experience.",
            agentCount: 8,
            capabilities: [
                "UI design with monochrome aesthetic",
                "UX review for clarity and friction",
                "Accessibility auditing (WCAG, VoiceOver)",
                "iPad layout optimization",
                "iPhone layout optimization",
                "Live preview rendering",
                "Visual QA",
                "Copy and UI text"
            ],
            commonWorkflows: [
                "Spec → UI Designer → SwiftUI Coder → iPad Optimization",
                "Build → Preview Agent → Visual QA → (fixes)"
            ]
        ),
        CategoryDoc(
            category: .deployment,
            description: "Deployment agents handle CI/CD, cloud providers, and release management.",
            agentCount: 0,
            capabilities: [
                "CI pipeline design",
                "GitHub Actions workflows",
                "iOS unsigned IPA builds",
                "IPA packaging",
                "Release verification",
                "Deployment troubleshooting",
                "Cloud architecture (AWS, Azure, GCP)",
                "Vercel / Netlify / Railway / Fly.io",
                "Docker / Kubernetes / Terraform",
                "Monitoring / Observability / Alerting",
                "Incident response"
            ],
            commonWorkflows: [
                "Code → CI Agent → GitHub Actions → artifact",
                "Deploy → Deployment Troubleshooter → (fix) → redeploy"
            ]
        ),
    ]

    /// Get documentation for a category.
    public static func doc(for category: AgentCategory) -> CategoryDoc? {
        categoryDocs.first { $0.category == category }
    }
}
