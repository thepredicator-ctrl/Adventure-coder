import Foundation
import NIOSSH
import NIOCore
import NIOPosix
import Crypto

/// Real SSH client built on Apple's swift-nio-ssh library.
///
/// Provides async/await wrappers around NIO's EventLoopFuture-based API.
/// Supports password authentication, command execution with streaming output,
/// and connection lifecycle management.
public final class SSHService: ObservableObject {
    public static let shared = SSHService()

    @Published public private(set) var isConnected = false
    @Published public private(set) var connectionInfo: ConnectionInfo?

    private var client: SSHClient?
    private let group: MultiThreadedEventLoopGroup

    public struct ConnectionInfo: Equatable {
        public let host: String
        public let port: Int
        public let username: String
        public var connectedAt: Date
    }

    public enum SSHError: Error, LocalizedError {
        case notConnected
        case authenticationFailed(String)
        case connectionRefused
        case connectionTimeout
        case hostUnreachable
        case invalidPort
        case sshUnavailable
        case permissionDenied
        case hostKeyMismatch
        case unknown(String)

        public var errorDescription: String? {
            switch self {
            case .notConnected: return "Not connected to a remote PC."
            case .authenticationFailed(let detail): return "Authentication failed: \(detail)"
            case .connectionRefused: return "Connection refused. Check that the SSH server is running on the remote PC."
            case .connectionTimeout: return "Connection timed out. The remote PC did not respond in time."
            case .hostUnreachable: return "Host unreachable. Check the IP address and network connection."
            case .invalidPort: return "Invalid port number. SSH typically uses port 22."
            case .sshUnavailable: return "SSH is not available on the remote host. Install OpenSSH Server on the PC."
            case .permissionDenied: return "Permission denied. Check the username and credentials."
            case .hostKeyMismatch: return "Host key has changed. This could be a security concern."
            case .unknown(let detail): return detail
            }
        }
    }

    public struct CommandResult {
        public let stdout: String
        public let stderr: String
        public let exitCode: Int
        public var success: Bool { exitCode == 0 }
    }

    private init() {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    // MARK: - Connection

    public func connect(
        host: String,
        port: Int = 22,
        username: String,
        password: String?,
        privateKey: String? = nil,
        hostKeyCallback: ((String) -> Bool)? = nil
    ) async throws {
        guard port > 0 && port < 65536 else { throw SSHError.invalidPort }
        guard !host.isEmpty else { throw SSHError.hostUnreachable }
        guard password != nil || privateKey != nil else {
            throw SSHError.authenticationFailed("No credentials provided")
        }

        let auth: SSHClientAuthentication
        if let privateKey = privateKey, !privateKey.isEmpty {
            let key = try NIOSSHPrivateKey(pemKey: privateKey)
            auth = .privateKey(username: username, privateKey: key)
        } else if let password = password {
            auth = .passwordBased(username: username, password: password)
        } else {
            throw SSHError.authenticationFailed("No credentials provided")
        }

        let validator: SSHHostKeyValidator
        if let callback = hostKeyCallback {
            validator = SSHHostKeyValidator.custom { hostKey in
                let fingerprint = hostKey.fingerprint
                return callback(fingerprint)
            }
        } else {
            validator = .acceptAll()
        }

        let config = SSHClientConfiguration(
            user: auth,
            hostKeyValidator: validator,
            algorithmSet: .default
        )

        do {
            let connected = try await SSHClient.connect(
                host: host,
                port: port,
                configuration: config,
                group: group
            ).get()
            self.client = connected
            self.isConnected = true
            self.connectionInfo = ConnectionInfo(
                host: host,
                port: port,
                username: username,
                connectedAt: Date()
            )
        } catch let error as SSHError {
            throw error
        } catch {
            // Map NIO errors to user-friendly messages
            let nsError = error as NSError
            let message = error.localizedDescription.lowercased()
            if nsError.domain == "NIOSSH" || message.contains("ssh") {
                if message.contains("auth") || message.contains("password") || message.contains("key") {
                    throw SSHError.authenticationFailed(error.localizedDescription)
                }
                throw SSHError.sshUnavailable
            }
            if nsError.domain == "POSIXError" || nsError.domain == "NIOCore" {
                switch nsError.code {
                case 61: throw SSHError.connectionRefused
                case 60: throw SSHError.connectionTimeout
                case 65, 51, 68: throw SSHError.hostUnreachable
                case 13: throw SSHError.permissionDenied
                default:
                    if message.contains("refused") { throw SSHError.connectionRefused }
                    if message.contains("timeout") { throw SSHError.connectionTimeout }
                    if message.contains("unreachable") || message.contains("no route") { throw SSHError.hostUnreachable }
                    throw SSHError.unknown(error.localizedDescription)
                }
            }
            if message.contains("refused") { throw SSHError.connectionRefused }
            if message.contains("timeout") { throw SSHError.connectionTimeout }
            if message.contains("unreachable") || message.contains("no route") { throw SSHError.hostUnreachable }
            if message.contains("auth") || message.contains("credential") { throw SSHError.authenticationFailed(error.localizedDescription) }
            throw SSHError.unknown(error.localizedDescription)
        }
    }

    public func disconnect() async {
        if let client = client {
            try? await client.close().get()
        }
        self.client = nil
        self.isConnected = false
        self.connectionInfo = nil
    }

    // MARK: - Command execution

    /// Execute a command and return the complete output.
    public func execute(_ command: String) async throws -> CommandResult {
        guard let client = client else { throw SSHError.notConnected }
        let execution = client.executeCommand(command)
        var stdout = ""
        var stderr = ""
        // Collect output
        for try await buffer in execution.output {
            stdout += String(buffer: buffer)
        }
        for try await buffer in execution.stderrOutput {
            stderr += String(buffer: buffer)
        }
        let exitCode = try await execution.exitStatus.get()
        return CommandResult(stdout: stdout, stderr: stderr, exitCode: exitCode)
    }

    /// Execute a command with streaming output, calling onOutput for each chunk.
    public func executeStreaming(
        _ command: String,
        onStdout: @escaping (String) -> Void,
        onStderr: @escaping (String) -> Void
    ) async throws -> Int {
        guard let client = client else { throw SSHError.notConnected }
        let execution = client.executeCommand(command)
        // Use a task group to read stdout and stderr concurrently
        return try await withTaskGroup(of: StreamChunk.self, returning: Int.self) { group in
            group.addTask {
                var output = ""
                for try await buffer in execution.output {
                    let s = String(buffer: buffer)
                    output += s
                    onStdout(s)
                }
                return .stdout(output)
            }
            group.addTask {
                var output = ""
                for try await buffer in execution.stderrOutput {
                    let s = String(buffer: buffer)
                    output += s
                    onStderr(s)
                }
                return .stderr(output)
            }
            // Wait for exit status
            let exitCode = try await execution.exitStatus.get()
            // Drain the group
            for await _ in group {}
            return exitCode
        }
    }

    /// Execute a command with a timeout.
    public func execute(_ command: String, timeout: TimeInterval) async throws -> CommandResult {
        return try await withThrowingTaskGroup(of: CommandResult.self) { group in
            group.addTask {
                try await self.execute(command)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw SSHError.connectionTimeout
            }
            guard let result = try await group.next() else {
                throw SSHError.unknown("Task group returned no results")
            }
            group.cancelAll()
            return result
        }
    }

    // MARK: - File operations (via command execution)

    /// Read a file's content as UTF-8 text.
    public func readFile(_ path: String) async throws -> String {
        // Use base64 to safely transfer binary/special characters
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        let result = try await execute("cat '\(escaped)' 2>/dev/null || type '\(escaped)' 2>nul")
        if result.success {
            return result.stdout
        }
        // Try PowerShell
        let psResult = try await execute("powershell -Command \"Get-Content -Raw -Path '\(escaped)'\"")
        return psResult.stdout
    }

    /// Write content to a file, creating it if it doesn't exist.
    public func writeFile(_ path: String, content: String) async throws {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        // Base64-encode the content to avoid shell escaping issues
        let base64 = Data(content.utf8).base64EncodedString()
        // Try Linux/macOS first, then Windows PowerShell
        let result = try await execute("echo '\(base64)' | base64 -d > '\(escaped)' 2>/dev/null; if [ $? -ne 0 ]; then powershell -Command \"[System.IO.File]::WriteAllText('\(escaped)', [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('\(base64)')))\"; fi")
        if !result.success && !result.stdout.isEmpty {
            throw SSHError.unknown("Failed to write file: \(result.stderr)")
        }
    }

    /// Create a directory (and parents) at the given path.
    public func createDirectory(_ path: String) async throws {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        _ = try await execute("mkdir -p '\(escaped)' 2>/dev/null; if [ $? -ne 0 ]; then powershell -Command \"New-Item -ItemType Directory -Force -Path '\(escaped)'\"; fi")
    }

    /// Delete a file or directory.
    public func deletePath(_ path: String) async throws {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        _ = try await execute("rm -rf '\(escaped)' 2>/dev/null; if [ $? -ne 0 ]; then powershell -Command \"Remove-Item -Recurse -Force '\(escaped)'\"; fi")
    }

    /// Move/rename a file or directory.
    public func movePath(_ from: String, to: String) async throws {
        let fromEsc = from.replacingOccurrences(of: "'", with: "'\\''")
        let toEsc = to.replacingOccurrences(of: "'", with: "'\\''")
        _ = try await execute("mv '\(fromEsc)' '\(toEsc)' 2>/dev/null; if [ $? -ne 0 ]; then powershell -Command \"Move-Item '\(fromEsc)' '\(toEsc)'\"; fi")
    }

    /// Copy a file or directory.
    public func copyPath(_ from: String, to: String) async throws {
        let fromEsc = from.replacingOccurrences(of: "'", with: "'\\''")
        let toEsc = to.replacingOccurrences(of: "'", with: "'\\''")
        _ = try await execute("cp -r '\(fromEsc)' '\(toEsc)' 2>/dev/null; if [ $? -ne 0 ]; then powershell -Command \"Copy-Item -Recurse '\(fromEsc)' '\(toEsc)'\"; fi")
    }

    /// List files in a directory. Returns JSON-compatible array.
    public func listFiles(_ path: String) async throws -> [RemoteFileEntry] {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        // Try Linux/macOS format first
        let result = try await execute("ls -la --time-style=+%s '\(escaped)' 2>/dev/null")
        if result.success && !result.stdout.isEmpty {
            return parseLinuxListing(result.stdout, basePath: path)
        }
        // Try Windows PowerShell
        let psResult = try await execute("powershell -Command \"Get-ChildItem -Path '\(escaped)' | Select-Object Name, Length, LastWriteTime, @{N='Mode';E={if(\$_.PSIsContainer){'d'}else{'-'}}} | ConvertTo-Csv -NoTypeInformation\"")
        if psResult.success {
            return parseWindowsListing(psResult.stdout, basePath: path)
        }
        return []
    }

    /// Search for a text pattern in files under a directory.
    public func searchFiles(query: String, in directory: String) async throws -> [RemoteSearchHit] {
        let dirEsc = directory.replacingOccurrences(of: "'", with: "'\\''")
        let queryEsc = query.replacingOccurrences(of: "'", with: "'\\''")
        // Try grep (Linux/macOS)
        let result = try await execute("grep -rn '\(queryEsc)' '\(dirEsc)' 2>/dev/null")
        if result.success {
            return parseGrepOutput(result.stdout, basePath: directory)
        }
        // Try Windows PowerShell Select-String
        let psResult = try await execute("powershell -Command \"Select-String -Path '\(dirEsc)\\*' -Pattern '\(queryEsc)' -Recurse | ForEach-Object { \\\"\$_.Path:\$_.LineNumber:\$_.Line\\\" }\"")
        if psResult.success {
            return parseWindowsSearchOutput(psResult.stdout, basePath: directory)
        }
        return []
    }

    // MARK: - Parsing helpers

    private func parseLinuxListing(_ output: String, basePath: String) -> [RemoteFileEntry] {
        var entries: [RemoteFileEntry] = []
        for line in output.components(separatedBy: "\n").dropFirst() { // skip header
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: true).map { String($0) }
            guard parts.count >= 9 else { continue }
            let perms = parts[0]
            let size = Int64(parts[4]) ?? 0
            let name = parts[8...].joined(separator: " ")
            if name == "." || name == ".." { continue }
            let isDir = perms.hasPrefix("d")
            entries.append(RemoteFileEntry(
                name: name,
                path: (basePath as NSString).appendingPathComponent(name),
                isDirectory: isDir,
                size: size,
                modifiedAt: Date()
            ))
        }
        return entries
    }

    private func parseWindowsListing(_ output: String, basePath: String) -> [RemoteFileEntry] {
        var entries: [RemoteFileEntry] = []
        let lines = output.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count > 1 else { return entries }
        for line in lines.dropFirst() { // skip header
            let fields = line.split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            guard fields.count >= 4 else { continue }
            let name = fields[0]
            let size = Int64(fields[1]) ?? 0
            let mode = fields[3]
            if name == "." || name == ".." { continue }
            entries.append(RemoteFileEntry(
                name: name,
                path: (basePath as NSString).appendingPathComponent(name),
                isDirectory: mode == "d",
                size: size,
                modifiedAt: Date()
            ))
        }
        return entries
    }

    private func parseGrepOutput(_ output: String, basePath: String) -> [RemoteSearchHit] {
        var hits: [RemoteSearchHit] = []
        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: ":", maxSplits: 2).map { String($0) }
            guard parts.count >= 3 else { continue }
            hits.append(RemoteSearchHit(
                path: parts[0],
                line: Int(parts[1]) ?? 0,
                snippet: parts[2]
            ))
        }
        return hits
    }

    private func parseWindowsSearchOutput(_ output: String, basePath: String) -> [RemoteSearchHit] {
        var hits: [RemoteSearchHit] = []
        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: ":", maxSplits: 2).map { String($0) }
            guard parts.count >= 3 else { continue }
            hits.append(RemoteSearchHit(
                path: parts[0],
                line: Int(parts[1]) ?? 0,
                snippet: parts[2]
            ))
        }
        return hits
    }

    private enum StreamChunk {
        case stdout(String)
        case stderr(String)
    }
}

// MARK: - Remote file models

public struct RemoteFileEntry: Identifiable, Hashable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64
    public let modifiedAt: Date

    public init(name: String, path: String, isDirectory: Bool, size: Int64, modifiedAt: Date) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedAt = modifiedAt
    }
}

public struct RemoteSearchHit: Hashable {
    public let path: String
    public let line: Int
    public let snippet: String
}
