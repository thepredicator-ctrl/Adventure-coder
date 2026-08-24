import XCTest
@testable import AdventureCoder

final class ToolTests: XCTestCase {
    func testAllToolsRegistered() {
        let defs = ToolRegistry.shared.definitions()
        let names = defs.map { $0.name }
        XCTAssertTrue(names.contains("read_file"))
        XCTAssertTrue(names.contains("write_file"))
        XCTAssertTrue(names.contains("edit_file"))
        XCTAssertTrue(names.contains("delete_file"))
        XCTAssertTrue(names.contains("list_files"))
        XCTAssertTrue(names.contains("search_files"))
        XCTAssertTrue(names.contains("search_project"))
        XCTAssertTrue(names.contains("web_search"))
        XCTAssertTrue(names.contains("fetch_url"))
        XCTAssertTrue(names.contains("search_documentation"))
        XCTAssertTrue(names.contains("search_images"))
        XCTAssertTrue(names.contains("git_status"))
        XCTAssertTrue(names.contains("git_diff"))
        XCTAssertTrue(names.contains("git_commit"))
        XCTAssertTrue(names.contains("git_push"))
        XCTAssertTrue(names.contains("git_pull"))
        XCTAssertTrue(names.contains("git_branches"))
        XCTAssertTrue(names.contains("git_checkout"))
        XCTAssertTrue(names.contains("git_history"))
        XCTAssertTrue(names.contains("github_search"))
        XCTAssertTrue(names.contains("github_repos"))
        XCTAssertTrue(names.contains("github_actions_status"))
        XCTAssertTrue(names.contains("run_command"))
        XCTAssertTrue(names.contains("build_project"))
        XCTAssertTrue(names.contains("run_tests"))
        XCTAssertTrue(names.contains("analyze_logs"))
        XCTAssertTrue(names.contains("generate_diff"))
        XCTAssertTrue(names.contains("preview_project"))
    }

    func testToolDefinitionsHaveRequiredFields() {
        for def in ToolRegistry.shared.definitions() {
            XCTAssertFalse(def.name.isEmpty)
            XCTAssertFalse(def.summary.isEmpty)
            XCTAssertFalse(def.description.isEmpty)
        }
    }

    func testFileToolsReadWrite() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("tool-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let project = Project(name: "test", rootPath: tmp.path, template: .empty)
        let context = ToolContext(project: project)

        let write = WriteFileTool(fs: FileSystem.shared)
        let result = try await write.invoke(parameters: ["path": "hello.txt", "content": "Hello, world"], context: context)
        XCTAssertTrue(result.success)

        let read = ReadFileTool(fs: FileSystem.shared)
        let readResult = try await read.invoke(parameters: ["path": "hello.txt"], context: context)
        XCTAssertTrue(readResult.success)
        XCTAssertEqual(readResult.output, "Hello, world")
    }

    func testListFiles() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("tool-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try "a".write(to: tmp.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "b".write(to: tmp.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let project = Project(name: "test", rootPath: tmp.path, template: .empty)
        let context = ToolContext(project: project)

        let tool = ListFilesTool(fs: FileSystem.shared)
        let result = try await tool.invoke(parameters: [:], context: context)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("a.txt"))
        XCTAssertTrue(result.output.contains("b.txt"))
    }

    func testGenerateDiff() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("tool-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let project = Project(name: "test", rootPath: tmp.path, template: .empty)
        let context = ToolContext(project: project)
        let tool = GenerateDiffTool()
        let result = try await tool.invoke(parameters: ["old_text": "line1\nline2", "new_text": "line1\nline2\nline3", "path": "test.txt"], context: context)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("+line3"))
    }
}
