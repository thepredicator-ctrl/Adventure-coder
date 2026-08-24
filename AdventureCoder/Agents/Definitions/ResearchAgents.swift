import Foundation

/// Research / tools agents (39–48).
public enum ResearchAgents {
    public static let all: [AgentDefinition] = [
        webSearchAgent, documentationSearchAgent, githubSearchAgent, packageSearchAgent,
        stackKnowledgeResearchAgent, webPageReaderAgent, urlFetchAgent, imageSearchAgent,
        fileSearchAgent, projectExplorerAgent
    ]

    static let webSearchAgent = AgentDefinition(
        agentId: "research.web_search",
        name: "Web Search Agent",
        category: .research,
        role: "Performs web searches and returns ranked results.",
        systemInstructions: """
        You are the Web Search Agent. Use the web_search tool to find authoritative sources.
        Return JSON: { "query":"", "results":[{"title":"","url":"","snippet":""}], "synthesis":"" }
        """,
        toolPermissions: ["web_search","fetch_url"],
        inputSchema: ["query"],
        outputSchema: ["query","results[]","synthesis"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 3000),
        handoffRules: ["Return results to the originating agent."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.globe,
        description: "Performs web searches."
    )

    static let documentationSearchAgent = AgentDefinition(
        agentId: "research.documentation",
        name: "Documentation Search Agent",
        category: .research,
        role: "Searches developer documentation (Apple, Swift.org, MDN, GitHub).",
        systemInstructions: """
        You are the Documentation Search Agent. Use search_documentation to find authoritative docs.
        Return JSON: { "query":"", "results":[{"title":"","url":"","snippet":""}], "summary":"" }
        """,
        toolPermissions: ["search_documentation","fetch_url","web_search"],
        inputSchema: ["query", "source"],
        outputSchema: ["query","results[]","summary"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 3000),
        handoffRules: ["Hand results back to the coding agent that requested them."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.docText,
        description: "Searches developer documentation."
    )

    static let githubSearchAgent = AgentDefinition(
        agentId: "research.github_search",
        name: "GitHub Search Agent",
        category: .research,
        role: "Searches GitHub for relevant repositories, code, and issues.",
        systemInstructions: """
        You are the GitHub Search Agent. Use github_search to find repositories.
        Return JSON: { "query":"", "repos":[{"full_name":"","url":"","description":"","stars":0}] }
        """,
        toolPermissions: ["github_search","github_repos","fetch_url"],
        inputSchema: ["query"],
        outputSchema: ["query","repos[]"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 3000),
        handoffRules: ["Return results to originating agent."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.github,
        description: "Searches GitHub repositories."
    )

    static let packageSearchAgent = AgentDefinition(
        agentId: "research.package_search",
        name: "Package Search Agent",
        category: .research,
        role: "Searches for packages/libraries matching a need.",
        systemInstructions: """
        You are the Package Search Agent. Find packages across SPM, npm, PyPI, crates.io.
        Return JSON: { "packages":[{"name":"","registry":"","url":"","description":"","stars":0}] }
        """,
        toolPermissions: ["web_search","github_search","fetch_url"],
        inputSchema: ["need", "language"],
        outputSchema: ["packages[]"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 3000),
        handoffRules: ["Hand off to Dependency Planner."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.stack,
        description: "Finds packages matching a need."
    )

    static let stackKnowledgeResearchAgent = AgentDefinition(
        agentId: "research.knowledge",
        name: "Stack/Knowledge Research Agent",
        category: .research,
        role: "Surveys Stack Overflow and technical blogs for solutions.",
        systemInstructions: """
        You are the Knowledge Research Agent. Use web_search to gather community solutions.
        Return JSON: { "query":"", "results":[{"title":"","url":"","snippet":""}], "synthesis":"" }
        """,
        toolPermissions: ["web_search","fetch_url"],
        inputSchema: ["query"],
        outputSchema: ["query","results[]","synthesis"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 3000),
        handoffRules: ["Return results to originating agent."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.globe,
        description: "Surveys community solutions."
    )

    static let webPageReaderAgent = AgentDefinition(
        agentId: "research.web_reader",
        name: "Web Page Reader Agent",
        category: .research,
        role: "Fetches a URL and returns cleaned text.",
        systemInstructions: """
        You are the Web Page Reader Agent. Use fetch_url to retrieve the page, then summarize.
        Return JSON: { "url":"", "title":"", "summary":"", "key_points":[] }
        """,
        toolPermissions: ["fetch_url"],
        inputSchema: ["url"],
        outputSchema: ["url","title","summary","key_points[]"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 4000),
        handoffRules: ["Return summary to originating agent."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.docText,
        description: "Reads and summarizes web pages."
    )

    static let urlFetchAgent = AgentDefinition(
        agentId: "research.url_fetch",
        name: "URL Fetch Agent",
        category: .research,
        role: "Fetches a raw URL and returns its body.",
        systemInstructions: """
        You are the URL Fetch Agent. Use fetch_url and return the body verbatim (truncated to 8000 chars).
        Return JSON: { "url":"", "status":"", "body":"" }
        """,
        toolPermissions: ["fetch_url"],
        inputSchema: ["url"],
        outputSchema: ["url","status","body"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 4000),
        handoffRules: ["Return body to originating agent."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.download,
        description: "Fetches raw URL bodies."
    )

    static let imageSearchAgent = AgentDefinition(
        agentId: "research.image_search",
        name: "Image Search Agent",
        category: .research,
        role: "Finds images relevant to a query.",
        systemInstructions: """
        You are the Image Search Agent. Use search_images.
        Return JSON: { "query":"", "images":[{"title":"","url":"","thumbnail":""}] }
        """,
        toolPermissions: ["search_images"],
        inputSchema: ["query"],
        outputSchema: ["query","images[]"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 2000),
        handoffRules: ["Return images to originating agent."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.image,
        description: "Finds images for a query."
    )

    static let fileSearchAgent = AgentDefinition(
        agentId: "research.file_search",
        name: "File Search Agent",
        category: .research,
        role: "Finds files matching a name or content pattern.",
        systemInstructions: """
        You are the File Search Agent. Use search_files and search_project.
        Return JSON: { "query":"", "matches":[{"path":"","line":0,"snippet":""}] }
        """,
        toolPermissions: ["search_files","search_project","list_files"],
        inputSchema: ["query"],
        outputSchema: ["query","matches[]"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 3000),
        handoffRules: ["Return matches to originating agent."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.search,
        description: "Finds files matching a query."
    )

    static let projectExplorerAgent = AgentDefinition(
        agentId: "research.project_explorer",
        name: "Project Explorer Agent",
        category: .research,
        role: "Builds a structured overview of the project.",
        systemInstructions: """
        You are the Project Explorer Agent. Use list_files to walk the project and produce a structural summary.
        Return JSON: { "root":"", "directories":[], "key_files":[], "estimated_loc":0, "languages":[] }
        """,
        toolPermissions: ["list_files","read_file","search_files"],
        inputSchema: ["project_id"],
        outputSchema: ["root","directories[]","key_files[]","estimated_loc","languages[]"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 3000, includeProjectStructure: true),
        handoffRules: ["Hand off to Architecture Reviewer."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.folder,
        description: "Builds a project structural overview."
    )
}
