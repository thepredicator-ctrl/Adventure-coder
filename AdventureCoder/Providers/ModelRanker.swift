import Foundation

/// Ranks and filters discovered models according to the user's free-only / paid-allowed preferences.
public struct ModelRanker {
    public let settings: SettingsStore

    public init(settings: SettingsStore = .shared) {
        self.settings = settings
    }

    /// Returns models the user is allowed to see, ranked by composite score.
    public func availableModels(from all: [AIModel]) -> [AIModel] {
        let filtered: [AIModel]
        if settings.allowPaidModels {
            filtered = all
        } else {
            filtered = all.filter { $0.isFree }
        }
        return filtered.sorted { $0.compositeScore > $1.compositeScore }
    }

    /// Picks the single best model for a given preference.
    public func pick(for preference: ModelPreference, from all: [AIModel]) -> AIModel? {
        let pool = availableModels(from: all)
        if pool.isEmpty { return nil }

        switch preference {
        case .fastFree:
            // Prefer small context (fast) free models with reasonable coding
            return pool
                .filter { $0.contextLength <= 32768 }
                .sorted { $0.contextLength < $1.contextLength }
                .first
                ?? pool.first
        case .codingFree:
            return pool
                .filter { $0.codingScore >= 0.7 }
                .sorted { $0.codingScore > $1.codingScore }
                .first
                ?? pool.first
        case .planningFree:
            return pool
                .filter { $0.contextLength >= 16384 }
                .sorted { $0.compositeScore > $1.compositeScore }
                .first
                ?? pool.first
        case .reviewFree:
            return pool
                .sorted { $0.reliabilityScore > $1.reliabilityScore }
                .first
        case .strongestFree:
            return pool.first
        case .strongestAny:
            if settings.allowPaidModels {
                return all.sorted { $0.compositeScore > $1.compositeScore }.first
            }
            return pool.first
        }
    }

    /// Convenience: rank free models only and return top-N.
    public func topFreeModels(from all: [AIModel], limit: Int = 10) -> [AIModel] {
        all.filter { $0.isFree }
           .sorted { $0.compositeScore > $1.compositeScore }
           .prefix(limit)
           .map { $0 }
    }

    /// Suggest a default primary model: prefer coding-strong free model.
    public func suggestDefault(from all: [AIModel]) -> AIModel? {
        pick(for: .codingFree, from: all)
    }
}
