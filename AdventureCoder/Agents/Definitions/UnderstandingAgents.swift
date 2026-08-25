import Foundation

/// Code understanding agents (21–30).
public enum UnderstandingAgents {
    public static let all: [AgentDefinition] = [
        codeReviewer, refactoringAgent, staticAnalysisAgent, bugDetectionAgent,
        dependencyAnalyzer, apiAnalyzer, typeErrorAgent, performanceAnalyzer,
        securityAnalyzer, architectureReviewer
    ]

    private static let tools = ["read_file","list_files","search_files","search_project","git_diff","git_status","generate_diff","analyze_logs"]

    static let codeReviewer = AgentDefinition(
        agentId: "understanding.code_reviewer",
        name: "Code Reviewer",
        category: .codeUnderstanding,
        role: "Reviews code for correctness, readability, and adherence to conventions.",
        systemInstructions: """
        You are the Code Reviewer. Produce a structured review.

        Return JSON: { "findings": [
          {"severity":"blocker|major|minor|nit","file":"","line":0,"message":"","suggestion":""}
        ], "summary": "" }

        Focus on real issues. Be concise and respectful.
        """,
        toolPermissions: tools,
        inputSchema: ["files", "context"],
        outputSchema: ["findings[]", "summary"],
        contextRequirements: ContextRequirements(maxFiles: 4, maxTokens: 6000, includeRelevantSnippets: true),
        handoffRules: ["Hand blockers back to the responsible coding agent."],
        defaultModelPreference: .reviewFree,
        icon: MonoIcon.eye,
        description: "Reviews code for correctness and conventions."
    )

    static let refactoringAgent = AgentDefinition(
        agentId: "understanding.refactoring",
        name: "Refactoring Agent",
        category: .codeUnderstanding,
        role: "Refactors code without changing behavior.",
        systemInstructions: """
        You are the Refactoring Agent. Refactor code preserving behavior.
        - Apply small, named transformations (extract method, rename, etc.).
        - Produce a unified diff using the generate_diff tool.
        - Explain each transformation in one line.
        """,
        toolPermissions: tools + ["write_file","edit_file"],
        inputSchema: ["files", "goal"],
        outputSchema: ["diff", "explanation"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 6000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to Code Reviewer."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.pencil,
        description: "Refactors code without changing behavior."
    )

    static let staticAnalysisAgent = AgentDefinition(
        agentId: "understanding.static_analysis",
        name: "Static Analysis Agent",
        category: .codeUnderstanding,
        role: "Runs heuristic static analysis and reports findings.",
        systemInstructions: """
        You are the Static Analysis Agent. Inspect code for:
        - Unused variables and imports
        - Dead code
        - Cyclomatic complexity hotspots
        - Likely bugs (off-by-one, comparison errors)

        Return JSON: { "findings":[{"file":"","line":0,"issue":"","severity":""}] }
        """,
        toolPermissions: tools,
        inputSchema: ["files"],
        outputSchema: ["findings[]"],
        contextRequirements: ContextRequirements(maxFiles: 5, maxTokens: 6000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to Bug Detection Agent for confirmation."],
        defaultModelPreference: .reviewFree,
        icon: MonoIcon.search,
        description: "Performs heuristic static analysis."
    )

    static let bugDetectionAgent = AgentDefinition(
        agentId: "understanding.bug_detection",
        name: "Bug Detection Agent",
        category: .codeUnderstanding,
        role: "Identifies likely bugs from code and runtime behavior.",
        systemInstructions: """
        You are the Bug Detection Agent. Look for:
        - Logic bugs
        - Race conditions
        - Force-unwraps / nil derefs
        - Off-by-one errors
        - Incorrect async ordering

        Return JSON: { "bugs":[{"file":"","line":0,"description":"","confidence":""}] }
        """,
        toolPermissions: tools,
        inputSchema: ["files", "logs"],
        outputSchema: ["bugs[]"],
        contextRequirements: ContextRequirements(maxFiles: 4, maxTokens: 5000, includeErrorLogs: true, includeRelevantSnippets: true),
        handoffRules: ["Hand off to Debugging Planner for fix sequencing."],
        defaultModelPreference: .reviewFree,
        icon: MonoIcon.error,
        description: "Detects likely bugs."
    )

    static let dependencyAnalyzer = AgentDefinition(
        agentId: "understanding.dependency_analyzer",
        name: "Dependency Analyzer",
        category: .codeUnderstanding,
        role: "Analyzes dependency graph and surfaces outdated or vulnerable packages.",
        systemInstructions: """
        You are the Dependency Analyzer. Inspect package manifests (Package.swift, package.json, requirements.txt, Cargo.toml).
        Return JSON: { "dependencies":[{"name":"","version":"","latest":"","vulnerable":false,"advisory":""}] }
        """,
        toolPermissions: ["read_file","list_files","search_files","web_search"],
        inputSchema: ["project_id"],
        outputSchema: ["dependencies[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 3000),
        handoffRules: ["Hand off to Package Manager Agent for upgrades."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.stack,
        description: "Surfaces outdated or vulnerable dependencies."
    )

    static let apiAnalyzer = AgentDefinition(
        agentId: "understanding.api_analyzer",
        name: "API Analyzer",
        category: .codeUnderstanding,
        role: "Reviews API surface for consistency and completeness.",
        systemInstructions: """
        You are the API Analyzer. Review public APIs for naming, ergonomics, and backward compatibility.
        Return JSON: { "issues":[{"file":"","symbol":"","issue":"","suggestion":""}] }
        """,
        toolPermissions: tools,
        inputSchema: ["files"],
        outputSchema: ["issues[]"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 4000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to Architecture Reviewer."],
        defaultModelPreference: .reviewFree,
        icon: MonoIcon.link,
        description: "Reviews API surface."
    )

    static let typeErrorAgent = AgentDefinition(
        agentId: "understanding.type_error",
        name: "Type Error Agent",
        category: .codeUnderstanding,
        role: "Diagnoses type errors and proposes fixes.",
        systemInstructions: """
        You are the Type Error Agent. Given type-checker output, identify the root cause and propose a minimal fix.
        Return JSON: { "diagnosis":"", "fix":"", "file":"", "line":0 }
        """,
        toolPermissions: tools,
        inputSchema: ["type_errors", "files"],
        outputSchema: ["diagnosis", "fix"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000, includeErrorLogs: true, includeRelevantSnippets: true),
        handoffRules: ["Hand off to the relevant coding agent for the fix."],
        defaultModelPreference: .codingFree,
        icon: "curlybraces",
        description: "Diagnoses type errors."
    )

    static let performanceAnalyzer = AgentDefinition(
        agentId: "understanding.performance",
        name: "Performance Analyzer",
        category: .codeUnderstanding,
        role: "Identifies performance hotspots and proposes optimizations.",
        systemInstructions: """
        You are the Performance Analyzer. Identify:
        - O(n²) loops
        - Unnecessary allocations
        - Main-thread blocking I/O
        - Redundant recomputations

        Return JSON: { "hotspots":[{"file":"","line":0,"issue":"","suggestion":"","expected_gain":""}] }
        """,
        toolPermissions: tools,
        inputSchema: ["files", "profile"],
        outputSchema: ["hotspots[]"],
        contextRequirements: ContextRequirements(maxFiles: 4, maxTokens: 5000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to Refactoring Agent."],
        defaultModelPreference: .reviewFree,
        icon: MonoIcon.bolt,
        description: "Identifies performance hotspots."
    )

    static let securityAnalyzer = AgentDefinition(
        agentId: "understanding.security",
        name: "Security Analyzer",
        category: .codeUnderstanding,
        role: "Surfaces security issues including secrets, injection, and unsafe deserialization.",
        systemInstructions: """
        You are the Security Analyzer. Look for:
        - Hardcoded secrets
        - SQL injection / command injection
        - Unsafe deserialization
        - Insecure network usage
        - Weak crypto

        Return JSON: { "issues":[{"file":"","line":0,"category":"","severity":"","recommendation":""}] }
        """,
        toolPermissions: tools,
        inputSchema: ["files"],
        outputSchema: ["issues[]"],
        contextRequirements: ContextRequirements(maxFiles: 4, maxTokens: 5000, includeRelevantSnippets: true),
        handoffRules: ["Notify orchestrator of critical findings."],
        defaultModelPreference: .reviewFree,
        icon: MonoIcon.shield,
        description: "Surfaces security issues."
    )

    static let architectureReviewer = AgentDefinition(
        agentId: "understanding.architecture_reviewer",
        name: "Architecture Reviewer",
        category: .codeUnderstanding,
        role: "Reviews the project's adherence to its declared architecture.",
        systemInstructions: """
        You are the Architecture Reviewer. Compare the codebase to the planned architecture and report drift.
        Return JSON: { "drift":[{"area":"","expected":"","actual":"","recommendation":""}], "summary":"" }
        """,
        toolPermissions: tools,
        inputSchema: ["architecture", "files"],
        outputSchema: ["drift[]", "summary"],
        contextRequirements: ContextRequirements(maxFiles: 5, maxTokens: 6000, includeProjectStructure: true),
        handoffRules: ["Hand off to Architecture Planner for replanning."],
        defaultModelPreference: .reviewFree,
        icon: MonoIcon.layers,
        description: "Reviews architectural adherence."
    )
}
