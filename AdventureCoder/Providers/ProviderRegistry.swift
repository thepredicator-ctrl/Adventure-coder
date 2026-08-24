import Foundation

/// Registry of all configured AI providers, with a couple of fallback free models
/// used when discovery is offline (e.g. first launch with no API key).
public final class ProviderRegistry: ObservableObject {
    public static let shared = ProviderRegistry()

    public let providers: [AIProvider]

    private init() {
        providers = [
            OpenRouterProvider(),
            HuggingFaceProvider()
        ]
    }

    public func provider(id: String) -> AIProvider? {
        providers.first { $0.id == id }
    }

    /// Convenience: returns the provider for the given model id by checking which provider owns it.
    @MainActor
    public func provider(forModel modelId: String) -> AIProvider? {
        // OpenRouter models are typically vendor namespaced (e.g. "deepseek/deepseek-chat"),
        // Hugging Face models are organisation/namepsace (e.g. "meta-llama/Llama-3.1-8B-Instruct").
        // We resolve by checking which provider's discovered model list contains it,
        // falling back to OpenRouter for unknowns (it has the broadest catalog).
        for provider in providers {
            if CachedModelStore.shared.find(providerId: provider.id, modelId: modelId) != nil {
                return provider
            }
        }
        return providers.first
    }

    public func configuredProviders() -> [AIProvider] {
        providers.filter { $0.isConfigured() }
    }
}

/// In-memory cache of discovered models, refreshed periodically.
@MainActor
public final class CachedModelStore: ObservableObject {
    public static let shared = CachedModelStore()

    @Published public private(set) var models: [AIModel] = []
    @Published public private(set) var lastRefresh: Date?
    @Published public private(set) var isRefreshing = false

    private init() {}

    public func find(providerId: String, modelId: String) -> AIModel? {
        models.first { $0.providerId == providerId && $0.modelId == modelId }
    }

    public func find(modelId: String) -> AIModel? {
        models.first { $0.modelId == modelId }
    }

    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        var discovered: [AIModel] = []
        for provider in ProviderRegistry.shared.providers where provider.isConfigured() {
            let models = await provider.discoverModels()
            discovered.append(contentsOf: models)
        }
        if discovered.isEmpty {
            discovered = FallbackModels.list
        }
        models = discovered
        lastRefresh = Date()
    }

    public var freeModels: [AIModel] {
        models.filter { $0.isFree }.sorted { $0.compositeScore > $1.compositeScore }
    }

    public var paidModels: [AIModel] {
        models.filter { !$0.isFree }
    }
}

/// Curated fallback list used when no provider has been configured yet,
/// so the UI can show a populated model picker before any key is added.
public enum FallbackModels {
    public static let list: [AIModel] = [
        AIModel(
            providerId: "openrouter",
            modelId: "deepseek/deepseek-chat-v3-0324:free",
            displayName: "DeepSeek V3 0324 (free)",
            contextLength: 64000,
            maxOutputTokens: 8192,
            isFree: true,
            supportsToolCalls: true,
            supportsStreaming: true,
            description: "Strong general-purpose free model with tool support.",
            tags: ["free", "chat"],
            codingScore: 0.9,
            toolUseScore: 0.7,
            reliabilityScore: 0.82
        ),
        AIModel(
            providerId: "openrouter",
            modelId: "deepseek/deepseek-r1:free",
            displayName: "DeepSeek R1 (free)",
            contextLength: 64000,
            maxOutputTokens: 8192,
            isFree: true,
            supportsToolCalls: false,
            supportsStreaming: true,
            description: "Reasoning-focused free model.",
            tags: ["free", "reasoning"],
            codingScore: 0.88,
            toolUseScore: 0.5,
            reliabilityScore: 0.8
        ),
        AIModel(
            providerId: "openrouter",
            modelId: "qwen/qwen-2.5-coder-32b-instruct:free",
            displayName: "Qwen 2.5 Coder 32B (free)",
            contextLength: 32768,
            maxOutputTokens: 4096,
            isFree: true,
            supportsToolCalls: true,
            supportsStreaming: true,
            description: "Strong free coding model.",
            tags: ["free", "coding"],
            codingScore: 0.88,
            toolUseScore: 0.75,
            reliabilityScore: 0.83
        ),
        AIModel(
            providerId: "openrouter",
            modelId: "meta-llama/llama-3.3-70b-instruct:free",
            displayName: "Llama 3.3 70B Instruct (free)",
            contextLength: 131072,
            maxOutputTokens: 4096,
            isFree: true,
            supportsToolCalls: true,
            supportsStreaming: true,
            description: "Large-context free model from Meta.",
            tags: ["free", "chat"],
            codingScore: 0.78,
            toolUseScore: 0.8,
            reliabilityScore: 0.85
        ),
        AIModel(
            providerId: "openrouter",
            modelId: "mistralai/mistral-7b-instruct:free",
            displayName: "Mistral 7B Instruct (free)",
            contextLength: 32768,
            maxOutputTokens: 4096,
            isFree: true,
            supportsToolCalls: false,
            supportsStreaming: true,
            description: "Fast, lightweight free model.",
            tags: ["free", "fast"],
            codingScore: 0.7,
            toolUseScore: 0.4,
            reliabilityScore: 0.82
        ),
        AIModel(
            providerId: "huggingface",
            modelId: "meta-llama/Llama-3.2-3B-Instruct",
            displayName: "Llama 3.2 3B Instruct",
            contextLength: 131072,
            maxOutputTokens: 4096,
            isFree: true,
            supportsToolCalls: false,
            supportsStreaming: true,
            description: "Compact free model on Hugging Face.",
            tags: ["free", "small"],
            codingScore: 0.65,
            toolUseScore: 0.4,
            reliabilityScore: 0.78
        ),
        AIModel(
            providerId: "huggingface",
            modelId: "Qwen/Qwen2.5-7B-Instruct",
            displayName: "Qwen 2.5 7B Instruct",
            contextLength: 32768,
            maxOutputTokens: 4096,
            isFree: true,
            supportsToolCalls: false,
            supportsStreaming: true,
            description: "Free Qwen 7B on Hugging Face.",
            tags: ["free", "small"],
            codingScore: 0.72,
            toolUseScore: 0.4,
            reliabilityScore: 0.8
        ),
    ]
}
