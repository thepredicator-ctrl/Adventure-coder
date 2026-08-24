import XCTest
@testable import AdventureCoder

final class FileSystemTests: XCTestCase {
    var tmp: URL!

    override func setUp() {
        super.setUp()
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("fs-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmp!)
        super.tearDown()
    }

    func testWriteRead() throws {
        let path = tmp.appendingPathComponent("hello.txt").path
        try FileSystem.shared.write(path, content: "hi")
        XCTAssertEqual(try FileSystem.shared.read(path), "hi")
    }

    func testList() throws {
        try FileSystem.shared.write(tmp.appendingPathComponent("a.txt").path, content: "a")
        try FileSystem.shared.write(tmp.appendingPathComponent("b.txt").path, content: "b")
        let nodes = try FileSystem.shared.list(directory: tmp.path)
        XCTAssertEqual(nodes.count, 2)
    }

    func testSearch() throws {
        try FileSystem.shared.write(tmp.appendingPathComponent("a.txt").path, content: "hello world")
        try FileSystem.shared.write(tmp.appendingPathComponent("b.txt").path, content: "goodbye world")
        let hits = try FileSystem.shared.search(query: "hello", in: tmp.path)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.relativePath, "a.txt")
    }

    func testDelete() throws {
        let path = tmp.appendingPathComponent("to-delete.txt").path
        try FileSystem.shared.write(path, content: "x")
        XCTAssertTrue(FileSystem.shared.exists(path))
        try FileSystem.shared.delete(path)
        XCTAssertFalse(FileSystem.shared.exists(path))
    }

    func testRename() throws {
        let path = tmp.appendingPathComponent("old.txt").path
        try FileSystem.shared.write(path, content: "x")
        let newPath = try FileSystem.shared.rename(path, to: "new.txt")
        XCTAssertTrue(FileSystem.shared.exists(newPath))
        XCTAssertFalse(FileSystem.shared.exists(path))
    }

    func testDuplicate() throws {
        let path = tmp.appendingPathComponent("orig.txt").path
        try FileSystem.shared.write(path, content: "x")
        let copyPath = try FileSystem.shared.duplicate(path)
        XCTAssertTrue(FileSystem.shared.exists(copyPath))
        XCTAssertTrue(FileSystem.shared.exists(path))
    }

    func testRelativePath() {
        let abs = (tmp.path as NSString).appendingPathComponent("sub/file.txt")
        let rel = FileSystem.shared.relativePath(of: abs, from: tmp.path)
        XCTAssertEqual(rel, "sub/file.txt")
    }
}
