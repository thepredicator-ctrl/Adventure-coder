import XCTest
@testable import AdventureCoder

final class ModelRankerTests: XCTestCase {
    func testFreeOnlyFilter() {
        let settings = SettingsStore()
        // Force free-only
        settings.freeModelsOnly = true
        settings.allowPaidModels = false

        let models = [
            AIModel(providerId: "p", modelId: "free-1", isFree: true, codingScore: 0.6),
            AIModel(providerId: "p", modelId: "paid-1", isFree: false, codingScore: 0.95, promptPricePer1K: 0.01, completionPricePer1K: 0.02),
            AIModel(providerId: "p", modelId: "free-2", isFree: true, codingScore: 0.9),
        ]
        let ranker = ModelRanker(settings: settings)
        let available = ranker.availableModels(from: models)
        XCTAssertEqual(available.count, 2)
        XCTAssertTrue(available.allSatisfy { $0.isFree })
    }

    func testPaidAllowed() {
        let settings = SettingsStore()
        settings.freeModelsOnly = false
        settings.allowPaidModels = true

        let models = [
            AIModel(providerId: "p", modelId: "free-1", isFree: true, codingScore: 0.6),
            AIModel(providerId: "p", modelId: "paid-1", isFree: false, codingScore: 0.95, promptPricePer1K: 0.01, completionPricePer1K: 0.02),
        ]
        let ranker = ModelRanker(settings: settings)
        let available = ranker.availableModels(from: models)
        XCTAssertEqual(available.count, 2)
    }

    func testPickCodingFree() {
        let settings = SettingsStore()
        settings.freeModelsOnly = true
        settings.allowPaidModels = false
        let models = [
            AIModel(providerId: "p", modelId: "free-small", isFree: true, codingScore: 0.6, contextLength: 8000),
            AIModel(providerId: "p", modelId: "free-coder", isFree: true, codingScore: 0.92, contextLength: 32000),
        ]
        let ranker = ModelRanker(settings: settings)
        let picked = ranker.pick(for: .codingFree, from: models)
        XCTAssertEqual(picked?.modelId, "free-coder")
    }

    func testPickFastFree() {
        let settings = SettingsStore()
        settings.freeModelsOnly = true
        settings.allowPaidModels = false
        let models = [
            AIModel(providerId: "p", modelId: "big", isFree: true, contextLength: 131072, codingScore: 0.8),
            AIModel(providerId: "p", modelId: "small", isFree: true, contextLength: 4096, codingScore: 0.6),
        ]
        let ranker = ModelRanker(settings: settings)
        let picked = ranker.pick(for: .fastFree, from: models)
        XCTAssertNotNil(picked)
        XCTAssertEqual(picked?.modelId, "small")
    }

    func testCompositeScore() {
        let m1 = AIModel(providerId: "p", modelId: "a", isFree: true, contextLength: 32768, codingScore: 0.9, toolUseScore: 0.8, reliabilityScore: 0.85)
        let m2 = AIModel(providerId: "p", modelId: "b", isFree: true, contextLength: 8192, codingScore: 0.6, toolUseScore: 0.4, reliabilityScore: 0.7)
        XCTAssertGreaterThan(m1.compositeScore, m2.compositeScore)
    }
}
