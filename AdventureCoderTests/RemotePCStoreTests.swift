import XCTest
@testable import AdventureCoder

final class RemotePCStoreTests: XCTestCase {
    @MainActor
    func testAddAndRemoveMachine() {
        let store = RemotePCStore.shared
        let initialCount = store.machines.count
        let machine = RemotePC(name: "Test PC", host: "192.168.1.100", port: 22, username: "testuser")
        store.addMachine(machine)
        XCTAssertEqual(store.machines.count, initialCount + 1)
        store.removeMachine(machine)
        XCTAssertEqual(store.machines.count, initialCount)
    }

    @MainActor
    func testSetActiveMachine() {
        let store = RemotePCStore.shared
        let machine = RemotePC(name: "Test PC 2", host: "10.0.0.1", port: 22, username: "user")
        store.addMachine(machine)
        store.setActive(machine)
        XCTAssertEqual(store.activeMachine?.id, machine.id)
        store.removeMachine(machine)
    }

    @MainActor
    func testCredentialStorage() {
        let store = RemotePCStore.shared
        let machine = RemotePC(name: "Cred Test", host: "localhost", port: 22, username: "user", authMethod: .password)
        store.addMachine(machine)
        defer { store.removeMachine(machine) }

        store.savePassword("test-password-123", for: machine)
        XCTAssertEqual(store.loadPassword(for: machine), "test-password-123")

        store.deleteCredentialsFor(machine: machine)
        XCTAssertNil(store.loadPassword(for: machine))
    }

    @MainActor
    func testMaskedCredentials() {
        let store = RemotePCStore.shared
        let machine = RemotePC(name: "Mask Test", host: "localhost", port: 22, username: "user", authMethod: .password)
        store.addMachine(machine)
        defer { store.removeMachine(machine) }

        store.savePassword("my-secret-password", for: machine)
        let masked = store.maskedCredentials(for: machine)
        XCTAssertTrue(masked.contains("•"))
        XCTAssertFalse(masked.contains("my-secret-password"))
    }

    @MainActor
    func testPrivateKeyStorage() {
        let store = RemotePCStore.shared
        let machine = RemotePC(name: "Key Test", host: "localhost", port: 22, username: "user", authMethod: .privateKey)
        store.addMachine(machine)
        defer { store.removeMachine(machine) }

        let testKey = "-----BEGIN OPENSSH PRIVATE KEY-----\nfakekey\n-----END OPENSSH PRIVATE KEY-----"
        store.savePrivateKey(testKey, for: machine)
        XCTAssertEqual(store.loadPrivateKey(for: machine), testKey)

        store.deleteCredentialsFor(machine: machine)
        XCTAssertNil(store.loadPrivateKey(for: machine))
    }

    @MainActor
    func testDefaultWorkspacePath() {
        let machine = RemotePC(name: "Test", host: "localhost", port: 22, username: "Neth")
        XCTAssertEqual(machine.effectiveWorkspacePath, "C:\\Users\\Neth\\coder")
    }

    @MainActor
    func testCustomWorkspacePath() {
        let machine = RemotePC(name: "Test", host: "localhost", port: 22, username: "Neth", workspacePath: "D:\\Projects")
        XCTAssertEqual(machine.effectiveWorkspacePath, "D:\\Projects")
    }
}
