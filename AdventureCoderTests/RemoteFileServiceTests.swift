import XCTest
@testable import AdventureCoder

final class RemoteFileServiceTests: XCTestCase {
    func testRemoteFileNodeProperties() {
        let entry = RemoteFileEntry(name: "test.swift", path: "/home/user/test.swift", isDirectory: false, size: 1024, modifiedAt: Date())
        let node = RemoteFileNode(from: entry)
        XCTAssertEqual(node.name, "test.swift")
        XCTAssertEqual(node.path, "/home/user/test.swift")
        XCTAssertFalse(node.isDirectory)
        XCTAssertEqual(node.fileExtension, "swift")
        XCTAssertEqual(node.language, .swift)
        XCTAssertNil(node.optionalChildren)
    }

    func testRemoteFileNodeDirectory() {
        let entry = RemoteFileEntry(name: "src", path: "/home/user/src", isDirectory: true, size: 0, modifiedAt: Date())
        let node = RemoteFileNode(from: entry)
        XCTAssertTrue(node.isDirectory)
        XCTAssertNotNil(node.optionalChildren)
        XCTAssertEqual(node.optionalChildren?.count, 0)
    }

    func testRemoteProjectModel() {
        let project = RemoteProject(name: "TestApp", path: "C:\\Users\\Neth\\coder\\TestApp", modifiedAt: Date())
        XCTAssertEqual(project.id, project.path)
        XCTAssertEqual(project.name, "TestApp")
    }

    func testPreviewServerModel() {
        let preview = PreviewServer(
            port: 5173,
            url: "http://192.168.1.100:5173",
            host: "192.168.1.100",
            projectPath: "C:\\Users\\Neth\\coder\\MyApp"
        )
        XCTAssertEqual(preview.port, 5173)
        XCTAssertEqual(preview.url, "http://192.168.1.100:5173")
    }

    func testRemoteEnvironmentModel() {
        let env = RemoteEnvironment(
            os: .windows,
            osVersion: "Windows 11 Pro",
            shell: "PowerShell 7.4",
            cpuArchitecture: "AMD64",
            cpuUsage: 0.18,
            totalRAM: 34_359_738_368,
            availableRAM: 19_928_692_736,
            ramUsage: 0.42,
            totalDiskSpace: 512_000_000_000,
            availableDiskSpace: 200_000_000_000,
            diskUsage: 0.61,
            hostname: "NETH-PC",
            workspacePath: "C:\\Users\\Neth\\coder"
        )
        XCTAssertEqual(env.os, .windows)
        XCTAssertEqual(env.os.displayName, "Windows")
        XCTAssertEqual(env.ramTotalGB, 32.0, accuracy: 0.1)
        XCTAssertEqual(env.diskTotalGB, 476.8, accuracy: 1.0)
    }

    func testRemoteEnvironmentLinux() {
        let env = RemoteEnvironment(os: .linux, osVersion: "Ubuntu 22.04")
        XCTAssertEqual(env.os.displayName, "Linux")
    }

    func testRemoteEnvironmentMacOS() {
        let env = RemoteEnvironment(os: .macos, osVersion: "14.0")
        XCTAssertEqual(env.os.displayName, "macOS")
    }
}
