import Foundation

/// A remote PC configuration.
public struct RemotePC: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var username: String
    public var authMethod: AuthMethod
    public var workspacePath: String
    public var createdAt: Date
    public var lastConnectedAt: Date?
    public var isDefault: Bool

    public enum AuthMethod: String, Codable, CaseIterable {
        case password
        case privateKey

        public var displayName: String {
            switch self {
            case .password: return "Password"
            case .privateKey: return "Private Key"
            }
        }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authMethod: AuthMethod = .password,
        workspacePath: String = "",
        createdAt: Date = Date(),
        lastConnectedAt: Date? = nil,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.workspacePath = workspacePath
        self.createdAt = createdAt
        self.lastConnectedAt = lastConnectedAt
        self.isDefault = isDefault
    }

    /// Keychain key for the password or private key.
    public var keychainKey: String {
        "remote_pc.\(id.uuidString)"
    }

    /// Default workspace path if not set.
    public var effectiveWorkspacePath: String {
        if workspacePath.isEmpty {
            // Default to C:\Users\<username>\coder on Windows, ~/coder on Linux/macOS
            return "C:\\Users\\\(username)\\coder"
        }
        return workspacePath
    }
}

/// Detected remote environment information.
public struct RemoteEnvironment: Codable, Hashable {
    public var os: OperatingSystem
    public var osVersion: String
    public var shell: String
    public var availableShells: [String]
    public var cpuArchitecture: String
    public var cpuUsage: Double
    public var totalRAM: Int64
    public var availableRAM: Int64
    public var ramUsage: Double
    public var totalDiskSpace: Int64
    public var availableDiskSpace: Int64
    public var diskUsage: Double
    public var hostname: String
    public var workspacePath: String

    public enum OperatingSystem: String, Codable {
        case windows
        case macos
        case linux
        case unknown

        public var displayName: String {
            switch self {
            case .windows: return "Windows"
            case .macos: return "macOS"
            case .linux: return "Linux"
            case .unknown: return "Unknown"
            }
        }

        public var icon: String {
            switch self {
            case .windows: return "pc"
            case .macos: return "macbook"
            case .linux: return "terminal"
            case .unknown: return "questionmark"
            }
        }
    }

    public init(
        os: OperatingSystem = .unknown,
        osVersion: String = "",
        shell: String = "",
        availableShells: [String] = [],
        cpuArchitecture: String = "",
        cpuUsage: Double = 0,
        totalRAM: Int64 = 0,
        availableRAM: Int64 = 0,
        ramUsage: Double = 0,
        totalDiskSpace: Int64 = 0,
        availableDiskSpace: Int64 = 0,
        diskUsage: Double = 0,
        hostname: String = "",
        workspacePath: String = ""
    ) {
        self.os = os
        self.osVersion = osVersion
        self.shell = shell
        self.availableShells = availableShells
        self.cpuArchitecture = cpuArchitecture
        self.cpuUsage = cpuUsage
        self.totalRAM = totalRAM
        self.availableRAM = availableRAM
        self.ramUsage = ramUsage
        self.totalDiskSpace = totalDiskSpace
        self.availableDiskSpace = availableDiskSpace
        self.diskUsage = diskUsage
        self.hostname = hostname
        self.workspacePath = workspacePath
    }

    public var ramTotalGB: Double { Double(totalRAM) / 1_073_741_824 }
    public var diskTotalGB: Double { Double(totalDiskSpace) / 1_073_741_824 }
}

/// A running remote process.
public struct RemoteProcess: Identifiable, Hashable {
    public var id: Int
    public var name: String
    public var cpuUsage: Double
    public var memoryUsage: Int64
    public var commandLine: String

    public init(id: Int, name: String, cpuUsage: Double = 0, memoryUsage: Int64 = 0, commandLine: String = "") {
        self.id = id
        self.name = name
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.commandLine = commandLine
    }
}

/// Preview server information detected on the remote PC.
public struct PreviewServer: Hashable {
    public var port: Int
    public var url: String
    public var host: String
    public var processId: Int?
    public var projectPath: String
    public var startedAt: Date

    public init(port: Int, url: String, host: String, processId: Int? = nil, projectPath: String, startedAt: Date = Date()) {
        self.port = port
        self.url = url
        self.host = host
        self.processId = processId
        self.projectPath = projectPath
        self.startedAt = startedAt
    }
}

/// Connection test result.
public struct ConnectionTestResult {
    public let success: Bool
    public let message: String
    public let latencyMs: Int
    public let environment: RemoteEnvironment?

    public init(success: Bool, message: String, latencyMs: Int = 0, environment: RemoteEnvironment? = nil) {
        self.success = success
        self.message = message
        self.latencyMs = latencyMs
        self.environment = environment
    }
}
