import XCTest
@testable import AdventureCoder

final class SwiftSyntaxCheckerTests: XCTestCase {
    func testBalancedBracesPass() {
        let code = """
        func foo() {
            print("hi")
        }
        """
        let diags = SwiftSyntaxChecker.check(content: code, path: "test.swift")
        XCTAssertFalse(diags.contains { $0.severity == .error })
    }

    func testUnbalancedBracesFail() {
        let code = """
        func foo() {
            print("hi")
        """
        let diags = SwiftSyntaxChecker.check(content: code, path: "test.swift")
        XCTAssertTrue(diags.contains { $0.severity == .error && $0.message.contains("Unbalanced braces") })
    }

    func testUnbalancedParensFail() {
        let code = """
        func foo() {
            print("hi"
        }
        """
        let diags = SwiftSyntaxChecker.check(content: code, path: "test.swift")
        XCTAssertTrue(diags.contains { $0.severity == .error && $0.message.contains("Unbalanced") })
    }

    func testIgnoresBracesInStrings() {
        let code = """
        let s = "{not a brace}"
        """
        let diags = SwiftSyntaxChecker.check(content: code, path: "test.swift")
        XCTAssertFalse(diags.contains { $0.severity == .error })
    }

    func testIgnoresBracesInComments() {
        let code = """
        // comment with { brace
        let x = 1
        """
        let diags = SwiftSyntaxChecker.check(content: code, path: "test.swift")
        XCTAssertFalse(diags.contains { $0.severity == .error })
    }
}
