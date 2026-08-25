import XCTest
@testable import AdventureCoder

final class SnippetManagerTests: XCTestCase {
    func testDefaultSnippetsInstalled() {
        let manager = SnippetManager.shared
        XCTAssertFalse(manager.snippets.isEmpty, "Default snippets should be installed")
    }

    func testHasSwiftSnippets() {
        let swift = SnippetManager.shared.snippets(forLanguage: "swift")
        XCTAssertFalse(swift.isEmpty)
    }

    func testHasTypeScriptSnippets() {
        let ts = SnippetManager.shared.snippets(forLanguage: "typescript")
        XCTAssertFalse(ts.isEmpty)
    }

    func testHasPythonSnippets() {
        let py = SnippetManager.shared.snippets(forLanguage: "python")
        XCTAssertFalse(py.isEmpty)
    }

    func testCategoriesExist() {
        let categories = SnippetManager.shared.categories
        XCTAssertFalse(categories.isEmpty)
        XCTAssertTrue(categories.contains("SwiftUI"))
        XCTAssertTrue(categories.contains("React"))
    }

    func testSearchByTitle() {
        let results = SnippetManager.shared.search("View")
        XCTAssertFalse(results.isEmpty)
    }

    func testSearchByContent() {
        let results = SnippetManager.shared.search("useState")
        XCTAssertFalse(results.isEmpty)
    }

    func testAddAndRemove() {
        let manager = SnippetManager.shared
        let initialCount = manager.snippets.count
        let snippet = SnippetManager.Snippet(title: "Test Snippet", language: "swift", content: "let x = 1")
        manager.add(snippet)
        XCTAssertEqual(manager.snippets.count, initialCount + 1)
        manager.remove(snippet)
        XCTAssertEqual(manager.snippets.count, initialCount)
    }

    func testSnippetsInCategory() {
        let swiftUI = SnippetManager.shared.snippets(inCategory: "SwiftUI")
        XCTAssertFalse(swiftUI.isEmpty)
    }
}

final class SearchIndexerTests: XCTestCase {
    var tmp: URL!

    override func setUp() {
        super.setUp()
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("index-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmp!)
        super.tearDown()
    }

    func testIndexProject() {
        try? "func foo() {}".write(to: tmp.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)
        try? "class Bar {}".write(to: tmp.appendingPathComponent("b.swift"), atomically: true, encoding: .utf8)

        SearchIndexer.shared.indexProject(at: tmp.path)
        let stats = SearchIndexer.shared.stats
        XCTAssertGreaterThanOrEqual(stats.files, 2)
    }

    func testSearchFiles() {
        try? "let x = 1".write(to: tmp.appendingPathComponent("myfile.swift"), atomically: true, encoding: .utf8)
        SearchIndexer.shared.indexProject(at: tmp.path)
        let results = SearchIndexer.shared.searchFiles("myfile")
        XCTAssertFalse(results.isEmpty)
    }

    func testSearchSymbols() {
        try? "func myFunction() {}".write(to: tmp.appendingPathComponent("test.swift"), atomically: true, encoding: .utf8)
        SearchIndexer.shared.indexProject(at: tmp.path)
        let results = SearchIndexer.shared.searchSymbols("myFunction")
        XCTAssertFalse(results.isEmpty)
    }

    func testSearchContent() {
        try? "let greeting = \"hello world\"".write(to: tmp.appendingPathComponent("test.swift"), atomically: true, encoding: .utf8)
        SearchIndexer.shared.indexProject(at: tmp.path)
        let results = SearchIndexer.shared.searchContent("hello")
        XCTAssertFalse(results.isEmpty)
    }
}

final class BookmarkManagerTests: XCTestCase {
    func testToggleBookmark() {
        let manager = BookmarkManager.shared
        let initialCount = manager.bookmarks.count
        manager.toggle(filePath: "/test/file.swift", line: 42)
        XCTAssertEqual(manager.bookmarks.count, initialCount + 1)
        manager.toggle(filePath: "/test/file.swift", line: 42)
        XCTAssertEqual(manager.bookmarks.count, initialCount)
    }

    func testIsBookmarked() {
        let manager = BookmarkManager.shared
        manager.toggle(filePath: "/test/file2.swift", line: 10)
        XCTAssertTrue(manager.isBookmarked(filePath: "/test/file2.swift", line: 10))
        XCTAssertFalse(manager.isBookmarked(filePath: "/test/file2.swift", line: 11))
        manager.toggle(filePath: "/test/file2.swift", line: 10)
    }

    func testBookmarksForFile() {
        let manager = BookmarkManager.shared
        manager.toggle(filePath: "/test/file3.swift", line: 1)
        manager.toggle(filePath: "/test/file3.swift", line: 5)
        manager.toggle(filePath: "/test/file3.swift", line: 10)
        let bookmarks = manager.bookmarks(forFile: "/test/file3.swift")
        XCTAssertEqual(bookmarks.count, 3)
        // Clean up
        manager.bookmarks.filter { $0.filePath == "/test/file3.swift" }.forEach { manager.remove($0) }
    }
}

final class RecentFilesManagerTests: XCTestCase {
    func testRecordOpen() {
        let manager = RecentFilesManager.shared
        manager.clear()
        manager.recordOpen(path: "/test/file.swift", name: "file.swift", project: "TestApp")
        XCTAssertEqual(manager.recentFiles.count, 1)
        XCTAssertEqual(manager.recentFiles[0].name, "file.swift")
    }

    func testRecordOpenMovesToFront() {
        let manager = RecentFilesManager.shared
        manager.clear()
        manager.recordOpen(path: "/test/a.swift", name: "a.swift", project: "App")
        manager.recordOpen(path: "/test/b.swift", name: "b.swift", project: "App")
        manager.recordOpen(path: "/test/a.swift", name: "a.swift", project: "App")
        XCTAssertEqual(manager.recentFiles[0].name, "a.swift")
    }

    func testMaxFilesLimit() {
        let manager = RecentFilesManager.shared
        manager.clear()
        for i in 0..<25 {
            manager.recordOpen(path: "/test/file\(i).swift", name: "file\(i).swift", project: "App")
        }
        XCTAssertLessThanOrEqual(manager.recentFiles.count, 20)
    }
}

final class CodeCompletionEngineTests: XCTestCase {
    func testCompletionsForSwiftKeyword() {
        let results = CodeCompletionEngine.shared.completions(for: "fu", language: .swift)
        XCTAssertTrue(results.contains { $0.text == "func" })
    }

    func testCompletionsForPythonKeyword() {
        let results = CodeCompletionEngine.shared.completions(for: "de", language: .python)
        XCTAssertTrue(results.contains { $0.text == "def" })
    }

    func testCompletionsForTypeScriptKeyword() {
        let results = CodeCompletionEngine.shared.completions(for: "con", language: .typescript)
        XCTAssertTrue(results.contains { $0.text == "const" })
    }

    func testCompletionsForRustKeyword() {
        let results = CodeCompletionEngine.shared.completions(for: "fn", language: .rust)
        XCTAssertTrue(results.contains { $0.text == "fn" })
    }

    func testEmptyPartialReturnsEmpty() {
        let results = CodeCompletionEngine.shared.completions(for: "", language: .swift)
        XCTAssertTrue(results.isEmpty)
    }

    func testCompletionsIncludeFileSymbols() {
        let code = """
        func myFunction() {}
        struct MyStruct {}
        class MyClass {}
        """
        let results = CodeCompletionEngine.shared.completions(for: "my", language: .swift, fileContent: code)
        XCTAssertTrue(results.contains { $0.text == "myFunction" })
        XCTAssertTrue(results.contains { $0.text == "MyStruct" })
        XCTAssertTrue(results.contains { $0.text == "MyClass" })
    }
}
