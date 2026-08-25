import XCTest
@testable import AdventureCoder

final class RemoteHostKeyStoreTests: XCTestCase {
    func testFirstConnectionStoresKey() {
        let store = RemoteHostKeyStore.shared
        store.clearAll()
        let result = store.validate(host: "192.168.1.100", fingerprint: "SHA256:abc123")
        XCTAssertTrue(result)
        XCTAssertEqual(store.storedFingerprint(for: "192.168.1.100"), "SHA256:abc123")
        // Clean up
        store.clearAll()
    }

    func testMatchingKeyReturnsTrue() {
        let store = RemoteHostKeyStore.shared
        store.clearAll()
        _ = store.validate(host: "10.0.0.1", fingerprint: "SHA256:xyz789")
        let result = store.validate(host: "10.0.0.1", fingerprint: "SHA256:xyz789")
        XCTAssertTrue(result)
        store.clearAll()
    }

    func testMismatchedKeyReturnsFalse() {
        let store = RemoteHostKeyStore.shared
        store.clearAll()
        _ = store.validate(host: "172.16.0.1", fingerprint: "SHA256:original")
        let result = store.validate(host: "172.16.0.1", fingerprint: "SHA256:attacker")
        XCTAssertFalse(result)
        store.clearAll()
    }

    func testRemoveHostKey() {
        let store = RemoteHostKeyStore.shared
        store.clearAll()
        _ = store.validate(host: "test.host", fingerprint: "SHA256:test")
        store.remove(host: "test.host")
        XCTAssertNil(store.storedFingerprint(for: "test.host"))
    }
}
