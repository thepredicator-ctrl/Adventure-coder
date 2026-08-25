import XCTest
@testable import AdventureCoder

final class AdvancedToolsTests: XCTestCase {
    func testAllAdvancedToolsRegistered() {
        let names = ToolRegistry.shared.definitions().map { $0.name }
        XCTAssertTrue(names.contains("analyze_complexity"))
        XCTAssertTrue(names.contains("detect_duplicates"))
        XCTAssertTrue(names.contains("detect_dead_code"))
        XCTAssertTrue(names.contains("calculate_metrics"))
        XCTAssertTrue(names.contains("format_code"))
        XCTAssertTrue(names.contains("lint_code"))
        XCTAssertTrue(names.contains("generate_tests"))
        XCTAssertTrue(names.contains("security_scan"))
        XCTAssertTrue(names.contains("dependency_scan"))
        XCTAssertTrue(names.contains("generate_changelog"))
        XCTAssertTrue(names.contains("generate_docs"))
    }

    func testAdvancedToolDefinitionsHaveRequiredFields() {
        let advancedDefs = ToolRegistry.shared.definitions().filter {
            ["analyze_complexity","detect_duplicates","detect_dead_code","calculate_metrics","format_code","lint_code","generate_tests","security_scan","dependency_scan","generate_changelog","generate_docs"].contains($0.name)
        }
        XCTAssertEqual(advancedDefs.count, 11)
        for def in advancedDefs {
            XCTAssertFalse(def.name.isEmpty)
            XCTAssertFalse(def.summary.isEmpty)
            XCTAssertFalse(def.description.isEmpty)
        }
    }

    func testAnalyzeComplexityTool() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("tool-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let project = Project(name: "test", rootPath: tmp.path, template: .empty)
        let context = ToolContext(project: project)

        let testFile = tmp.appendingPathComponent("test.swift")
        try "func foo() { print(\"hi\") }".write(to: testFile, atomically: true, encoding: .utf8)

        let tool = AnalyzeComplexityTool()
        let result = try await tool.invoke(parameters: ["path": "test.swift"], context: context)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Maintainability Index"))
    }

    func testLintCodeTool() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("tool-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let project = Project(name: "test", rootPath: tmp.path, template: .empty)
        let context = ToolContext(project: project)

        let testFile = tmp.appendingPathComponent("test.swift")
        let longLine = String(repeating: "x", count: 130)
        try "\(longLine)\n".write(to: testFile, atomically: true, encoding: .utf8)

        let tool = LintCodeTool()
        let result = try await tool.invoke(parameters: ["path": "test.swift"], context: context)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("line_length"))
    }

    func testFormatCodeTool() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("tool-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let project = Project(name: "test", rootPath: tmp.path, template: .empty)
        let context = ToolContext(project: project)

        let testFile = tmp.appendingPathComponent("test.swift")
        try "func foo(){print(\"hi\")}".write(to: testFile, atomically: true, encoding: .utf8)

        let tool = FormatCodeTool()
        let result = try await tool.invoke(parameters: ["path": "test.swift"], context: context)
        XCTAssertTrue(result.success)
    }

    func testSecurityScanTool() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("tool-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let project = Project(name: "test", rootPath: tmp.path, template: .empty)
        let context = ToolContext(project: project)

        let testFile = tmp.appendingPathComponent("test.swift")
        try "let url = \"http://example.com\"".write(to: testFile, atomically: true, encoding: .utf8)

        let tool = SecurityScanTool()
        let result = try await tool.invoke(parameters: ["path": "test.swift"], context: context)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("INSECURE"))
    }

    func testGenerateTestsTool() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("tool-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let project = Project(name: "test", rootPath: tmp.path, template: .empty)
        let context = ToolContext(project: project)

        let testFile = tmp.appendingPathComponent("MyClass.swift")
        try "func foo() {}\nfunc bar() {}".write(to: testFile, atomically: true, encoding: .utf8)

        let tool = GenerateTestsTool()
        let result = try await tool.invoke(parameters: ["path": "MyClass.swift"], context: context)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("test cases"))
    }
}
