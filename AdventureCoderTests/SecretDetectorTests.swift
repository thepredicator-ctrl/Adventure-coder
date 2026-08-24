import XCTest
@testable import AdventureCoder

final class SecretDetectorTests: XCTestCase {
    func testDetectsGitHubPAT() {
        // Construct the test string at runtime so the literal token pattern
        // does not appear in source (GitHub secret scanning would otherwise
        // flag any string matching the github_pat_* shape).
        let prefix = "github" + "_" + "pat" + "_"
        let body = String(repeating: "X", count: 82)
        let text = "token = " + prefix + body
        let hits = SecretDetector.scan(text)
        XCTAssertFalse(hits.isEmpty)
        XCTAssertTrue(hits.contains { $0.kind == .githubToken })
    }

    func testDetectsOpenAIKey() {
        // Build at runtime to avoid tripping secret scanners on the literal.
        let prefix = "sk" + "-"
        let body = String(repeating: "a", count: 30)
        let text = "OPENAI_API_KEY=" + prefix + body
        let hits = SecretDetector.scan(text)
        XCTAssertTrue(hits.contains { $0.kind == .openAIKey })
    }

    func testDetectsAWSKey() {
        let text = "aws_key = AKIAIOSFODNN7EXAMPLE"
        let hits = SecretDetector.scan(text)
        XCTAssertTrue(hits.contains { $0.kind == .awsAccessKey })
    }

    func testDetectsPrivateKey() {
        let text = """
        -----BEGIN RSA PRIVATE KEY-----
        MIIEpAIBAAKCAQEA...
        -----END RSA PRIVATE KEY-----
        """
        let hits = SecretDetector.scan(text)
        XCTAssertTrue(hits.contains { $0.kind == .privateKey })
    }

    func testDetectsHardcodedPassword() {
        let text = "password = \"supersecret123\""
        let hits = SecretDetector.scan(text)
        XCTAssertTrue(hits.contains { $0.kind == .genericPassword })
    }

    func testNoFalsePositive() {
        let text = "func calculateTotal() -> Int { return 42 }"
        let hits = SecretDetector.scan(text)
        XCTAssertTrue(hits.isEmpty)
    }
}
