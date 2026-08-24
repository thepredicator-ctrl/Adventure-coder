import Foundation

/// Development tools agents (49–56).
public enum DevToolAgents {
    public static let all: [AgentDefinition] = [
        terminalAgent, gitAgent, githubAgent, buildAgent, testAgent,
        packageManagerAgent, environmentAgent, fileEditingAgent
    ]

    static let terminalAgent = AgentDefinition(
        agentId: "tools.terminal",
        name: "Terminal Agent",
        category: .devTools,
        role: "Runs sandboxed terminal commands.",
        systemInstructions: """
        You are the Terminal Agent. Use run_command to execute whitelisted commands (ls, cat, grep, find, tree, head, tail, wc, echo, date, env, pwd, whoami).
        Return JSON: { "command":"", "exit_code":0, "output":"" }
        Never attempt to escape the sandbox.
        """,
        toolPermissions: ["run_command","read_file","list_files"],
        inputSchema: ["command"],
        outputSchema: ["command","exit_code","output"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 3000),
        handoffRules: ["Return output to originating agent."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.terminal,
        description: "Runs sandboxed terminal commands."
    )

    static let gitAgent = AgentDefinition(
        agentId: "tools.git",
        name: "Git Agent",
        category: .devTools,
        role: "Performs local Git operations.",
        systemInstructions: """
        You are the Git Agent. Use git_status, git_diff, git_commit, git_branches, git_checkout, git_history, git_push, git_pull.
        Return JSON: { "action":"", "result":"", "success":true }
        """,
        toolPermissions: ["git_status","git_diff","git_commit","git_branches","git_checkout","git_history","git_push","git_pull"],
        inputSchema: ["action"],
        outputSchema: ["action","result","success"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 3000, includeGitDiff: true),
        handoffRules: ["Notify orchestrator of push/pull results."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.branch,
        description: "Performs Git operations."
    )

    static let githubAgent = AgentDefinition(
        agentId: "tools.github",
        name: "GitHub Agent",
        category: .devTools,
        role: "Performs GitHub API operations.",
        systemInstructions: """
        You are the GitHub Agent. Use github_search, github_repos, github_actions_status.
        Return JSON: { "action":"", "result":"", "success":true }
        """,
        toolPermissions: ["github_search","github_repos","github_actions_status"],
        inputSchema: ["action"],
        outputSchema: ["action","result","success"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 3000),
        handoffRules: ["Hand off to CI Agent for build triggers."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.github,
        description: "Performs GitHub API operations."
    )

    static let buildAgent = AgentDefinition(
        agentId: "tools.build",
        name: "Build Agent",
        category: .devTools,
        role: "Builds the project locally (where supported) and triggers remote builds.",
        systemInstructions: """
        You are the Build Agent. Use build_project to build locally. If the local build is not supported,
        summarize why and recommend triggering a GitHub Actions build.
        Return JSON: { "success":true, "output":"", "artifacts":[] }
        """,
        toolPermissions: ["build_project","run_tests","analyze_logs"],
        inputSchema: ["configuration"],
        outputSchema: ["success","output","artifacts[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000, includeErrorLogs: true),
        handoffRules: ["On failure, hand off to Build Error Agent."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.build,
        description: "Builds the project."
    )

    static let testAgent = AgentDefinition(
        agentId: "tools.test",
        name: "Test Agent",
        category: .devTools,
        role: "Runs tests and reports results.",
        systemInstructions: """
        You are the Test Agent. Use run_tests and analyze_logs.
        Return JSON: { "passed":0, "failed":0, "skipped":0, "failures":[{"test":"","reason":""}] }
        """,
        toolPermissions: ["run_tests","analyze_logs"],
        inputSchema: [],
        outputSchema: ["passed","failed","skipped","failures[]"],
        contextRequirements: ContextRequirements(maxFiles: 1, maxTokens: 4000, includeErrorLogs: true),
        handoffRules: ["On failure, hand off to Test Failure Agent."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.test,
        description: "Runs tests and reports results."
    )

    static let packageManagerAgent = AgentDefinition(
        agentId: "tools.package_manager",
        name: "Package Manager Agent",
        category: .devTools,
        role: "Adds, removes, and updates dependencies in project manifests.",
        systemInstructions: """
        You are the Package Manager Agent. Edit Package.swift / package.json / requirements.txt / Cargo.toml.
        Return JSON: { "manifest":"", "changes":"", "added":[], "removed":[] }
        """,
        toolPermissions: ["read_file","write_file","edit_file","list_files"],
        inputSchema: ["package", "version", "action"],
        outputSchema: ["manifest","changes","added[]","removed[]"],
        contextRequirements: ContextRequirements(maxFiles: 1, maxTokens: 3000),
        handoffRules: ["Hand off to Build Agent to verify resolution."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.stack,
        description: "Manages dependencies."
    )

    static let environmentAgent = AgentDefinition(
        agentId: "tools.environment",
        name: "Environment Agent",
        category: .devTools,
        role: "Inspects the build/runtime environment.",
        systemInstructions: """
        You are the Environment Agent. Use run_command with 'env', 'pwd', 'whoami' to inspect the environment.
        Return JSON: { "os":"", "shell":"", "paths":[], "tools":[] }
        """,
        toolPermissions: ["run_command"],
        inputSchema: [],
        outputSchema: ["os","shell","paths[]","tools[]"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 2000),
        handoffRules: ["Return summary to originating agent."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.desktop,
        description: "Inspects the environment."
    )

    static let fileEditingAgent = AgentDefinition(
        agentId: "tools.file_editing",
        name: "File Editing Agent",
        category: .devTools,
        role: "Performs targeted file edits requested by other agents.",
        systemInstructions: """
        You are the File Editing Agent. Apply edits using edit_file or write_file.
        Return JSON: { "files_modified":[], "diffs":[] }
        """,
        toolPermissions: ["read_file","write_file","edit_file","delete_file","list_files","generate_diff"],
        inputSchema: ["edits[]"],
        outputSchema: ["files_modified[]","diffs[]"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 4000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to Code Reviewer."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.pencil,
        description: "Applies targeted file edits."
    )
}
