import XCTest
@testable import AdventureCoder

final class GitServiceTests: XCTestCase {
    var tmp: URL!
    var project: Project!

    override func setUp() {
        super.setUp()
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("git-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        project = Project(name: "test", rootPath: tmp.path, template: .empty, defaultBranch: "main")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmp!)
        super.tearDown()
    }

    func testInitializeRepo() {
        XCTAssertFalse(GitService.shared.isRepo(project))
        if case .success = GitService.shared.initialize(project) {}
        XCTAssertTrue(GitService.shared.isRepo(project))
    }

    func testStatusAfterInit() {
        if case .success = GitService.shared.initialize(project) {}
        if case .success(let status) = GitService.shared.status(project: project) {
            XCTAssertTrue(status.contains("On branch main"))
        } else {
            XCTFail("Expected status success")
        }
    }

    func testCommitCreatesHistory() throws {
        if case .success = GitService.shared.initialize(project) {}
        try "hello".write(to: tmp.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        if case .success(let sha) = GitService.shared.commit(project: project, message: "initial commit") {
            XCTAssertFalse(sha.isEmpty)
        } else {
            XCTFail("Expected commit success")
        }
        if case .success(let history) = GitService.shared.history(project: project, limit: 10) {
            XCTAssertEqual(history.count, 1)
            XCTAssertEqual(history.first?.message, "initial commit")
        } else {
            XCTFail("Expected history success")
        }
    }

    func testBranchesAfterInit() {
        if case .success = GitService.shared.initialize(project) {}
        if case .success(let branches) = GitService.shared.branches(project: project) {
            XCTAssertTrue(branches.contains { $0.name == "main" })
        } else {
            XCTFail("Expected branches success")
        }
    }

    func testDiffAfterChange() throws {
        if case .success = GitService.shared.initialize(project) {}
        try "line1\nline2".write(to: tmp.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        if case .success = GitService.shared.commit(project: project, message: "v1") {}
        try "line1\nline2\nline3".write(to: tmp.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        if case .success(let diff) = GitService.shared.diff(project: project, staged: false) {
            XCTAssertTrue(diff.contains("+line3"))
        } else {
            XCTFail("Expected diff success")
        }
    }
}
