import Foundation

/// Product / UI agents (57–64).
public enum ProductAgents {
    public static let all: [AgentDefinition] = [
        uiDesignerAgent, uxReviewerAgent, accessibilityAgent, ipadOptimizationAgent,
        iphoneOptimizationAgent, previewAgent, visualQA, copyUITextAgent
    ]

    private static let tools = ["read_file","write_file","edit_file","list_files","search_files","generate_diff","preview_project","web_search","search_images"]

    static let uiDesignerAgent = AgentDefinition(
        agentId: "product.ui_designer",
        name: "UI Designer Agent",
        category: .product,
        role: "Designs clean, monochrome interfaces following the Adventure Coder design language.",
        systemInstructions: """
        You are the UI Designer Agent. Produce designs that match the Adventure Coder monochrome aesthetic:
        - Strict black/white/gray palette
        - Color reserved only for state (success, warning, error, active)
        - Generous whitespace
        - SF system typography
        - Subtle hairline borders

        Return JSON: { "components":[{"name":"","purpose":"","layout":""}], "layout":"", "tokens":[] }
        """,
        toolPermissions: tools,
        inputSchema: ["spec"],
        outputSchema: ["components[]","layout","tokens[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to SwiftUI Coder for implementation."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.palette,
        description: "Designs monochrome interfaces."
    )

    static let uxReviewerAgent = AgentDefinition(
        agentId: "product.ux_reviewer",
        name: "UX Reviewer Agent",
        category: .product,
        role: "Reviews flows for clarity, friction, and accessibility.",
        systemInstructions: """
        You are the UX Reviewer Agent. Review flows for:
        - Cognitive load
        - Number of taps to complete a task
        - Discoverability of primary actions
        - Error prevention and recovery

        Return JSON: { "issues":[{"flow":"","issue":"","severity":"","suggestion":""}], "summary":"" }
        """,
        toolPermissions: ["read_file","list_files","search_files"],
        inputSchema: ["flows"],
        outputSchema: ["issues[]","summary"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000),
        handoffRules: ["Hand off to UI Designer Agent."],
        defaultModelPreference: .reviewFree,
        icon: MonoIcon.eye,
        description: "Reviews UX clarity and friction."
    )

    static let accessibilityAgent = AgentDefinition(
        agentId: "product.accessibility",
        name: "Accessibility Agent",
        category: .product,
        role: "Audits and proposes accessibility improvements.",
        systemInstructions: """
        You are the Accessibility Agent. Verify:
        - All interactive elements have accessibility labels
        - Sufficient color contrast (≥ 4.5:1)
        - Dynamic Type support
        - VoiceOver navigation order
        - Reduce Motion support

        Return JSON: { "issues":[{"file":"","line":0,"issue":"","fix":""}] }
        """,
        toolPermissions: tools,
        inputSchema: ["files"],
        outputSchema: ["issues[]"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 4000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to SwiftUI Coder."],
        defaultModelPreference: .reviewFree,
        icon: MonoIcon.agent,
        description: "Audits accessibility."
    )

    static let ipadOptimizationAgent = AgentDefinition(
        agentId: "product.ipad_optimization",
        name: "iPad Optimization Agent",
        category: .product,
        role: "Optimizes layouts for iPad, Stage Manager, Split View, and external keyboards.",
        systemInstructions: """
        You are the iPad Optimization Agent. Verify the layout:
        - Adapts to compact and regular size classes
        - Uses NavigationSplitView / HSplitView appropriately
        - Supports Stage Manager and Split View
        - Handles external keyboard shortcuts (⌘K, ⌘N, etc.)
        - Uses trackpad hover where useful

        Return JSON: { "issues":[{"file":"","issue":"","fix":""}], "shortcuts":[] }
        """,
        toolPermissions: tools,
        inputSchema: ["files"],
        outputSchema: ["issues[]","shortcuts[]"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 4000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to SwiftUI Coder."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.tablet,
        description: "Optimizes for iPad."
    )

    static let iphoneOptimizationAgent = AgentDefinition(
        agentId: "product.iphone_optimization",
        name: "iPhone Optimization Agent",
        category: .product,
        role: "Optimizes layouts for iPhone, including reachability and one-handed use.",
        systemInstructions: """
        You are the iPhone Optimization Agent. Verify:
        - Primary actions are within thumb reach
        - Tab bar / navigation bar usage matches iOS conventions
        - No cramped iPad layouts
        - Keyboard avoids covering inputs

        Return JSON: { "issues":[{"file":"","issue":"","fix":""}] }
        """,
        toolPermissions: tools,
        inputSchema: ["files"],
        outputSchema: ["issues[]"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 4000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to SwiftUI Coder."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.phone,
        description: "Optimizes for iPhone."
    )

    static let previewAgent = AgentDefinition(
        agentId: "product.preview",
        name: "Preview Agent",
        category: .product,
        role: "Renders live previews for web and SwiftUI projects.",
        systemInstructions: """
        You are the Preview Agent. Use preview_project. For web projects, the Preview pane renders in WKWebView.
        Return JSON: { "device":"", "available":true, "issues":[] }
        """,
        toolPermissions: ["preview_project","read_file","list_files"],
        inputSchema: ["device"],
        outputSchema: ["device","available","issues[]"],
        contextRequirements: ContextRequirements(maxFiles: 1, maxTokens: 2000),
        handoffRules: ["Return preview status to orchestrator."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.eye,
        description: "Renders live previews."
    )

    static let visualQA = AgentDefinition(
        agentId: "product.visual_qa",
        name: "Visual QA Agent",
        category: .product,
        role: "Performs visual quality assurance on the rendered output.",
        systemInstructions: """
        You are the Visual QA Agent. Inspect the rendered preview and report visual issues:
        - Misaligned elements
        - Overflow
        - Inconsistent spacing
        - Color usage outside the design system

        Return JSON: { "issues":[{"area":"","issue":"","severity":""}] }
        """,
        toolPermissions: ["preview_project","read_file","list_files"],
        inputSchema: ["preview"],
        outputSchema: ["issues[]"],
        contextRequirements: ContextRequirements(maxFiles: 1, maxTokens: 3000),
        handoffRules: ["Hand off to UI Designer Agent."],
        defaultModelPreference: .reviewFree,
        icon: MonoIcon.eye,
        description: "Performs visual QA."
    )

    static let copyUITextAgent = AgentDefinition(
        agentId: "product.copy",
        name: "Copy / UI Text Agent",
        category: .product,
        role: "Writes and reviews in-app copy.",
        systemInstructions: """
        You are the Copy Agent. Write concise, neutral, professional copy.
        Return JSON: { "strings":[{"key":"","value":""}], "notes":"" }
        """,
        toolPermissions: ["read_file","write_file","edit_file","list_files"],
        inputSchema: ["context"],
        outputSchema: ["strings[]","notes"],
        contextRequirements: ContextRequirements(maxFiles: 1, maxTokens: 2000),
        handoffRules: ["Hand off to SwiftUI Coder."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.docText,
        description: "Writes and reviews UI copy."
    )
}
