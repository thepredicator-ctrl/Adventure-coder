import Foundation

/// Public protocol every AI provider implements.
public protocol AIProvider: AnyObject {
    var id: String { get }
    var displayName: String { get }
    var requiresAPIKey: Bool { get }
    var keychainKey: KeychainService.Key { get }

    /// True if the provider currently has a stored key.
    func isConfigured() -> Bool

    /// Test the stored key by issuing a small request. Returns a friendly status.
    func testConnection() async -> ProviderTestResult

    /// Discover available models.
    func discoverModels() async -> [AIModel]

    /// Stream a chat completion, calling `onDelta` for each token batch.
    func streamChat(
        messages: [ProviderMessage],
        model: String,
        temperature: Double,
        maxTokens: Int,
        onDelta: @escaping (String) -> Void
    ) async throws -> ProviderCompletion

    /// Non-streaming chat completion.
    func chat(
        messages: [ProviderMessage],
        model: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> ProviderCompletion
}

public struct ProviderMessage: Codable, Hashable {
    public var role: String   // "system" | "user" | "assistant" | "tool"
    public var content: String
    public var name: String?

    public init(role: String, content: String, name: String? = nil) {
        self.role = role
        self.content = content
        self.name = name
    }
}

public struct ProviderCompletion: Codable {
    public var content: String
    public var finishReason: String
    public var usageTokensIn: Int
    public var usageTokensOut: Int
    public var model: String

    public init(content: String, finishReason: String = "stop", usageTokensIn: Int = 0, usageTokensOut: Int = 0, model: String = "") {
        self.content = content
        self.finishReason = finishReason
        self.usageTokensIn = usageTokensIn
        self.usageTokensOut = usageTokensOut
        self.model = model
    }
}

public enum ProviderError: Error, LocalizedError {
    case missingKey
    case invalidURL
    case requestFailed(Int, String)
    case decodingFailed
    case rateLimited
    case modelNotFound(String)
    case streamError(String)

    public var errorDescription: String? {
        switch self {
        case .missingKey: return "Provider API key is missing. Add it in Settings → AI Providers."
        case .invalidURL: return "Could not construct a valid request URL."
        case .requestFailed(let code, let body): return "Request failed with status \(code). \(body)"
        case .decodingFailed: return "Could not decode the provider's response."
        case .rateLimited: return "The provider rate-limited the request. Please retry in a moment."
        case .modelNotFound(let id): return "Model \(id) is not available on this provider."
        case .streamError(let msg): return "Streaming error: \(msg)"
        }
    }
}

public struct ProviderTestResult {
    public var success: Bool
    public var message: String
    public var modelsDiscovered: Int

    public init(success: Bool, message: String, modelsDiscovered: Int = 0) {
        self.success = success
        self.message = message
        self.modelsDiscovered = modelsDiscovered
    }
}
