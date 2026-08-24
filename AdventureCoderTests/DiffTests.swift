import XCTest
@testable import AdventureCoder

final class DiffTests: XCTestCase {
    func testIdenticalContentProducesNoChanges() {
        let old = "line1\nline2\nline3"
        let new = "line1\nline2\nline3"
        let hunks = DiffAlgorithm.computeHunks(oldLines: old.components(separatedBy: "\n"), newLines: new.components(separatedBy: "\n"))
        let added = hunks.flatMap { $0.lines.filter { $0.kind == .added } }
        let removed = hunks.flatMap { $0.lines.filter { $0.kind == .removed } }
        XCTAssertTrue(added.isEmpty)
        XCTAssertTrue(removed.isEmpty)
    }

    func testAddedLine() {
        let old = "a\nb"
        let new = "a\nb\nc"
        let hunks = DiffAlgorithm.computeHunks(oldLines: old.components(separatedBy: "\n"), newLines: new.components(separatedBy: "\n"))
        let added = hunks.flatMap { $0.lines.filter { $0.kind == .added } }
        XCTAssertTrue(added.contains(where: { $0.content == "c" }))
    }

    func testRemovedLine() {
        let old = "a\nb\nc"
        let new = "a\nc"
        let hunks = DiffAlgorithm.computeHunks(oldLines: old.components(separatedBy: "\n"), newLines: new.components(separatedBy: "\n"))
        let removed = hunks.flatMap { $0.lines.filter { $0.kind == .removed } }
        XCTAssertTrue(removed.contains(where: { $0.content == "b" }))
    }

    func testUnifiedDiffFormat() {
        let old = "a\nb"
        let new = "a\nB"
        let diff = DiffAlgorithm.unifiedDiff(old: old, new: new, path: "file.txt")
        XCTAssertTrue(diff.contains("diff --git"))
        XCTAssertTrue(diff.contains("@@"))
        XCTAssertTrue(diff.contains("-b"))
        XCTAssertTrue(diff.contains("+B"))
    }
}
