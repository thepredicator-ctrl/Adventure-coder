import XCTest
@testable import AdventureCoder

final class ProjectStoreTests: XCTestCase {
    func testCreateAndDeleteProject() throws {
        let store = ProjectStore.shared
        let initialCount = store.projects.count
        let project = try store.createProject(name: "test-project-\(UUID().uuidString.prefix(8))", template: .swiftUI)
        XCTAssertEqual(store.projects.count, initialCount + 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.rootPath))

        try store.delete(project)
        XCTAssertEqual(store.projects.count, initialCount)
        XCTAssertFalse(FileManager.default.fileExists(atPath: project.rootPath))
    }

    func testTemplateCreatesRealFiles() throws {
        let store = ProjectStore.shared
        let project = try store.createProject(name: "template-test-\(UUID().uuidString.prefix(8))", template: .html)
        defer { try? store.delete(project) }
        let indexPath = (project.rootPath as NSString).appendingPathComponent("index.html")
        XCTAssertTrue(FileManager.default.fileExists(atPath: indexPath))
    }

    func testSwiftUITemplateCreatesAppFile() throws {
        let store = ProjectStore.shared
        let project = try store.createProject(name: "swiftui-test-\(UUID().uuidString.prefix(8))", template: .swiftUI)
        defer { try? store.delete(project) }
        let appFile = (project.rootPath as NSString).appendingPathComponent("ContentView.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: appFile))
    }

    func testConversations() {
        let store = ProjectStore.shared
        let projectId = UUID()
        let conv = store.createConversation(projectId: projectId, title: "Test")
        XCTAssertEqual(store.conversations(for: projectId).first?.id, conv.id)
        store.delete(conv)
        XCTAssertNil(store.conversations(for: projectId).first)
    }
}
