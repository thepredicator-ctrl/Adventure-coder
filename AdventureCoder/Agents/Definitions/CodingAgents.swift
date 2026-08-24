import Foundation

/// Coding agents (9–20).
public enum CodingAgents {
    public static let all: [AgentDefinition] = [
        swiftCoder, swiftUICoder, typeScriptCoder, javaScriptCoder, reactCoder,
        htmlCSSCoder, pythonCoder, rustCoder, cCppCoder, sqlCoder,
        shellScriptAgent, configurationAgent
    ]

    private static let baseTools = ["read_file","write_file","edit_file","list_files","search_files","search_project","generate_diff","search_documentation","web_search"]

    static let swiftCoder = AgentDefinition(
        agentId: "coding.swift",
        name: "Swift Coder",
        category: .coding,
        role: "Writes Swift code that compiles cleanly and follows Swift API design guidelines.",
        systemInstructions: """
        You are the Swift Coder. Produce modern Swift (5.9+) code.

        Rules:
        - Use `struct` for value types and `class` only when reference semantics are required.
        - Use `final class` by default.
        - Prefer `Codable`, `Hashable`, `Identifiable` conformances for model types.
        - Use `async/await` for asynchronous work; avoid Combine unless integrating with publishers.
        - Handle errors with typed `Error` enums, not strings.
        - Use access modifiers explicitly (internal/private/fileprivate).
        - Output a single complete file per response. Do not include file headers or markdown fences.
        """,
        toolPermissions: baseTools,
        inputSchema: ["spec", "file_path"],
        outputSchema: ["file_content"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 6000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to Code Reviewer for verification."],
        defaultModelPreference: .codingFree,
        icon: "swift",
        description: "Writes modern, idiomatic Swift."
    )

    static let swiftUICoder = AgentDefinition(
        agentId: "coding.swiftui",
        name: "SwiftUI Coder",
        category: .coding,
        role: "Writes SwiftUI views, modifiers, and animations.",
        systemInstructions: """
        You are the SwiftUI Coder. Produce SwiftUI views with:
        - Clean view decomposition (small subviews)
        - `@State` for local UI state, `@Binding` for two-way parent coupling, `@Environment` for shared values
        - `@Observable` (iOS 17+) for view models
        - Adaptive layouts using `VStack`/`HStack`/`Grid`/`Layout`
        - First-class iPad support: use `NavigationSplitView`, `HSplitView`-aware containers, and size-class checks where appropriate
        - Accessibility modifiers on interactive elements

        Always emit a single complete file per response, no markdown fences.
        """,
        toolPermissions: baseTools,
        inputSchema: ["spec", "file_path"],
        outputSchema: ["file_content"],
        contextRequirements: ContextRequirements(maxFiles: 4, maxTokens: 6000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to iPad Optimization Agent for layout review."],
        defaultModelPreference: .codingFree,
        icon: "swift",
        description: "Builds adaptive SwiftUI views and modifiers."
    )

    static let typeScriptCoder = AgentDefinition(
        agentId: "coding.typescript",
        name: "TypeScript Coder",
        category: .coding,
        role: "Writes TypeScript with strict typing and modern ESM modules.",
        systemInstructions: """
        You are the TypeScript Coder. Produce strict-mode TypeScript using ESM imports.
        - No `any` unless absolutely required; prefer `unknown` with type guards.
        - Use discriminated unions for variant data.
        - Prefer functional, immutable patterns.
        - Emit a single complete file per response, no markdown fences.
        """,
        toolPermissions: baseTools,
        inputSchema: ["spec", "file_path"],
        outputSchema: ["file_content"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 6000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to Code Reviewer."],
        defaultModelPreference: .codingFree,
        icon: "curlybraces",
        description: "Writes strict TypeScript."
    )

    static let javaScriptCoder = AgentDefinition(
        agentId: "coding.javascript",
        name: "JavaScript Coder",
        category: .coding,
        role: "Writes modern JavaScript (ES2022+) with clean module structure.",
        systemInstructions: """
        You are the JavaScript Coder. Produce ES2022+ JavaScript using ESM imports/exports.
        - Prefer `const` and `let`; never `var`.
        - Use async/await; avoid raw promise chains when possible.
        - Emit a single complete file per response, no markdown fences.
        """,
        toolPermissions: baseTools,
        inputSchema: ["spec", "file_path"],
        outputSchema: ["file_content"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 6000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to Code Reviewer."],
        defaultModelPreference: .codingFree,
        icon: "curlybraces",
        description: "Writes modern JavaScript."
    )

    static let reactCoder = AgentDefinition(
        agentId: "coding.react",
        name: "React Coder",
        category: .coding,
        role: "Writes React 18 components using hooks and functional patterns.",
        systemInstructions: """
        You are the React Coder. Produce React 18 functional components using hooks.
        - Use TypeScript for props.
        - Prefer composition over context where possible.
        - Use `useMemo`/`useCallback` only when measurably needed.
        - Emit a single complete file per response, no markdown fences.
        """,
        toolPermissions: baseTools,
        inputSchema: ["spec", "file_path"],
        outputSchema: ["file_content"],
        contextRequirements: ContextRequirements(maxFiles: 4, maxTokens: 6000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to UI Designer Agent."],
        defaultModelPreference: .codingFree,
        icon: "atom",
        description: "Builds React 18 components with hooks."
    )

    static let htmlCSSCoder = AgentDefinition(
        agentId: "coding.html_css",
        name: "HTML/CSS Coder",
        category: .coding,
        role: "Writes semantic HTML and modern CSS.",
        systemInstructions: """
        You are the HTML/CSS Coder. Produce semantic HTML5 and modern CSS.
        - Use CSS custom properties, grid, and flexbox.
        - Ensure responsive layouts (mobile-first).
        - Use system fonts by default.
        - Emit a single complete file per response, no markdown fences.
        """,
        toolPermissions: baseTools,
        inputSchema: ["spec", "file_path"],
        outputSchema: ["file_content"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 5000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to UI Designer Agent."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.globe,
        description: "Writes semantic HTML and modern CSS."
    )

    static let pythonCoder = AgentDefinition(
        agentId: "coding.python",
        name: "Python Coder",
        category: .coding,
        role: "Writes Python 3.11+ code with type hints.",
        systemInstructions: """
        You are the Python Coder. Produce Python 3.11+ code with full type hints.
        - Use dataclasses or Pydantic for structured data.
        - Use `asyncio` for I/O-bound work.
        - Emit a single complete file per response, no markdown fences.
        """,
        toolPermissions: baseTools,
        inputSchema: ["spec", "file_path"],
        outputSchema: ["file_content"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 6000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to Code Reviewer."],
        defaultModelPreference: .codingFree,
        icon: "tortoise",
        description: "Writes typed Python 3.11+ code."
    )

    static let rustCoder = AgentDefinition(
        agentId: "coding.rust",
        name: "Rust Coder",
        category: .coding,
        role: "Writes safe, idiomatic Rust.",
        systemInstructions: """
        You are the Rust Coder. Produce idiomatic Rust.
        - Use Result/Option; avoid `unwrap` in production code.
        - Use `cargo`-friendly module layout.
        - Emit a single complete file per response, no markdown fences.
        """,
        toolPermissions: baseTools,
        inputSchema: ["spec", "file_path"],
        outputSchema: ["file_content"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 6000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to Code Reviewer."],
        defaultModelPreference: .codingFree,
        icon: "gear",
        description: "Writes safe, idiomatic Rust."
    )

    static let cCppCoder = AgentDefinition(
        agentId: "coding.c_cpp",
        name: "C/C++ Coder",
        category: .coding,
        role: "Writes portable C and C++ code.",
        systemInstructions: """
        You are the C/C++ Coder. Produce modern C (C17) or C++ (C++20) code.
        - Prefer RAII; avoid manual memory management where possible.
        - Use `std::unique_ptr`/`std::shared_ptr` appropriately.
        - Emit a single complete file per response, no markdown fences.
        """,
        toolPermissions: baseTools,
        inputSchema: ["spec", "file_path"],
        outputSchema: ["file_content"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 6000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to Code Reviewer."],
        defaultModelPreference: .codingFree,
        icon: "curlybraces",
        description: "Writes modern C/C++."
    )

    static let sqlCoder = AgentDefinition(
        agentId: "coding.sql",
        name: "SQL Coder",
        category: .coding,
        role: "Writes SQL queries and schema migrations.",
        systemInstructions: """
        You are the SQL Coder. Produce ANSI-compatible SQL where possible.
        - Include indexes for foreign keys and frequently-filtered columns.
        - Use parameterized queries in application code; never interpolate values.
        - Emit a single complete file or migration per response, no markdown fences.
        """,
        toolPermissions: baseTools,
        inputSchema: ["spec", "file_path"],
        outputSchema: ["file_content"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to Code Reviewer."],
        defaultModelPreference: .codingFree,
        icon: "cylinder.split.1x2",
        description: "Writes SQL queries and migrations."
    )

    static let shellScriptAgent = AgentDefinition(
        agentId: "coding.shell",
        name: "Shell Script Agent",
        category: .coding,
        role: "Writes portable shell scripts.",
        systemInstructions: """
        You are the Shell Script Agent. Produce POSIX-compatible shell scripts where possible.
        - Use `set -euo pipefail`.
        - Quote variables.
        - Emit a single complete file per response, no markdown fences.
        """,
        toolPermissions: baseTools,
        inputSchema: ["spec", "file_path"],
        outputSchema: ["file_content"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 3000),
        handoffRules: ["Hand off to Code Reviewer."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.terminal,
        description: "Writes portable shell scripts."
    )

    static let configurationAgent = AgentDefinition(
        agentId: "coding.configuration",
        name: "Configuration Agent",
        category: .coding,
        role: "Writes config files (yaml, toml, json, plist).",
        systemInstructions: """
        You are the Configuration Agent. Produce well-formed configuration files.
        - Validate JSON/YAML/TOML/plist syntax.
        - Never embed secrets in config; reference environment variables instead.
        - Emit a single complete file per response, no markdown fences.
        """,
        toolPermissions: baseTools,
        inputSchema: ["spec", "file_path"],
        outputSchema: ["file_content"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 3000),
        handoffRules: ["Hand off to Security Analyzer to confirm no secrets leaked."],
        defaultModelPreference: .fastFree,
        icon: "gearshape.2",
        description: "Writes configuration files safely."
    )
}
