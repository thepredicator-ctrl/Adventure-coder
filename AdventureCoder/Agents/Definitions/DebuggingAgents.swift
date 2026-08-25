import Foundation

/// Debugging agents (31–38).
public enum DebuggingAgents {
    public static let all: [AgentDefinition] = [
        buildErrorAgent, runtimeErrorAgent, crashAnalyzer, logAnalyzer,
        testFailureAgent, regressionAgent, debuggingPlanner, fixVerificationAgent
    ]

    private static let tools = ["read_file","list_files","search_files","search_project","git_diff","git_status","git_history","analyze_logs","run_command","web_search","search_documentation"]

    static let buildErrorAgent = AgentDefinition(
        agentId: "debugging.build_error",
        name: "Build Error Agent",
        category: .debugging,
        role: "Diagnoses build errors and proposes minimal fixes.",
        systemInstructions: """
        You are the Build Error Agent. Given build logs and the relevant files:
        1. Identify the root cause of each error.
        2. Propose a minimal fix (file, line, change).
        3. Note any secondary errors that will likely appear after the first fix.

        Return JSON: { "errors":[{"file":"","line":0,"cause":"","fix":""}], "next_steps":"" }
        """,
        toolPermissions: tools,
        inputSchema: ["logs", "files"],
        outputSchema: ["errors[]", "next_steps"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 6000, includeErrorLogs: true, includeRelevantSnippets: true),
        handoffRules: ["Hand off to the relevant coding agent."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.error,
        description: "Diagnoses build errors."
    )

    static let runtimeErrorAgent = AgentDefinition(
        agentId: "debugging.runtime_error",
        name: "Runtime Error Agent",
        category: .debugging,
        role: "Diagnoses runtime exceptions and crashes.",
        systemInstructions: """
        You are the Runtime Error Agent. Given a stack trace and surrounding code:
        - Identify the failing component and root cause.
        - Propose a fix.

        Return JSON: { "diagnosis":"", "root_cause":"", "fix":"", "files":[] }
        """,
        toolPermissions: tools,
        inputSchema: ["stack_trace", "files"],
        outputSchema: ["diagnosis", "root_cause", "fix"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 5000, includeErrorLogs: true, includeRelevantSnippets: true),
        handoffRules: ["Hand off to the relevant coding agent."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.warning,
        description: "Diagnoses runtime errors."
    )

    static let crashAnalyzer = AgentDefinition(
        agentId: "debugging.crash_analyzer",
        name: "Crash Analyzer",
        category: .debugging,
        role: "Analyzes crash reports and pinpoints the failing code path.",
        systemInstructions: """
        You are the Crash Analyzer. Parse the crash report, identify the crashing thread, and propose a fix.
        Return JSON: { "crashing_thread":0, "symbol":"", "cause":"", "fix":"", "files":[] }
        """,
        toolPermissions: tools,
        inputSchema: ["crash_report"],
        outputSchema: ["crashing_thread", "symbol", "cause", "fix"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 5000, includeErrorLogs: true),
        handoffRules: ["Hand off to Runtime Error Agent."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.error,
        description: "Analyzes crash reports."
    )

    static let logAnalyzer = AgentDefinition(
        agentId: "debugging.log_analyzer",
        name: "Log Analyzer",
        category: .debugging,
        role: "Extracts errors, warnings, and patterns from logs.",
        systemInstructions: """
        You are the Log Analyzer. Parse logs and return a structured summary.
        Return JSON: { "errors":[], "warnings":[], "patterns":[], "anomalies":[] }
        """,
        toolPermissions: ["analyze_logs","read_file","search_files"],
        inputSchema: ["logs"],
        outputSchema: ["errors[]","warnings[]","patterns[]","anomalies[]"],
        contextRequirements: ContextRequirements(maxFiles: 1, maxTokens: 4000, includeErrorLogs: true),
        handoffRules: ["Hand off to Runtime Error Agent if a crash is detected."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.list,
        description: "Extracts errors and patterns from logs."
    )

    static let testFailureAgent = AgentDefinition(
        agentId: "debugging.test_failure",
        name: "Test Failure Agent",
        category: .debugging,
        role: "Diagnoses failing tests and proposes fixes.",
        systemInstructions: """
        You are the Test Failure Agent. Given test output and the relevant source files:
        - Identify whether the failure is in the test or in production code.
        - Propose the minimal fix.

        Return JSON: { "failures":[{"test":"","file":"","line":0,"cause":"","fix":""}] }
        """,
        toolPermissions: tools,
        inputSchema: ["test_output", "files"],
        outputSchema: ["failures[]"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 5000, includeErrorLogs: true, includeRelevantSnippets: true),
        handoffRules: ["Hand off to the relevant coding agent."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.error,
        description: "Diagnoses failing tests."
    )

    static let regressionAgent = AgentDefinition(
        agentId: "debugging.regression",
        name: "Regression Agent",
        category: .debugging,
        role: "Identifies the commit that introduced a regression.",
        systemInstructions: """
        You are the Regression Agent. Use git_history and git_diff to identify the most likely regression-introducing commit.
        Return JSON: { "suspected_commit":"", "reasoning":"", "evidence":[] }
        """,
        toolPermissions: ["git_history","git_diff","git_status","read_file","search_files"],
        inputSchema: ["symptom"],
        outputSchema: ["suspected_commit", "reasoning"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000, includeGitDiff: true),
        handoffRules: ["Hand off to Runtime Error Agent."],
        defaultModelPreference: .reviewFree,
        icon: MonoIcon.history,
        description: "Identifies the commit that introduced a regression."
    )

    static let debuggingPlanner = AgentDefinition(
        agentId: "debugging.planner",
        name: "Debugging Planner",
        category: .debugging,
        role: "Plans a debugging strategy given a symptom.",
        systemInstructions: """
        You are the Debugging Planner. Given a symptom, output an ordered debugging plan.
        Return JSON: { "steps":[""], "hypotheses":[""], "tests_to_run":[""] }
        """,
        toolPermissions: ["read_file","list_files","search_files","git_history","analyze_logs"],
        inputSchema: ["symptom"],
        outputSchema: ["steps[]","hypotheses[]","tests_to_run[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 3000),
        handoffRules: ["Hand off to Runtime Error Agent or Build Error Agent."],
        defaultModelPreference: .planningFree,
        icon: MonoIcon.list,
        description: "Plans a debugging strategy."
    )

    static let fixVerificationAgent = AgentDefinition(
        agentId: "debugging.fix_verification",
        name: "Fix Verification Agent",
        category: .debugging,
        role: "Verifies that a proposed fix resolves the issue without regressions.",
        systemInstructions: """
        You are the Fix Verification Agent. After a fix is applied:
        - Re-run the build/tests.
        - Confirm the original symptom is gone.
        - Check for new regressions.

        Return JSON: { "verified":true, "remaining_issues":[], "follow_ups":[] }
        """,
        toolPermissions: ["build_project","run_tests","analyze_logs","git_diff","read_file"],
        inputSchema: ["original_symptom", "fix_diff"],
        outputSchema: ["verified", "remaining_issues[]", "follow_ups[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000, includeErrorLogs: true),
        handoffRules: ["If not verified, hand back to the debugging agent."],
        defaultModelPreference: .reviewFree,
        icon: MonoIcon.check,
        description: "Verifies that fixes resolve issues."
    )
}
