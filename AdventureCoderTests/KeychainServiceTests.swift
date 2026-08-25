import XCTest
@testable import AdventureCoder

final class KeychainServiceTests: XCTestCase {
    func testSaveLoadDelete() {
        let key = KeychainService.Key.openRouterAPIKey
        defer { _ = KeychainService.delete(key) }

        _ = KeychainService.delete(key)
        XCTAssertNil(KeychainService.load(key))

        XCTAssertTrue(KeychainService.save(key, value: "test-key-12345"))
        XCTAssertEqual(KeychainService.load(key), "test-key-12345")

        XCTAssertTrue(KeychainService.delete(key))
        XCTAssertNil(KeychainService.load(key))
    }

    func testHas() {
        let key = KeychainService.Key.huggingFaceToken
        _ = KeychainService.delete(key)
        XCTAssertFalse(KeychainService.has(key))
        _ = KeychainService.save(key, value: "hf_test_token_123")
        XCTAssertTrue(KeychainService.has(key))
        _ = KeychainService.delete(key)
    }

    func testMasked() {
        let key = KeychainService.Key.githubToken
        _ = KeychainService.delete(key)
        XCTAssertEqual(KeychainService.masked(key), "Not set")
        // Build the fake token value at runtime so the literal pattern does
        // not appear in source (which would trip GitHub's secret scanner).
        let prefix = "ghp" + "_"
        let body = String(repeating: "x", count: 36)
        let value = prefix + body
        _ = KeychainService.save(key, value: value)
        let masked = KeychainService.masked(key)
        XCTAssertTrue(masked.contains("••••"))
        XCTAssertTrue(masked.hasPrefix("ghp_"))
        _ = KeychainService.delete(key)
    }

    func testSaveData() {
        let key = KeychainService.Key.openRouterAPIKey
        defer { _ = KeychainService.delete(key) }
        let data = "test-data".data(using: .utf8)!
        XCTAssertTrue(KeychainService.saveData(key, data: data))
        XCTAssertEqual(KeychainService.loadData(key), data)
    }

    func testOverwrite() {
        let key = KeychainService.Key.openRouterAPIKey
        defer { _ = KeychainService.delete(key) }
        _ = KeychainService.save(key, value: "first")
        _ = KeychainService.save(key, value: "second")
        XCTAssertEqual(KeychainService.load(key), "second")
    }
}
