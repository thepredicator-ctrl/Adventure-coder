import XCTest
@testable import AdventureCoder

final class EditExtractorTests: XCTestCase {
    func testExtractsCreateFileBlock() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("extract-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let project = Project(name: "test", rootPath: tmp.path, template: .empty)

        let response = """
        Here's the new file:

        ```swift path=Sources/Foo.swift
        struct Foo {}
        ```

        Done.
        """
        let edits = EditExtractor.extract(from: response, project: project)
        XCTAssertEqual(edits.count, 1)
        XCTAssertEqual(edits[0].path, "Sources/Foo.swift")
        XCTAssertEqual(edits[0].kind, .create)
        XCTAssertTrue(edits[0].newContent.contains("struct Foo"))
    }

    func testExtractsReplaceBlock() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("extract-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let project = Project(name: "test", rootPath: tmp.path, template: .empty)

        let response = """
        EDIT path=Bar.swift
        FIND:
        old line
        REPLACE:
        new line
        END_EDIT
        """
        let edits = EditExtractor.extract(from: response, project: project)
        XCTAssertEqual(edits.count, 1)
        XCTAssertEqual(edits[0].path, "Bar.swift")
        XCTAssertEqual(edits[0].findText, "old line\n")
        XCTAssertEqual(edits[0].replaceText, "new line\n")
    }
}
