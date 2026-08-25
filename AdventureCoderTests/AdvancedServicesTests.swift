import XCTest
@testable import AdventureCoder

final class FileWatcherTests: XCTestCase {
    var tmp: URL!

    override func setUp() {
        super.setUp()
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("watcher-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDown() {
        FileWatcher.shared.stopWatching()
        try? FileManager.default.removeItem(at: tmp!)
        super.tearDown()
    }

    func testStartWatching() {
        FileWatcher.shared.startWatching(tmp.path)
        XCTAssertTrue(FileWatcher.shared.isWatching)
        FileWatcher.shared.stopWatching()
        XCTAssertFalse(FileWatcher.shared.isWatching)
    }

    func testClearChanges() {
        FileWatcher.shared.changedFiles.insert("/test/file.swift")
        FileWatcher.shared.clearChanges()
        XCTAssertTrue(FileWatcher.shared.changedFiles.isEmpty)
    }
}

final class EditorSessionManagerTests: XCTestCase {
    func testCreateSession() {
        let manager = EditorSessionManager.shared
        let session = manager.session(for: "/test/file.swift")
        XCTAssertEqual(session.filePath, "/test/file.swift")
    }

    func testUpdateContent() {
        let manager = EditorSessionManager.shared
        let path = "/test/update.swift"
        manager.updateSession(for: path, content: "let x = 1")
        let session = manager.session(for: path)
        XCTAssertEqual(session.content, "let x = 1")
        XCTAssertTrue(session.isDirty)
    }

    func testUndoRedo() {
        let manager = EditorSessionManager.shared
        let path = "/test/undo.swift"
        manager.updateSession(for: path, content: "original")
        manager.updateSession(for: path, content: "modified")
        manager.undo(path: path)
        XCTAssertEqual(manager.session(for: path).content, "original")
        manager.redo(path: path)
        XCTAssertEqual(manager.session(for: path).content, "modified")
    }

    func testMarkSaved() {
        let manager = EditorSessionManager.shared
        let path = "/test/saved.swift"
        manager.updateSession(for: path, content: "saved content")
        manager.markSaved(path: path)
        XCTAssertFalse(manager.isDirty(path: path))
    }

    func testRemoveSession() {
        let manager = EditorSessionManager.shared
        let path = "/test/remove.swift"
        _ = manager.session(for: path)
        manager.removeSession(path: path)
        // Creating a new session should give empty content
        let newSession = manager.session(for: path)
        XCTAssertEqual(newSession.content, "")
    }
}

final class ProjectSettingsManagerTests: XCTestCase {
    func testGetDefaultSettings() {
        let id = UUID()
        let settings = ProjectSettingsManager.shared.settings(for: id)
        XCTAssertEqual(settings.projectId, id)
        XCTAssertFalse(settings.autoFormatOnSave)
    }

    func testSetBuildCommand() {
        let id = UUID()
        ProjectSettingsManager.shared.setBuildCommand("npm run build", for: id)
        let settings = ProjectSettingsManager.shared.settings(for: id)
        XCTAssertEqual(settings.customBuildCommand, "npm run build")
    }

    func testSetTestCommand() {
        let id = UUID()
        ProjectSettingsManager.shared.setTestCommand("npm test", for: id)
        let settings = ProjectSettingsManager.shared.settings(for: id)
        XCTAssertEqual(settings.customTestCommand, "npm test")
    }

    func testExcludePath() {
        let id = UUID()
        ProjectSettingsManager.shared.excludePath("node_modules", for: id)
        let settings = ProjectSettingsManager.shared.settings(for: id)
        XCTAssertTrue(settings.excludedPaths.contains("node_modules"))
    }
}

final class WorkspaceLayoutManagerTests: XCTestCase {
    func testDefaultLayout() {
        let layout = WorkspaceLayoutManager.WorkspaceLayout.defaultLayout
        XCTAssertEqual(layout.sidebarWidth, 240)
        XCTAssertEqual(layout.chatWidth, 360)
    }

    func testSaveAndReset() {
        let manager = WorkspaceLayoutManager.shared
        manager.layout.sidebarWidth = 300
        manager.save()
        manager.reset()
        XCTAssertEqual(manager.layout.sidebarWidth, 240)
    }
}

final class CodeSuggestionEngineTests: XCTestCase {
    func testSuggestFixTODO() {
        let code = "// TODO: implement this"
        let suggestions = CodeSuggestionEngine.shared.suggestions(for: code, language: .swift, cursorPosition: 0)
        XCTAssertTrue(suggestions.contains { $0.kind == .fix })
    }

    func testSuggestFixForceUnwrap() {
        let code = "let x = optional!.property"
        let suggestions = CodeSuggestionEngine.shared.suggestions(for: code, language: .swift, cursorPosition: 0)
        XCTAssertTrue(suggestions.contains { $0.text.contains("force unwrapping") })
    }

    func testSuggestRefactoringLongFunction() {
        let longCode = String(repeating: "    print(\"line\")\n", count: 60)
        let suggestions = CodeSuggestionEngine.shared.suggestions(for: longCode, language: .swift, cursorPosition: 0)
        XCTAssertTrue(suggestions.contains { $0.kind == .refactoring })
    }

    func testSuggestDocumentation() {
        let code = "func foo() {}\nfunc bar() {}\nfunc baz() {}"
        let suggestions = CodeSuggestionEngine.shared.suggestions(for: code, language: .swift, cursorPosition: 0)
        XCTAssertTrue(suggestions.contains { $0.kind == .documentation })
    }

    func testEmptyCodeReturnsEmpty() {
        let suggestions = CodeSuggestionEngine.shared.suggestions(for: "", language: .swift, cursorPosition: 0)
        XCTAssertTrue(suggestions.isEmpty)
    }
}

final class BuildProfileManagerTests: XCTestCase {
    func testDefaultProfiles() {
        let manager = BuildProfileManager.shared
        XCTAssertGreaterThanOrEqual(manager.profiles.count, 3)
        XCTAssertTrue(manager.profiles.contains { $0.name == "Debug" })
        XCTAssertTrue(manager.profiles.contains { $0.name == "Release" })
        XCTAssertTrue(manager.profiles.contains { $0.name == "Test" })
    }

    func testAddProfile() {
        let manager = BuildProfileManager.shared
        let initialCount = manager.profiles.count
        let profile = BuildProfile(name: "Custom Profile")
        manager.add(profile)
        XCTAssertEqual(manager.profiles.count, initialCount + 1)
        manager.remove(profile)
        XCTAssertEqual(manager.profiles.count, initialCount)
    }
}

final class CustomTemplateManagerTests: XCTestCase {
    func testAddAndRemoveTemplate() {
        let manager = CustomTemplateManager.shared
        let template = CustomTemplate(
            name: "Test Template",
            description: "A test template",
            files: [CustomTemplate.TemplateFile(path: "main.swift", content: "let x = 1")]
        )
        manager.add(template)
        XCTAssertTrue(manager.customTemplates.contains { $0.id == template.id })
        manager.remove(template)
        XCTAssertFalse(manager.customTemplates.contains { $0.id == template.id })
    }
}
