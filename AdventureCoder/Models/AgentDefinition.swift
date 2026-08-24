import Foundation

/// Definition of a specialized agent.
public struct AgentDefinition: Identifiable, Codable, Hashable {
    public var id: String { agentId }
    public var agentId: String
    public var name: String
    public var category: AgentCategory
    public var role: String
    public var systemInstructions: String
    public var toolPermissions: [String]
    public var inputSchema: [String]
    public var outputSchema: [String]
    public var contextRequirements: ContextRequirements
    public var handoffRules: [String]
    public var defaultModelPreference: ModelPreference
    public var icon: String
    public var description: String

    public init(
        agentId: String,
        name: String,
        category: AgentCategory,
        role: String,
        systemInstructions: String,
        toolPermissions: [String],
        inputSchema: [String] = [],
        outputSchema: [String] = [],
        contextRequirements: ContextRequirements = ContextRequirements(),
        handoffRules: [String] = [],
        defaultModelPreference: ModelPreference = .fastFree,
        icon: String = MonoIcon.agent,
        description: String = ""
    ) {
        self.agentId = agentId
        self.name = name
        self.category = category
        self.role = role
        self.systemInstructions = systemInstructions
        self.toolPermissions = toolPermissions
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
        self.contextRequirements = contextRequirements
        self.handoffRules = handoffRules
        self.defaultModelPreference = defaultModelPreference
        self.icon = icon
        self.description = description
    }
}

public enum AgentCategory: String, Codable, CaseIterable {
    case planning
    case coding
    case codeUnderstanding = "understanding"
    case debugging
    case research
    case devTools = "tools"
    case product
    case deployment

    public var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .coding: return "Coding"
        case .codeUnderstanding: return "Code Understanding"
        case .debugging: return "Debugging"
        case .research: return "Research"
        case .devTools: return "Development Tools"
        case .product: return "Product / UI"
        case .deployment: return "Deployment"
        }
    }

    public var icon: String {
        switch self {
        case .planning: return MonoIcon.list
        case .coding: return MonoIcon.terminal
        case .codeUnderstanding: return MonoIcon.search
        case .debugging: return MonoIcon.warning
        case .research: return MonoIcon.globe
        case .devTools: return MonoIcon.bolt
        case .product: return MonoIcon.palette
        case .deployment: return MonoIcon.upload
        }
    }
}

public struct ContextRequirements: Codable, Hashable {
    public var maxFiles: Int
    public var maxTokens: Int
    public var includeProjectStructure: Bool
    public var includeErrorLogs: Bool
    public var includeGitDiff: Bool
    public var includeRelevantSnippets: Bool

    public init(
        maxFiles: Int = 3,
        maxTokens: Int = 6000,
        includeProjectStructure: Bool = false,
        includeErrorLogs: Bool = false,
        includeGitDiff: Bool = false,
        includeRelevantSnippets: Bool = true
    ) {
        self.maxFiles = maxFiles
        self.maxTokens = maxTokens
        self.includeProjectStructure = includeProjectStructure
        self.includeErrorLogs = includeErrorLogs
        self.includeGitDiff = includeGitDiff
        self.includeRelevantSnippets = includeRelevantSnippets
    }
}

public enum ModelPreference: String, Codable {
    case fastFree          // small, fast, free model — preferred for simple tasks
    case codingFree        // stronger free coding model
    case planningFree      // planning-capable free model
    case reviewFree        // review-capable free model
    case strongestFree     // strongest available free model
    case strongestAny      // strongest available model (paid allowed only if user opted in)
}
