import XCTest
@testable import AdventureCoder

final class ProviderTests: XCTestCase {
    func testProviderRegistryHasOpenRouter() {
        XCTAssertNotNil(ProviderRegistry.shared.provider(id: "openrouter"))
    }

    func testProviderRegistryHasHuggingFace() {
        XCTAssertNotNil(ProviderRegistry.shared.provider(id: "huggingface"))
    }

    func testProvidersHaveCorrectKeychainKeys() {
        XCTAssertEqual(ProviderRegistry.shared.provider(id: "openrouter")?.keychainKey, .openRouterAPIKey)
        XCTAssertEqual(ProviderRegistry.shared.provider(id: "huggingface")?.keychainKey, .huggingFaceToken)
    }

    func testFallbackModelsExist() {
        XCTAssertFalse(FallbackModels.list.isEmpty)
        XCTAssertTrue(FallbackModels.list.allSatisfy { $0.isFree })
    }

    func testFallbackModelsHaveCodingScores() {
        for model in FallbackModels.list {
            XCTAssertGreaterThan(model.codingScore, 0)
            XCTAssertLessThanOrEqual(model.codingScore, 1)
        }
    }

    func testScoreEstimator() {
        XCTAssertGreaterThan(ScoreEstimator.codingScore(for: "deepseek/deepseek-chat"), 0.8)
        XCTAssertGreaterThan(ScoreEstimator.codingScore(for: "qwen/qwen-2.5-coder-32b-instruct"), 0.8)
        XCTAssertGreaterThan(ScoreEstimator.reliabilityScore(for: "meta-llama/llama-3.3-70b"), 0.8)
    }

    func testOpenRouterProviderNotConfiguredWithoutKey() {
        _ = KeychainService.delete(.openRouterAPIKey)
        XCTAssertFalse(OpenRouterProvider().isConfigured())
    }

    func testHuggingFaceProviderNotConfiguredWithoutToken() {
        _ = KeychainService.delete(.huggingFaceToken)
        XCTAssertFalse(HuggingFaceProvider().isConfigured())
    }
}
