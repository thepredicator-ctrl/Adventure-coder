import XCTest
@testable import AdventureCoder

final class LogAnalyzerTests: XCTestCase {
    func testDetectsErrors() {
        let logs = """
        Build started
        Compiling main.swift
        error: cannot find type 'Foo' in scope
        warning: unused variable 'bar'
        Build failed
        """
        let result = LogAnalyzer.analyze(logs)
        let errors = result["errors"] as? [[String: Any]] ?? []
        XCTAssertGreaterThanOrEqual(errors.count, 2)
    }

    func testDetectsNoSuchModule() {
        let logs = "error: no such module 'Combine'"
        let result = LogAnalyzer.analyze(logs)
        let hints = result["hints"] as? [String] ?? []
        XCTAssertTrue(hints.contains { $0.contains("package dependency") })
    }

    func testEmptyLogs() {
        let result = LogAnalyzer.analyze("")
        let summary = result["summary"] as? String ?? ""
        XCTAssertTrue(summary.contains("0 errors"))
    }
}
