import XCTest
@testable import AdventureCoder

final class TemplateInstallerTests: XCTestCase {
    var tmp: URL!

    override func setUp() {
        super.setUp()
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("template-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmp!)
        super.tearDown()
    }

    func testSwiftUIInstallsAppFile() throws {
        try TemplateInstaller.install(template: .swiftUI, at: tmp, name: "TestApp")
        let appFile = tmp.appendingPathComponent("AdventureCoderApp.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: appFile.path))
        let content = try String(contentsOf: appFile, encoding: .utf8)
        XCTAssertTrue(content.contains("TestApp"))
    }

    func testHTMLInstallsIndex() throws {
        try TemplateInstaller.install(template: .html, at: tmp, name: "test")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("styles.css").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("script.js").path))
    }

    func testReactInstallsTSX() throws {
        try TemplateInstaller.install(template: .react, at: tmp, name: "test")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("src/App.tsx").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("package.json").path))
    }

    func testPythonInstallsMain() throws {
        try TemplateInstaller.install(template: .python, at: tmp, name: "test")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("main.py").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("requirements.txt").path))
    }

    func testRustInstallsCargo() throws {
        try TemplateInstaller.install(template: .rust, at: tmp, name: "test")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("Cargo.toml").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("src/main.rs").path))
    }

    func testGitignoreCreated() throws {
        try TemplateInstaller.install(template: .swiftUI, at: tmp, name: "test")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent(".gitignore").path))
    }
}
