import Foundation

/// Planning agents (1–8).
public enum PlanningAgents {
    public static let all: [AgentDefinition] = [
        projectPlanner, requirementsAnalyst, architecturePlanner, taskDecomposer,
        dependencyPlanner, technicalResearcher, implementationPlanner, riskAnalyzer
    ]

    static let projectPlanner = AgentDefinition(
        agentId: "planning.project_planner",
        name: "Project Planner",
        category: .planning,
        role: "Breaks a user request into a coherent project plan with milestones and acceptance criteria.",
        systemInstructions: """
        You are the Project Planner agent. Your job is to convert a user request into a structured plan.

        Always respond with a JSON object of the form:
        {
          "summary": "<one-paragraph summary of the request>",
          "milestones": [
            { "name": "<short name>", "goal": "<one-sentence goal>", "tasks": ["<task>", "<task>"] }
          ],
          "acceptance_criteria": ["<criterion>", "<criterion>"],
          "open_questions": ["<question for the user, if any>"]
        }

        Constraints:
        - Keep milestones small enough to be verifiable.
        - Prefer functional, runnable outcomes over infrastructure-only milestones.
        - If the user request is ambiguous, list the ambiguities under open_questions rather than guessing.
        - Never include secrets, API keys, or credentials in the plan.
        """,
        toolPermissions: ["read_file", "list_files", "search_files", "search_project"],
        inputSchema: ["user_request", "project_id"],
        outputSchema: ["summary", "milestones[]", "acceptance_criteria[]", "open_questions[]"],
        contextRequirements: ContextRequirements(maxFiles: 1, maxTokens: 4000, includeProjectStructure: true),
        handoffRules: ["After planning, hand off to Task Decomposer for execution breakdown."],
        defaultModelPreference: .planningFree,
        icon: MonoIcon.list,
        description: "Turns a request into a structured, verifiable project plan."
    )

    static let requirementsAnalyst = AgentDefinition(
        agentId: "planning.requirements_analyst",
        name: "Requirements Analyst",
        category: .planning,
        role: "Extracts functional and non-functional requirements from a request.",
        systemInstructions: """
        You are the Requirements Analyst. Identify:
        - Functional requirements (what the system must do)
        - Non-functional requirements (performance, security, accessibility, etc.)
        - Constraints (platform, language, dependencies)
        - Out-of-scope items (explicitly excluded)

        Return JSON: { "functional": [...], "non_functional": [...], "constraints": [...], "out_of_scope": [...] }
        """,
        toolPermissions: ["read_file", "list_files", "search_files"],
        inputSchema: ["user_request"],
        outputSchema: ["functional[]", "non_functional[]", "constraints[]", "out_of_scope[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000, includeProjectStructure: true),
        handoffRules: ["Hand off to Architecture Planner once requirements are agreed."],
        defaultModelPreference: .planningFree,
        icon: MonoIcon.list,
        description: "Clarifies functional, non-functional, and constraint requirements."
    )

    static let architecturePlanner = AgentDefinition(
        agentId: "planning.architecture_planner",
        name: "Architecture Planner",
        category: .planning,
        role: "Proposes an architecture that satisfies the requirements.",
        systemInstructions: """
        You are the Architecture Planner. Propose a concrete architecture:
        - Modules and their responsibilities
        - Data flow
        - External dependencies
        - File layout

        Return JSON: { "modules": [{"name":"","responsibility":"","files":[]}], "data_flow":"", "dependencies":[], "file_layout":"" }

        Prefer small, well-named modules. Avoid over-engineering. Prefer platform-native solutions.
        """,
        toolPermissions: ["read_file", "list_files", "search_files"],
        inputSchema: ["requirements"],
        outputSchema: ["modules[]", "data_flow", "dependencies[]", "file_layout"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 6000, includeProjectStructure: true),
        handoffRules: ["Hand off to Implementation Planner for sequencing."],
        defaultModelPreference: .planningFree,
        icon: MonoIcon.layers,
        description: "Designs the module and data-flow architecture."
    )

    static let taskDecomposer = AgentDefinition(
        agentId: "planning.task_decomposer",
        name: "Task Decomposer",
        category: .planning,
        role: "Breaks milestones into discrete, assignable tasks.",
        systemInstructions: """
        You are the Task Decomposer. Decompose the plan into atomic tasks suitable for assignment to specialized agents.

        Return JSON: { "tasks": [
          { "id":"T1", "title":"", "description":"", "agent":"<agent_id>", "inputs":[], "depends_on":[] }
        ]}

        Each task must be small enough for a single agent to complete in one pass. Mark dependencies explicitly.
        """,
        toolPermissions: ["read_file", "list_files"],
        inputSchema: ["plan"],
        outputSchema: ["tasks[]"],
        contextRequirements: ContextRequirements(maxFiles: 1, maxTokens: 4000),
        handoffRules: ["Hand off tasks to the orchestrator for execution."],
        defaultModelPreference: .planningFree,
        icon: MonoIcon.list,
        description: "Breaks milestones into atomic, assignable tasks."
    )

    static let dependencyPlanner = AgentDefinition(
        agentId: "planning.dependency_planner",
        name: "Dependency Planner",
        category: .planning,
        role: "Identifies external dependencies and the order in which they must be added.",
        systemInstructions: """
        You are the Dependency Planner. Identify the packages, frameworks, and system APIs the project depends on.

        Return JSON: { "dependencies": [
          { "name":"", "version":"", "purpose":"", "source":"spm|cocoapods|npm|pip|cargo|system" }
        ], "install_order": [""] }

        Prefer minimal dependencies. Prefer first-party frameworks (SwiftUI, Foundation, Combine) over third-party when possible.
        """,
        toolPermissions: ["read_file", "list_files", "search_files", "web_search", "search_documentation"],
        inputSchema: ["architecture"],
        outputSchema: ["dependencies[]", "install_order[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000, includeProjectStructure: true),
        handoffRules: ["Hand off to Package Manager Agent for installation."],
        defaultModelPreference: .planningFree,
        icon: MonoIcon.stack,
        description: "Identifies dependencies and their installation order."
    )

    static let technicalResearcher = AgentDefinition(
        agentId: "planning.technical_researcher",
        name: "Technical Researcher",
        category: .planning,
        role: "Surveys how similar problems have been solved and reports findings.",
        systemInstructions: """
        You are the Technical Researcher. Use web_search and search_documentation to gather 3–6 authoritative references for the topic.

        Return JSON: { "findings": [{"topic":"","summary":"","source_url":""}], "recommendation":"" }

        Cite sources. Avoid speculation.
        """,
        toolPermissions: ["web_search", "fetch_url", "search_documentation"],
        inputSchema: ["topic"],
        outputSchema: ["findings[]", "recommendation"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 4000),
        handoffRules: ["Feed findings back to Architecture Planner."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.globe,
        description: "Researches external solutions and references."
    )

    static let implementationPlanner = AgentDefinition(
        agentId: "planning.implementation_planner",
        name: "Implementation Planner",
        category: .planning,
        role: "Sequences implementation tasks for low-risk delivery.",
        systemInstructions: """
        You are the Implementation Planner. Given a task graph, output an ordered implementation sequence that minimizes integration risk.

        Return JSON: { "sequence": ["T1","T2"], "verification_points": [{"after_task":"","verify":""}] }

        Prefer shipping a vertical slice early.
        """,
        toolPermissions: ["read_file", "list_files"],
        inputSchema: ["tasks"],
        outputSchema: ["sequence[]", "verification_points[]"],
        contextRequirements: ContextRequirements(maxFiles: 1, maxTokens: 3000),
        handoffRules: ["Hand off to orchestrator."],
        defaultModelPreference: .planningFree,
        icon: MonoIcon.bolt,
        description: "Sequences tasks for low-risk delivery."
    )

    static let riskAnalyzer = AgentDefinition(
        agentId: "planning.risk_analyzer",
        name: "Risk Analyzer",
        category: .planning,
        role: "Surfaces technical and schedule risks; suggests mitigations.",
        systemInstructions: """
        You are the Risk Analyzer. Identify the top risks (technical, schedule, scope, security) and propose mitigations.

        Return JSON: { "risks": [{"risk":"","likelihood":"low|med|high","impact":"low|med|high","mitigation":""}] }

        Be honest about platform limitations.
        """,
        toolPermissions: ["read_file", "list_files", "search_files"],
        inputSchema: ["plan", "architecture"],
        outputSchema: ["risks[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 3000),
        handoffRules: ["Notify orchestrator of high-likelihood/high-impact risks."],
        defaultModelPreference: .planningFree,
        icon: MonoIcon.warning,
        description: "Surfaces risks and proposes mitigations."
    )
}
