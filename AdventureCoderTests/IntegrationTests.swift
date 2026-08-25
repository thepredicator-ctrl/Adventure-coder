import XCTest
@testable import AdventureCoder

/// Comprehensive integration tests that verify the full system works end-to-end.
final class IntegrationTests: XCTestCase {
    var tmp: URL!

    override func setUp() {
        super.setUp()
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("integration-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmp!)
        super.tearDown()
    }

    // MARK: - Full Project Lifecycle

    func testFullProjectLifecycle() throws {
        let store = ProjectStore.shared
        let project = try store.createProject(name: "integration-test-\(UUID().uuidString.prefix(8))", template: .swiftUI)
        defer { try? store.delete(project) }

        // Verify project was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.rootPath))

        // Verify template files exist
        let contentFile = (project.rootPath as NSString).appendingPathComponent("ContentView.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: contentFile))

        // Initialize git
        if case .success = GitService.shared.initialize(project) {}
        XCTAssertTrue(GitService.shared.isRepo(project))

        // Make a change
        let newFile = (project.rootPath as NSString).appendingPathComponent("NewFile.swift")
        try "let x = 42".write(to: URL(fileURLWithPath: newFile), atomically: true, encoding: .utf8)

        // Check git status shows the new file
        if case .success(let status) = GitService.shared.status(project: project) {
            XCTAssertTrue(status.contains("NewFile.swift"))
        }

        // Commit
        if case .success(let sha) = GitService.shared.commit(project: project, message: "Add new file") {
            XCTAssertFalse(sha.isEmpty)
        }

        // Check history
        if case .success(let history) = GitService.shared.history(project: project, limit: 10) {
            XCTAssertEqual(history.count, 1)
            XCTAssertEqual(history[0].message, "Add new file")
        }
    }

    // MARK: - File Operations

    func testFileOperationsWorkflow() throws {
        let project = Project(name: "file-test", rootPath: tmp.path, template: .empty)
        let fs = FileSystem.shared

        // Create a file
        try fs.write(fs.join(tmp.path, "test.txt"), content: "hello world")
        XCTAssertTrue(fs.exists(fs.join(tmp.path, "test.txt")))

        // Read it back
        let content = try fs.read(fs.join(tmp.path, "test.txt"))
        XCTAssertEqual(content, "hello world")

        // Rename
        let newPath = try fs.rename(fs.join(tmp.path, "test.txt"), to: "renamed.txt")
        XCTAssertTrue(fs.exists(newPath))
        XCTAssertFalse(fs.exists(fs.join(tmp.path, "test.txt")))

        // Duplicate
        let copyPath = try fs.duplicate(newPath)
        XCTAssertTrue(fs.exists(copyPath))

        // Delete
        try fs.delete(newPath)
        XCTAssertFalse(fs.exists(newPath))
    }

    // MARK: - Search

    func testSearchWorkflow() throws {
        let fs = FileSystem.shared
        try fs.write(fs.join(tmp.path, "a.swift"), content: "func foo() { /* TODO */ }")
        try fs.write(fs.join(tmp.path, "b.swift"), content: "func bar() { print(\"hello\") }")
        try fs.write(fs.join(tmp.path, "c.swift"), content: "// TODO: implement")

        let hits = try fs.search(query: "TODO", in: tmp.path)
        XCTAssertGreaterThanOrEqual(hits.count, 2)
    }

    // MARK: - Git Operations

    func testGitWorkflow() throws {
        let project = Project(name: "git-test", rootPath: tmp.path, template: .empty)

        // Init
        if case .success = GitService.shared.initialize(project) {}
        XCTAssertTrue(GitService.shared.isRepo(project))

        // Add files
        try "file 1".write(to: tmp.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        try "file 2".write(to: tmp.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)

        // Status
        if case .success(let status) = GitService.shared.status(project: project) {
            XCTAssertTrue(status.contains("file1.txt"))
        }

        // Commit
        if case .success = GitService.shared.commit(project: project, message: "initial commit") {}

        // History
        if case .success(let history) = GitService.shared.history(project: project, limit: 10) {
            XCTAssertEqual(history.count, 1)
        }

        // Branches
        if case .success(let branches) = GitService.shared.branches(project: project) {
            XCTAssertTrue(branches.contains { $0.name == "main" })
        }
    }

    // MARK: - Terminal

    func testTerminalCommands() {
        let engine = TerminalEngine.shared

        // Test pwd
        let pwdResult = engine.run(command: "pwd", in: tmp.path)
        XCTAssertEqual(pwdResult.exitCode, 0)
        XCTAssertEqual(pwdResult.output, tmp.path)

        // Test echo
        let echoResult = engine.run(command: "echo hello", in: tmp.path)
        XCTAssertEqual(echoResult.exitCode, 0)
        XCTAssertEqual(echoResult.output, "hello")

        // Test date
        let dateResult = engine.run(command: "date", in: tmp.path)
        XCTAssertEqual(dateResult.exitCode, 0)
        XCTAssertFalse(dateResult.output.isEmpty)
    }

    // MARK: - Secret Detection

    func testSecretDetectionWorkflow() {
        let code = """
        let apiKey = "sk-1234567890abcdefghijklmnop"
        let token = "ghp_1234567890abcdefghijklmnopqrstuv"
        """
        let hits = SecretDetector.scan(code)
        XCTAssertGreaterThanOrEqual(hits.count, 2)
    }

    // MARK: - Diff Generation

    func testDiffWorkflow() {
        let old = "line1\nline2\nline3"
        let new = "line1\nmodified\nline3\nline4"
        let diff = DiffAlgorithm.unifiedDiff(old: old, new: new, path: "test.txt")
        XCTAssertTrue(diff.contains("-line2"))
        XCTAssertTrue(diff.contains("+modified"))
        XCTAssertTrue(diff.contains("+line4"))
    }

    // MARK: - Model Ranking

    func testModelRankingWorkflow() {
        let settings = SettingsStore()
        settings.freeModelsOnly = true
        settings.allowPaidModels = false

        let models = [
            AIModel(providerId: "p", modelId: "free-1", isFree: true, codingScore: 0.9),
            AIModel(providerId: "p", modelId: "paid-1", isFree: false, codingScore: 0.95),
            AIModel(providerId: "p", modelId: "free-2", isFree: true, codingScore: 0.7),
        ]
        let ranker = ModelRanker(settings: settings)
        let available = ranker.availableModels(from: models)
        XCTAssertEqual(available.count, 2)
        XCTAssertTrue(available.allSatisfy { $0.isFree })

        let best = ranker.pick(for: .codingFree, from: models)
        XCTAssertEqual(best?.modelId, "free-1")
    }

    // MARK: - Tool System

    func testToolSystemWorkflow() async throws {
        let project = Project(name: "tool-test", rootPath: tmp.path, template: .empty)
        let context = ToolContext(project: project)

        // Write a file
        let writeTool = WriteFileTool(fs: FileSystem.shared)
        let writeResult = try await writeTool.invoke(parameters: ["path": "test.swift", "content": "let x = 1"], context: context)
        XCTAssertTrue(writeResult.success)

        // Read it back
        let readTool = ReadFileTool(fs: FileSystem.shared)
        let readResult = try await readTool.invoke(parameters: ["path": "test.swift"], context: context)
        XCTAssertTrue(readResult.success)
        XCTAssertEqual(readResult.output, "let x = 1")

        // List files
        let listTool = ListFilesTool(fs: FileSystem.shared)
        let listResult = try await listTool.invoke(parameters: [:], context: context)
        XCTAssertTrue(listResult.success)
        XCTAssertTrue(listResult.output.contains("test.swift"))

        // Search
        let searchTool = SearchFilesTool(fs: FileSystem.shared)
        let searchResult = try await searchTool.invoke(parameters: ["query": "let x"], context: context)
        XCTAssertTrue(searchResult.success)
        XCTAssertTrue(searchResult.output.contains("test.swift"))
    }

    // MARK: - Template Installation

    func testTemplateInstallationWorkflow() throws {
        for template in ProjectTemplate.allCases {
            let templateDir = tmp.appendingPathComponent(template.rawValue, isDirectory: true)
            try FileManager.default.createDirectory(at: templateDir, withIntermediateDirectories: true)
            try TemplateInstaller.install(template: template, at: templateDir, name: "TestApp")
            XCTAssertTrue(FileManager.default.fileExists(atPath: (templateDir as NSString).appendingPathComponent(".gitignore").path))
        }
    }

    // MARK: - Build Service

    func testBuildServiceWorkflow() {
        let project = Project(name: "build-test", rootPath: tmp.path, template: .empty)
        let result = BuildService.shared.build(project: project, configuration: "debug")
        switch result {
        case .success:
            break  // Empty template always succeeds
        case .failure:
            XCTFail("Build should succeed for empty template")
        }
    }

    // MARK: - Log Analysis

    func testLogAnalysisWorkflow() {
        let logs = """
        Building target AdventureCoder
        Compiling main.swift...
        error: cannot find type 'Foo' in scope
        warning: 'bar' is deprecated
        note: declared here
        Build failed with 1 error and 1 warning.
        """
        let analysis = LogAnalyzer.analyze(logs)
        let errors = analysis["errors"] as? [[String: Any]] ?? []
        let warnings = analysis["warnings"] as? [[String: Any]] ?? []
        XCTAssertGreaterThanOrEqual(errors.count, 1)
        XCTAssertGreaterThanOrEqual(warnings.count, 1)
    }

    // MARK: - Agent Registry

    func testAgentRegistryCompleteness() {
        let registry = AgentRegistry.shared
        XCTAssertGreaterThanOrEqual(registry.count, 130)

        // Verify all categories have agents
        for category in AgentCategory.allCases {
            let agents = registry.agents(in: category)
            XCTAssertGreaterThan(agents.count, 0, "Category \(category.displayName) has no agents")
        }
    }

    // MARK: - Tool Registry

    func testToolRegistryCompleteness() {
        let registry = ToolRegistry.shared
        XCTAssertGreaterThanOrEqual(registry.tools.count, 50)

        // Verify all tools have definitions
        for tool in registry.tools {
            XCTAssertFalse(tool.definition.name.isEmpty)
            XCTAssertFalse(tool.definition.summary.isEmpty)
        }
    }

    // MARK: - Code Analysis

    func testCodeAnalysisWorkflow() {
        let code = """
        func complexFunction(a: Int, b: Int) -> Int {
            if a > 0 {
                if b > 0 {
                    if a > b {
                        for i in 0..<a {
                            if i % 2 == 0 {
                                print(i)
                            }
                        }
                    }
                }
            }
            return a + b
        }
        """
        let metrics = CodeComplexityAnalyzer.shared.analyzeSwift(content: code, fileName: "test.swift")
        XCTAssertGreaterThan(metrics.functions.count, 0)
        XCTAssertGreaterThan(metrics.functions[0].cyclomaticComplexity, 1)

        let hotspots = CodeComplexityAnalyzer.shared.findHotspots(in: [metrics])
        XCTAssertGreaterThan(hotspots.count, 0)
    }

    // MARK: - Linter

    func testLinterWorkflow() {
        let code = "let x = 1   \n"  // trailing whitespace
        let findings = CodeLinter.shared.lintSwift(code, fileName: "test.swift")
        XCTAssertTrue(findings.contains { $0.rule == "trailing_whitespace" })
    }

    // MARK: - Formatter

    func testFormatterWorkflow() {
        let code = "func foo(){print(\"hi\")}"
        let formatted = CodeFormatter.shared.formatSwift(code)
        XCTAssertTrue(formatted.hasSuffix("\n"))
        XCTAssertTrue(formatted.contains("    "))
    }

    // MARK: - Symbol Parser

    func testSymbolParserWorkflow() {
        let code = """
        class MyClass {
            func myMethod() {}
            var myProperty: Int = 0
        }
        struct MyStruct {}
        enum MyEnum {
            case first
        }
        """
        let symbols = SymbolParser.parse(content: code, fileName: "test.swift")
        XCTAssertTrue(symbols.contains { $0.name == "MyClass" && $0.kind == .class })
        XCTAssertTrue(symbols.contains { $0.name == "myMethod" && $0.kind == .func })
        XCTAssertTrue(symbols.contains { $0.name == "myProperty" && $0.kind == .var_ })
        XCTAssertTrue(symbols.contains { $0.name == "MyStruct" && $0.kind == .struct_ })
        XCTAssertTrue(symbols.contains { $0.name == "MyEnum" && $0.kind == .enum_ })
    }
}

/// Performance tests to ensure the app handles large projects efficiently.
final class PerformanceTests: XCTestCase {
    func testLargeFileParsing() {
        let code = (0..<1000).map { "func function\($0)() {}" }.joined(separator: "\n")
        let start = Date()
        let metrics = CodeComplexityAnalyzer.shared.analyzeSwift(content: code, fileName: "large.swift")
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(metrics.functions.count, 1000)
        XCTAssertLessThan(elapsed, 5.0, "Parsing 1000 functions should take < 5 seconds")
    }

    func testLargeFileSymbolParsing() {
        let code = (0..<1000).map { "func function\($0)() {}" }.joined(separator: "\n")
        let start = Date()
        let symbols = SymbolParser.parse(content: code, fileName: "large.swift")
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(symbols.count, 1000)
        XCTAssertLessThan(elapsed, 2.0)
    }

    func testLargeFileDiff() {
        let old = (0..<1000).map { "line \($0)" }.joined(separator: "\n")
        let new = (0..<1000).map { "line \($0)" }.joined(separator: "\n") + "\nnew line"
        let start = Date()
        let diff = DiffAlgorithm.unifiedDiff(old: old, new: new, path: "large.txt")
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(diff.contains("+new line"))
        XCTAssertLessThan(elapsed, 5.0)
    }

    func testLargeFileLinting() {
        let code = (0..<500).map { "let x\($0) = \($0)" }.joined(separator: "\n")
        let start = Date()
        let findings = CodeLinter.shared.lintSwift(code, fileName: "large.swift")
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(findings.count, 0)
        XCTAssertLessThan(elapsed, 5.0)
    }

    func testManyAgentsLookup() {
        let registry = AgentRegistry.shared
        let start = Date()
        for _ in 0..<1000 {
            _ = registry.find("coding.swift")
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 1.0)
    }

    func testManyToolsLookup() {
        let registry = ToolRegistry.shared
        let start = Date()
        for _ in 0..<1000 {
            _ = registry.find("read_file")
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 1.0)
    }
}

/// Stress tests for edge cases.
final class StressTests: XCTestCase {
    func testEmptyFile() {
        let metrics = CodeComplexityAnalyzer.shared.analyzeSwift(content: "", fileName: "empty.swift")
        XCTAssertEqual(metrics.totalLines, 1)
        XCTAssertEqual(metrics.functions.count, 0)
    }

    func testSingleLineFile() {
        let metrics = CodeComplexityAnalyzer.shared.analyzeSwift(content: "let x = 1", fileName: "single.swift")
        XCTAssertEqual(metrics.totalLines, 1)
    }

    func testVeryDeepNesting() {
        let code = """
        func deep() {
            if true {
                if true {
                    if true {
                        if true {
                            if true {
                                if true {
                                    if true {
                                        print("deep")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        """
        let metrics = CodeComplexityAnalyzer.shared.analyzeSwift(content: code, fileName: "deep.swift")
        XCTAssertGreaterThan(metrics.functions[0].nestingDepth, 5)
    }

    func testUnicodeContent() {
        let code = "let greeting = \"你好世界\""
        let symbols = SymbolParser.parse(content: code, fileName: "unicode.swift")
        XCTAssertTrue(symbols.contains { $0.name == "greeting" })
    }

    func testBinaryLikeContent() {
        let code = "let data = Data([0x00, 0xFF, 0xFE])"
        let metrics = CodeComplexityAnalyzer.shared.analyzeSwift(content: code, fileName: "binary.swift")
        XCTAssertGreaterThanOrEqual(metrics.totalLines, 1)
    }
}
