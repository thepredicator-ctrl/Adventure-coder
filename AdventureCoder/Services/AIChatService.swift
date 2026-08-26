import Foundation
import Combine

/// Unified AI chat service that routes requests through the actually-selected provider and model.
///
/// This is the SINGLE entry point for all AI chat operations. It reads the user's
/// provider + model selection from `SettingsStore` and routes the request to the
/// correct provider API. No other code should call providers directly.
///
/// Provider → Selected Model → AI Request → Provider API → Response
@MainActor
public final class AIChatService: ObservableObject {
    public static let shared = AIChatService()

    @Published public var isGenerating = false
    @Published public var streamingContent = ""
    @Published public var error: String?

    private var currentTask: Task<Void, Never>?

    private init() {}

    // MARK: - Resolution

    /// Resolves the currently-selected provider + model from settings.
    /// Falls back to the best free model if no explicit selection exists.
    public func resolveSelectedModel() -> (provider: AIProvider, model: AIModel)? {
        let settings = SettingsStore.shared

        // 1. If user explicitly selected a model, find it
        if let modelId = settings.primaryModelId {
            if let model = CachedModelStore.shared.find(modelId: modelId),
               let provider = ProviderRegistry.shared.provider(id: model.providerId) {
                // Verify the provider is configured (has a key)
                if provider.isConfigured() {
                    return (provider, model)
                }
            }
        }

        // 2. Auto-select: find the best free model from configured providers
        let configuredProviders = ProviderRegistry.shared.configuredProviders()
        for provider in configuredProviders {
            let models = CachedModelStore.shared.models.filter { $0.providerId == provider.id }
            let freeModels = models.filter { $0.isFree }
            if let best = freeModels.sorted(by: { $0.compositeScore > $1.compositeScore }).first {
                // Persist this auto-selection
                settings.primaryModelId = best.modelId
                return (provider, best)
            }
        }

        // 3. Fallback to any model from any configured provider
        for provider in configuredProviders {
            let models = CachedModelStore.shared.models.filter { $0.providerId == provider.id }
            if let first = models.first {
                return (provider, first)
            }
        }

        return nil
    }

    /// Returns the display name of the currently selected model.
    public var selectedModelDisplayName: String {
        if let resolved = resolveSelectedModel() {
            return resolved.model.displayName
        }
        return "No model selected"
    }

    /// Returns the provider name of the currently selected model.
    public var selectedProviderName: String {
        if let resolved = resolveSelectedModel() {
            return resolved.provider.displayName
        }
        return "—"
    }

    // MARK: - Chat (non-streaming)

    /// Send a chat request using the currently-selected provider and model.
    public func chat(
        messages: [ProviderMessage],
        temperature: Double = 0.3,
        maxTokens: Int = 1500
    ) async throws -> ProviderCompletion {
        guard let resolved = resolveSelectedModel() else {
            throw AIChatError.noModelSelected
        }

        do {
            return try await resolved.provider.chat(
                messages: messages,
                model: resolved.model.modelId,
                temperature: temperature,
                maxTokens: maxTokens
            )
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Streaming Chat

    /// Stream a chat response, calling onDelta for each token.
    /// Uses the currently-selected provider and model.
    public func streamChat(
        messages: [ProviderMessage],
        temperature: Double = 0.3,
        maxTokens: Int = 1500,
        onDelta: @escaping (String) -> Void
    ) async throws -> ProviderCompletion {
        guard let resolved = resolveSelectedModel() else {
            throw AIChatError.noModelSelected
        }

        isGenerating = true
        streamingContent = ""
        error = nil

        defer { isGenerating = false }

        do {
            let completion = try await resolved.provider.streamChat(
                messages: messages,
                model: resolved.model.modelId,
                temperature: temperature,
                maxTokens: maxTokens,
                onDelta: { delta in
                    Task { @MainActor in
                        self.streamingContent += delta
                    }
                    onDelta(delta)
                }
            )
            return completion
        } catch {
            throw mapError(error)
        }
    }

    /// Stop the current generation.
    public func stopGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

    // MARK: - Model Discovery

    /// Refresh the model list from all configured providers.
    public func refreshModels() async {
        await CachedModelStore.shared.refresh()

        // After refresh, verify the current selection is still valid
        let settings = SettingsStore.shared
        if let modelId = settings.primaryModelId {
            if CachedModelStore.shared.find(modelId: modelId) == nil {
                // Model no longer available — clear selection
                settings.primaryModelId = nil
            }
        }
    }

    /// Set the selected provider and model.
    public func selectModel(providerId: String, modelId: String) {
        let settings = SettingsStore.shared
        settings.primaryModelId = modelId
        // Also set role-specific defaults if not already set
        if settings.codingModelId == nil { settings.codingModelId = modelId }
        if settings.fastModelId == nil { settings.fastModelId = modelId }
        if settings.planningModelId == nil { settings.planningModelId = modelId }
        if settings.reviewModelId == nil { settings.reviewModelId = modelId }
    }

    // MARK: - Error Mapping

    private func mapError(_ error: Error) -> Error {
        if let providerError = error as? ProviderError {
            switch providerError {
            case .missingKey:
                return AIChatError.noApiKey
            case .rateLimited:
                return AIChatError.rateLimited
            case .requestFailed(let code, let body):
                return AIChatError.providerError("Request failed (\(code)): \(body)")
            case .modelNotFound(let modelId):
                return AIChatError.modelNotFound(modelId)
            case .connectionTimeout:
                return AIChatError.timeout
            default:
                return AIChatError.providerError(error.localizedDescription)
            }
        }
        return error
    }
}

// MARK: - Errors

public enum AIChatError: Error, LocalizedError {
    case noModelSelected
    case noApiKey
    case rateLimited
    case timeout
    case modelNotFound(String)
    case providerError(String)

    public var errorDescription: String? {
        switch self {
        case .noModelSelected:
            return "No AI model is selected. Go to Connections to configure a provider and select a model."
        case .noApiKey:
            return "No API key is configured. Go to Connections to add your provider API key."
        case .rateLimited:
            return "The provider rate-limited the request. Please wait a moment and try again."
        case .timeout:
            return "The request timed out. The provider may be slow or unavailable."
        case .modelNotFound(let modelId):
            return "The model '\(modelId)' is not available. It may have been removed or your API key doesn't have access."
        case .providerError(let detail):
            return detail
        }
    }
}
