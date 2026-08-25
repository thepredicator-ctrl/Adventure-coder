import Foundation

/// Routes tasks to the right model based on the agent's preference and user settings.
@MainActor
public final class ModelRouter {
    public static let shared = ModelRouter()

    private let ranker = ModelRanker()
    private let settings = SettingsStore.shared

    private init() {}

    public struct Resolution {
        public let model: AIModel
        public let provider: AIProvider
    }

    public func resolve(preference: ModelPreference) -> Resolution? {
        let all = CachedModelStore.shared.models
        guard let model = explicitUserOverride(for: preference) ?? ranker.pick(for: preference, from: all) else {
            // Fall back to the first available configured provider's first model
            if let firstModel = all.first {
                if let provider = ProviderRegistry.shared.provider(id: firstModel.providerId) {
                    return Resolution(model: firstModel, provider: provider)
                }
            }
            return nil
        }
        guard let provider = ProviderRegistry.shared.provider(id: model.providerId) else { return nil }
        return Resolution(model: model, provider: provider)
    }

    /// Returns the explicit user override for a given preference slot if set.
    private func explicitUserOverride(for preference: ModelPreference) -> AIModel? {
        let id: String?
        switch preference {
        case .fastFree: id = settings.fastModelId
        case .codingFree: id = settings.codingModelId
        case .planningFree: id = settings.planningModelId
        case .reviewFree: id = settings.reviewModelId
        case .strongestFree, .strongestAny: id = settings.primaryModelId
        }
        guard let modelId = id else { return nil }
        return CachedModelStore.shared.find(modelId: modelId)
    }

    /// Routes based on task description rather than agent preference. Used by the orchestrator
    /// when no specific agent is selected yet (e.g. user directly asks the main AI something).
    public func route(forTaskDescription description: String) -> ModelPreference {
        let lowered = description.lowercased()
        if lowered.contains("refactor") || lowered.contains("rewrite") || lowered.contains("migrate") {
            return .strongestFree
        }
        if lowered.contains("review") || lowered.contains("audit") || lowered.contains("security") {
            return .reviewFree
        }
        if lowered.contains("plan") || lowered.contains("architecture") || lowered.contains("design") {
            return .planningFree
        }
        if lowered.contains("fix") || lowered.contains("implement") || lowered.contains("code") || lowered.contains("build") {
            return .codingFree
        }
        if lowered.contains("search") || lowered.contains("look up") || lowered.contains("documentation") {
            return .fastFree
        }
        return .codingFree
    }

    /// Picks a model that supports vision, if any available, for tasks involving images.
    public func resolveVisionCapable() -> Resolution? {
        let all = CachedModelStore.shared.models
        let vision = all.first { $0.isFree && $0.supportsVision } ?? all.first { $0.supportsVision }
        guard let model = vision else { return nil }
        guard let provider = ProviderRegistry.shared.provider(id: model.providerId) else { return nil }
        return Resolution(model: model, provider: provider)
    }
}
