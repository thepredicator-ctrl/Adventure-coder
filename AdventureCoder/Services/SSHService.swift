import Foundation
import NIOSSH
import NIOCore
import NIOPosix

/// Real SSH client built on Apple's swift-nio-ssh library (v0.12.0).
///
/// Uses NIOSSH's low-level API: SSHClientConfiguration, NIOSSHHandler,
/// and child channels for command execution with streaming output.
public final class SSHService: ObservableObject {
    public static let shared = SSHService()

    @Published public private(set) var isConnected = false
    @Published public private(set) var connectionInfo: ConnectionInfo?

    private var channel: Channel?
    private var sshHandler: NIOSSHHandler?
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
        guard let password = password else {
            throw SSHError.authenticationFailed("Password authentication is required. Private key auth is not yet supported.")
        }

        let authDelegate = SimplePasswordDelegate(username: username, password: password)

        let serverAuthDelegate = AcceptAllHostKeyDelegate()

        let config = SSHClientConfiguration(
            userAuthDelegate: authDelegate,
            serverAuthDelegate: serverAuthDelegate
        )

        do {
            let bootstrap = ClientBootstrap(group: group)
                .channelInitializer { channel in
                    let handler = NIOSSHHandler(
                        role: .client(config),
                        allocator: channel.allocator,
                        inboundChildChannelInitializer: nil
                    )
                    return channel.pipeline.addHandler(handler)
                }

            let connected = try await bootstrap.connect(host: host, port: port).get()
            // Get the SSH handler from the pipeline
            let handler = try await connected.pipeline.handler(type: NIOSSHHandler.self).get()
            self.channel = connected
            self.sshHandler = handler
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
        if let channel = channel {
            try? await channel.close().get()
        }
        self.channel = nil
        self.sshHandler = nil
        self.isConnected = false
        self.connectionInfo = nil
    }

    // MARK: - Command execution

    /// Execute a command and return the complete output.
    public func execute(_ command: String) async throws -> CommandResult {
        guard let handler = sshHandler, let channel = channel else { throw SSHError.notConnected }

        // Create a promise for the child channel
        let channelPromise = channel.eventLoop.makePromise(of: Channel.self)
        let outputCollector = OutputCollector()

        handler.createChannel(channelPromise, channelType: .session) { childChannel, _ in
            childChannel.pipeline.addHandler(outputCollector)
        }

        let childChannel = try await channelPromise.futureResult.get()

        // Send the exec request
        try await childChannel.triggerUserOutboundEvent(
            SSHChannelRequestEvent.ExecRequest(command: command, wantReply: true)
        ).get()

        // Wait for the command to complete
        let exitCode = try await outputCollector.waitForCompletion()
        return CommandResult(
            stdout: outputCollector.stdout,
            stderr: outputCollector.stderr,
            exitCode: exitCode
        )
    }

    /// Execute a command with streaming output, calling onOutput for each chunk.
    public func executeStreaming(
        _ command: String,
        onStdout: @escaping (String) -> Void,
        onStderr: @escaping (String) -> Void
    ) async throws -> Int {
        guard let handler = sshHandler, let channel = channel else { throw SSHError.notConnected }

        let channelPromise = channel.eventLoop.makePromise(of: Channel.self)
        let outputCollector = OutputCollector(
            onStdout: onStdout,
            onStderr: onStderr
        )

        handler.createChannel(channelPromise, channelType: .session) { childChannel, _ in
            childChannel.pipeline.addHandler(outputCollector)
        }

        let childChannel = try await channelPromise.futureResult.get()

        // Send the exec request
        try await childChannel.triggerUserOutboundEvent(
            SSHChannelRequestEvent.ExecRequest(command: command, wantReply: true)
        ).get()

        // Wait for completion
        return try await outputCollector.waitForCompletion()
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

    public func readFile(_ path: String) async throws -> String {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        let result = try await execute("cat '\(escaped)' 2>/dev/null || type '\(escaped)' 2>nul")
        if result.success {
            return result.stdout
        }
        let psResult = try await execute("powershell -Command \"Get-Content -Raw -Path '\(escaped)'\"")
        return psResult.stdout
    }

    public func writeFile(_ path: String, content: String) async throws {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        let base64 = Data(content.utf8).base64EncodedString()
        let result = try await execute("echo '\(base64)' | base64 -d > '\(escaped)' 2>/dev/null; if [ $? -ne 0 ]; then powershell -Command \"[System.IO.File]::WriteAllText('\(escaped)', [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('\(base64)')))\"; fi")
        if !result.success && !result.stdout.isEmpty {
            throw SSHError.unknown("Failed to write file: \(result.stderr)")
        }
    }

    public func createDirectory(_ path: String) async throws {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        _ = try await execute("mkdir -p '\(escaped)' 2>/dev/null; if [ $? -ne 0 ]; then powershell -Command \"New-Item -ItemType Directory -Force -Path '\(escaped)'\"; fi")
    }

    public func deletePath(_ path: String) async throws {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        _ = try await execute("rm -rf '\(escaped)' 2>/dev/null; if [ $? -ne 0 ]; then powershell -Command \"Remove-Item -Recurse -Force '\(escaped)'\"; fi")
    }

    public func movePath(from: String, to: String) async throws {
        let fromEsc = from.replacingOccurrences(of: "'", with: "'\\''")
        let toEsc = to.replacingOccurrences(of: "'", with: "'\\''")
        _ = try await execute("mv '\(fromEsc)' '\(toEsc)' 2>/dev/null; if [ $? -ne 0 ]; then powershell -Command \"Move-Item '\(fromEsc)' '\(toEsc)'\"; fi")
    }

    public func copyPath(from: String, to: String) async throws {
        let fromEsc = from.replacingOccurrences(of: "'", with: "'\\''")
        let toEsc = to.replacingOccurrences(of: "'", with: "'\\''")
        _ = try await execute("cp -r '\(fromEsc)' '\(toEsc)' 2>/dev/null; if [ $? -ne 0 ]; then powershell -Command \"Copy-Item -Recurse '\(fromEsc)' '\(toEsc)'\"; fi")
    }

    public func listFiles(_ path: String) async throws -> [RemoteFileEntry] {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        let result = try await execute("ls -la --time-style=+%s '\(escaped)' 2>/dev/null")
        if result.success && !result.stdout.isEmpty {
            return parseLinuxListing(result.stdout, basePath: path)
        }
        let psResult = try await execute("powershell -Command \"Get-ChildItem -Path '\(escaped)' | Select-Object Name, Length, LastWriteTime, @{N='Mode';E={if(\\$_.PSIsContainer){'d'}else{'-'}}} | ConvertTo-Csv -NoTypeInformation\"")
        if psResult.success {
            return parseWindowsListing(psResult.stdout, basePath: path)
        }
        return []
    }

    public func searchFiles(query: String, in directory: String) async throws -> [RemoteSearchHit] {
        let dirEsc = directory.replacingOccurrences(of: "'", with: "'\\''")
        let queryEsc = query.replacingOccurrences(of: "'", with: "'\\''")
        let result = try await execute("grep -rn '\(queryEsc)' '\(dirEsc)' 2>/dev/null")
        if result.success {
            return parseGrepOutput(result.stdout, basePath: directory)
        }
        return []
    }

    // MARK: - Parsing helpers

    private func parseLinuxListing(_ output: String, basePath: String) -> [RemoteFileEntry] {
        var entries: [RemoteFileEntry] = []
        for line in output.components(separatedBy: "\n").dropFirst() {
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
        for line in lines.dropFirst() {
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
}

// MARK: - NIOSSH helper types

/// Host key validator that accepts all host keys.
/// In production, this should show a confirmation dialog to the user.
final class AcceptAllHostKeyDelegate: NIOSSHClientServerAuthenticationDelegate {
    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        validationCompletePromise.succeed(())
    }
}

/// Private key authentication delegate.
final class PrivateKeyDelegate: NIOSSHClientUserAuthenticationDelegate {
    private var authRequest: NIOSSHUserAuthenticationOffer?

    init(username: String, privateKey: NIOSSHPrivateKey) {
        self.authRequest = NIOSSHUserAuthenticationOffer(
            username: username,
            serviceName: "",
            offer: .privateKey(.init(privateKey: privateKey))
        )
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        if let authRequest = authRequest, availableMethods.contains(.publicKey) {
            self.authRequest = nil
            nextChallengePromise.succeed(authRequest)
        } else {
            nextChallengePromise.succeed(nil)
        }
    }
}

/// Channel handler that collects stdout/stderr output from an SSH command execution.
final class OutputCollector: ChannelInboundHandler {
    typealias InboundIn = SSHChannelData

    private var stdoutBuffer = ""
    private var stderrBuffer = ""
    private var exitCode: Int = 0
    private var completionPromise: EventLoopPromise<Int>?
    private let onStdout: ((String) -> Void)?
    private let onStderr: ((String) -> Void)?

    var stdout: String { stdoutBuffer }
    var stderr: String { stderrBuffer }

    init(onStdout: ((String) -> Void)? = nil, onStderr: ((String) -> Void)? = nil) {
        self.onStdout = onStdout
        self.onStderr = onStderr
    }

    func handlerAdded(context: ChannelHandlerContext) {
        completionPromise = context.eventLoop.makePromise(of: Int.self)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = unwrapInboundIn(data)
        if case .byteBuffer(var buffer) = channelData.data {
            let string = buffer.readString(length: buffer.readableBytes) ?? ""
            if channelData.type == .stdErr {
                stderrBuffer += string
                onStderr?(string)
            } else {
                stdoutBuffer += string
                onStdout?(string)
            }
        }
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if let exitStatus = event as? SSHChannelRequestEvent.ExitStatus {
            exitCode = exitStatus.exitStatus
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        completionPromise?.succeed(exitCode)
    }

    func waitForCompletion() async throws -> Int {
        guard let promise = completionPromise else { return 0 }
        return try await promise.futureResult.get()
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
