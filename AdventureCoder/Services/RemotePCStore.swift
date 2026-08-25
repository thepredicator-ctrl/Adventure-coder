import Foundation
import Combine

/// Manages multiple remote PC configurations and the active connection.
@MainActor
public final class RemotePCStore: ObservableObject {
    public static let shared = RemotePCStore()

    @Published public var machines: [RemotePC] = []
    @Published public var activeMachineId: UUID?
    @Published public var isConnected: Bool = false
    @Published public var environment: RemoteEnvironment?
    @Published public var connectionError: String?
    @Published public var isConnecting: Bool = false

    private let defaults = UserDefaults.standard
    private let storageKey = "remote_pcs"

    private init() {
        load()
    }

    // MARK: - Machine management

    public var activeMachine: RemotePC? {
        machines.first { $0.id == activeMachineId }
    }

    public func addMachine(_ machine: RemotePC) {
        machines.append(machine)
        if machines.count == 1 || machine.isDefault {
            activeMachineId = machine.id
        }
        save()
    }

    public func updateMachine(_ machine: RemotePC) {
        if let idx = machines.firstIndex(where: { $0.id == machine.id }) {
            machines[idx] = machine
            save()
        }
    }

    public func removeMachine(_ machine: RemotePC) {
        machines.removeAll { $0.id == machine.id }
        // Delete stored credentials
        deleteCredentialsFor(machine: machine)
        if activeMachineId == machine.id {
            activeMachineId = machines.first?.id
        }
        save()
    }

    public func setActive(_ machine: RemotePC) {
        activeMachineId = machine.id
        save()
    }

    // MARK: - Credential management

    public func saveCredentials(for machine: RemotePC, password: String? = nil, privateKey: String? = nil) {
        if let password = password {
            savePassword(password, for: machine)
        }
        if let privateKey = privateKey {
            savePrivateKey(privateKey, for: machine)
        }
    }

    public func loadCredentials(for machine: RemotePC) -> (password: String?, privateKey: String?) {
        let password = loadPassword(for: machine)
        let privateKey = loadPrivateKey(for: machine)
        return (password, privateKey)
    }

    public func deleteCredentials(for machine: RemotePC) {
        deleteCredentialsFor(machine: machine)
    }

    public func maskedPassword(for machine: RemotePC) -> String {
        return maskedCredentials(for: machine)
    }

    // MARK: - Connection

    public func connect(to machine: RemotePC) async -> ConnectionTestResult {
        isConnecting = true
        connectionError = nil
        defer { isConnecting = false }

        let (password, privateKey) = loadCredentials(for: machine)

        let startTime = Date()
        do {
            try await SSHService.shared.connect(
                host: machine.host,
                port: machine.port,
                username: machine.username,
                password: password,
                privateKey: privateKey,
                hostKeyCallback: { fingerprint in
                    // For now, accept all host keys. In production, this would show
                    // a confirmation dialog to the user.
                    return RemoteHostKeyStore.shared.validate(host: machine.host, fingerprint: fingerprint)
                }
            )
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)

            // Detect environment
            let env = try await detectEnvironment(for: machine)
            self.environment = env
            self.isConnected = true
            self.activeMachineId = machine.id

            // Update last connected time
            var updated = machine
            updated.lastConnectedAt = Date()
            updated.workspacePath = env.workspacePath
            self.updateMachine(updated)

            return ConnectionTestResult(
                success: true,
                message: "Connected to \(machine.name)",
                latencyMs: latency,
                environment: env
            )
        } catch let error as SSHService.SSHError {
            self.connectionError = error.errorDescription
            self.isConnected = false
            return ConnectionTestResult(success: false, message: error.errorDescription ?? "Unknown error")
        } catch {
            self.connectionError = error.localizedDescription
            self.isConnected = false
            return ConnectionTestResult(success: false, message: error.localizedDescription)
        }
    }

    public func disconnect() async {
        await SSHService.shared.disconnect()
        self.isConnected = false
        self.environment = nil
    }

    public func testConnection(to machine: RemotePC) async -> ConnectionTestResult {
        let result = await connect(to: machine)
        if result.success {
            await disconnect()
        }
        return result
    }

    // MARK: - Environment detection

    private func detectEnvironment(for machine: RemotePC) async throws -> RemoteEnvironment {
        var env = RemoteEnvironment()
        env.hostname = machine.host

        // Detect OS
        let osResult = try await SSHService.shared.execute("ver 2>nul || uname -s")
        let osOutput = osResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if osOutput.lowercased().contains("windows") {
            env.os = .windows
            env.osVersion = osOutput
            // Get Windows details via PowerShell
            let psVersion = try? await SSHService.shared.execute("powershell -Command \"$PSVersionTable.PSVersion.ToString()\"")
            if let ps = psVersion?.stdout.trimmingCharacters(in: .whitespacesAndNewlines), !ps.isEmpty {
                env.shell = "PowerShell \(ps)"
            }
            // CPU architecture
            let arch = try? await SSHService.shared.execute("powershell -Command \"$env:PROCESSOR_ARCHITECTURE\"")
            env.cpuArchitecture = arch?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            // RAM
            let ram = try? await SSHService.shared.execute("powershell -Command \"$total = (Get-CIMInstance Win32_ComputerSystem).TotalPhysicalMemory; $free = (Get-CIMInstance Win32_OperatingSystem).FreePhysicalMemory * 1KB; Write-Output \\\"$total $free\\\"\"")
            if let ramStr = ram?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) {
                let parts = ramStr.split(separator: " ")
                if parts.count >= 2 {
                    env.totalRAM = Int64(parts[0]) ?? 0
                    env.availableRAM = Int64(parts[1]) ?? 0
                    if env.totalRAM > 0 {
                        env.ramUsage = 1.0 - (Double(env.availableRAM) / Double(env.totalRAM))
                    }
                }
            }

            // Disk
            let disk = try? await SSHService.shared.execute("powershell -Command \"$d = Get-PSDrive C; Write-Output \\\"$($d.Used) $($d.Free)\\\"\"")
            if let diskStr = disk?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) {
                let parts = diskStr.split(separator: " ")
                if parts.count >= 2 {
                    let used = Int64(parts[0]) ?? 0
                    let free = Int64(parts[1]) ?? 0
                    env.totalDiskSpace = used + free
                    env.availableDiskSpace = free
                    if env.totalDiskSpace > 0 {
                        env.diskUsage = Double(used) / Double(env.totalDiskSpace)
                    }
                }
            }

            // CPU usage
            let cpu = try? await SSHService.shared.execute("powershell -Command \"(Get-CIMInstance Win32_Processor).LoadPercentage\"")
            if let cpuStr = cpu?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) {
                env.cpuUsage = (Double(cpuStr) ?? 0) / 100.0
            }

            // Workspace path
            env.workspacePath = "C:\\Users\\\(machine.username)\\coder"
        } else if osOutput.lowercased().contains("darwin") || osOutput.lowercased().contains("mac") {
            env.os = .macos
            env.osVersion = (try? await SSHService.shared.execute("sw_vers -productVersion"))?.stdout ?? ""
            env.shell = (try? await SSHService.shared.execute("echo $SHELL"))?.stdout ?? "/bin/bash"
            env.cpuArchitecture = (try? await SSHService.shared.execute("uname -m"))?.stdout ?? ""
            env.workspacePath = "/Users/\(machine.username)/coder"
        } else if !osOutput.isEmpty {
            env.os = .linux
            env.osVersion = osOutput
            env.shell = (try? await SSHService.shared.execute("echo $SHELL"))?.stdout ?? "/bin/bash"
            env.cpuArchitecture = (try? await SSHService.shared.execute("uname -m"))?.stdout ?? ""
            env.workspacePath = "/home/\(machine.username)/coder"
        }

        // Ensure workspace exists
        if !env.workspacePath.isEmpty {
            try? await SSHService.shared.createDirectory(env.workspacePath)
        }

        return env
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(machines) {
            defaults.set(data, forKey: storageKey)
        }
        if let id = activeMachineId {
            defaults.set(id.uuidString, forKey: "\(storageKey).active")
        }
    }

    private func load() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([RemotePC].self, from: data) {
            machines = decoded
        }
        if let idStr = defaults.string(forKey: "\(storageKey).active"),
           let id = UUID(uuidString: idStr) {
            activeMachineId = id
        }
    }
}

// MARK: - Keychain extensions for dynamic key support

/// Extension to KeychainService for dynamic string-based key support,
/// used by the remote PC credential storage.
public extension KeychainService {
    enum DynamicKey {
        public static func password(for pcId: String) -> String { "remote_pc.password.\(pcId)" }
        public static func privateKey(for pcId: String) -> String { "remote_pc.privatekey.\(pcId)" }
    }

    static func save(_ key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return saveData(key, data: data)
    }

    static func saveData(_ key: String, data: Data) -> Bool {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    static func load(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    static func has(_ key: String) -> Bool {
        load(key) != nil
    }

    static func masked(_ key: String) -> String {
        guard let value = load(key), !value.isEmpty else { return "Not set" }
        if value.count <= 8 {
            return String(repeating: "•", count: value.count)
        }
        let head = String(value.prefix(4))
        let tail = String(value.suffix(4))
        return "\(head)••••••••\(tail)"
    }
}

/// Convenience methods that use dynamic keys for remote PC credentials.
public extension RemotePCStore {
    func savePassword(_ password: String, for machine: RemotePC) {
        KeychainService.save(KeychainService.DynamicKey.password(for: machine.id.uuidString), value: password)
    }
    func savePrivateKey(_ key: String, for machine: RemotePC) {
        KeychainService.save(KeychainService.DynamicKey.privateKey(for: machine.id.uuidString), value: key)
    }
    func loadPassword(for machine: RemotePC) -> String? {
        KeychainService.load(KeychainService.DynamicKey.password(for: machine.id.uuidString))
    }
    func loadPrivateKey(for machine: RemotePC) -> String? {
        KeychainService.load(KeychainService.DynamicKey.privateKey(for: machine.id.uuidString))
    }
    func deleteCredentialsFor(machine: RemotePC) {
        KeychainService.delete(KeychainService.DynamicKey.password(for: machine.id.uuidString))
        KeychainService.delete(KeychainService.DynamicKey.privateKey(for: machine.id.uuidString))
    }
    func maskedCredentials(for machine: RemotePC) -> String {
        switch machine.authMethod {
        case .password:
            let pwd = loadPassword(for: machine)
            guard let p = pwd, !p.isEmpty else { return "Not set" }
            return String(repeating: "•", count: min(p.count, 12))
        case .privateKey:
            let key = loadPrivateKey(for: machine)
            guard let k = key, !k.isEmpty else { return "Not set" }
            return "••••••••" + String(k.suffix(4))
        }
    }
}
