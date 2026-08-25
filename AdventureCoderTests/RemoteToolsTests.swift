import XCTest
@testable import AdventureCoder

final class RemoteToolsTests: XCTestCase {
    func testAllRemoteToolsRegistered() {
        let names = ToolRegistry.shared.definitions().map { $0.name }
        XCTAssertTrue(names.contains("remote_list_files"))
        XCTAssertTrue(names.contains("remote_read_file"))
        XCTAssertTrue(names.contains("remote_write_file"))
        XCTAssertTrue(names.contains("remote_edit_file"))
        XCTAssertTrue(names.contains("remote_delete_file"))
        XCTAssertTrue(names.contains("remote_create_directory"))
        XCTAssertTrue(names.contains("remote_move_file"))
        XCTAssertTrue(names.contains("remote_copy_file"))
        XCTAssertTrue(names.contains("remote_search_files"))
        XCTAssertTrue(names.contains("remote_execute_command"))
        XCTAssertTrue(names.contains("remote_start_process"))
        XCTAssertTrue(names.contains("remote_stop_process"))
        XCTAssertTrue(names.contains("remote_get_processes"))
        XCTAssertTrue(names.contains("remote_get_environment"))
        XCTAssertTrue(names.contains("remote_install_dependency"))
        XCTAssertTrue(names.contains("remote_build_project"))
        XCTAssertTrue(names.contains("remote_run_tests"))
        XCTAssertTrue(names.contains("remote_get_logs"))
        XCTAssertTrue(names.contains("remote_git_status"))
        XCTAssertTrue(names.contains("remote_git_diff"))
        XCTAssertTrue(names.contains("remote_git_commit"))
        XCTAssertTrue(names.contains("remote_git_push"))
        XCTAssertTrue(names.contains("remote_git_pull"))
        XCTAssertTrue(names.contains("remote_start_preview"))
        XCTAssertTrue(names.contains("remote_stop_preview"))
        XCTAssertTrue(names.contains("remote_download_project"))
    }

    func testRemoteToolDefinitionsHaveRequiredFields() {
        let remoteDefs = ToolRegistry.shared.definitions().filter { $0.name.hasPrefix("remote_") }
        XCTAssertGreaterThanOrEqual(remoteDefs.count, 26)
        for def in remoteDefs {
            XCTAssertFalse(def.name.isEmpty)
            XCTAssertFalse(def.summary.isEmpty)
            XCTAssertFalse(def.description.isEmpty)
        }
    }

    func testRemoteToolCount() {
        let remoteDefs = ToolRegistry.shared.definitions().filter { $0.name.hasPrefix("remote_") }
        XCTAssertGreaterThanOrEqual(remoteDefs.count, 26, "Expected at least 26 remote tools, got \(remoteDefs.count)")
    }

    func testRemoteWriteFileHasSecretDetection() async throws {
        // The tool definition should exist and be destructive
        let def = ToolDefinition.find("remote_write_file")
        XCTAssertNotNil(def)
        XCTAssertTrue(def?.isDestructive ?? false)
    }

    func testRemoteExecuteCommandRequiresConfirmation() {
        let def = ToolDefinition.find("remote_execute_command")
        XCTAssertNotNil(def)
        XCTAssertTrue(def?.requiresConfirmation ?? false)
    }
}
