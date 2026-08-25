import Foundation

/// An AI model exposed by a provider.
public struct AIModel: Identifiable, Codable, Hashable {
    public var id: String { modelId }
    public var providerId: String
    public var modelId: String
    public var displayName: String
    public var contextLength: Int
    public var maxOutputTokens: Int
    public var isFree: Bool
    public var promptPricePer1K: Double
    public var completionPricePer1K: Double
    public var supportsToolCalls: Bool
    public var supportsVision: Bool
    public var supportsStreaming: Bool
    public var description: String
    public var tags: [String]
    public var codingScore: Double
    public var toolUseScore: Double
    public var reliabilityScore: Double

    public init(
        providerId: String,
        modelId: String,
        displayName: String? = nil,
        contextLength: Int = 4096,
        maxOutputTokens: Int = 2048,
        isFree: Bool = false,
        promptPricePer1K: Double = 0,
        completionPricePer1K: Double = 0,
        supportsToolCalls: Bool = false,
        supportsVision: Bool = false,
        supportsStreaming: Bool = true,
        description: String = "",
        tags: [String] = [],
        codingScore: Double = 0.5,
        toolUseScore: Double = 0.5,
        reliabilityScore: Double = 0.5
    ) {
        self.providerId = providerId
        self.modelId = modelId
        self.displayName = displayName ?? modelId
        self.contextLength = contextLength
        self.maxOutputTokens = maxOutputTokens
        self.isFree = isFree
        self.promptPricePer1K = promptPricePer1K
        self.completionPricePer1K = completionPricePer1K
        self.supportsToolCalls = supportsToolCalls
        self.supportsVision = supportsVision
        self.supportsStreaming = supportsStreaming
        self.description = description
        self.tags = tags
        self.codingScore = codingScore
        self.toolUseScore = toolUseScore
        self.reliabilityScore = reliabilityScore
    }

    /// Composite score used by the free-model ranker.
    public var compositeScore: Double {
        let contextScore = min(Double(contextLength) / 32_000.0, 1.0) * 0.25
        let coding = codingScore * 0.4
        let toolUse = toolUseScore * 0.2
        let reliability = reliabilityScore * 0.15
        return contextScore + coding + toolUse + reliability
    }

    public var displayPrice: String {
        if isFree { return "Free" }
        if promptPricePer1K == 0 && completionPricePer1K == 0 { return "—" }
        return String(format: "$%.3f / $%.3f per 1K", promptPricePer1K, completionPricePer1K)
    }
}

public struct ToolInvocation: Identifiable, Codable, Hashable {
    public var id: UUID
    public var toolName: String
    public var inputSummary: String
    public var outputSummary: String
    public var status: Status
    public var startedAt: Date
    public var finishedAt: Date?

    public enum Status: String, Codable {
        case pending, running, success, failed, denied

        public var label: String {
            switch self {
            case .pending: return "Queued"
            case .running: return "Running"
            case .success: return "Done"
            case .failed: return "Error"
            case .denied: return "Denied"
            }
        }
    }

    public init(
        id: UUID = UUID(),
        toolName: String,
        inputSummary: String,
        outputSummary: String = "",
        status: Status = .pending,
        startedAt: Date = Date(),
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.toolName = toolName
        self.inputSummary = inputSummary
        self.outputSummary = outputSummary
        self.status = status
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

public struct ToolResult: Identifiable, Codable, Hashable {
    public var id: UUID
    public var toolName: String
    public var success: Bool
    public var output: String
    public var error: String?
    public var timestamp: Date

    public init(id: UUID = UUID(), toolName: String, success: Bool, output: String, error: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.toolName = toolName
        self.success = success
        self.output = output
        self.error = error
        self.timestamp = timestamp
    }
}
