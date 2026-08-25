import Foundation
import Combine

/// Manages remote preview servers: starts dev servers, detects ports, and provides URLs.
@MainActor
public final class RemotePreviewService: ObservableObject {
    public static let shared = RemotePreviewService()

    @Published public var activePreview: PreviewServer?
    @Published public var isStarting: Bool = false
    @Published public var startLog: [String] = []

    private var previewTask: Task<Void, Never>?
    private let ssh = SSHService.shared

    private init() {}

    /// Start a preview server for the given project.
    public func startPreview(projectPath: String, template: ProjectTemplate) async -> PreviewServer? {
        guard RemotePCStore.shared.isConnected else { return nil }
        isStarting = true
        startLog = []
        defer { isStarting = false }

        let command = devServerCommand(for: template, projectPath: projectPath)
        startLog.append("Starting: \(command)")

        // Execute the dev server command in the background
        // We'll capture output to detect the port
        previewTask = Task {
            do {
                let _ = try await ssh.executeStreaming(
                    command,
                    onStdout: { [weak self] chunk in
                        Task { @MainActor in
                            self?.startLog.append(chunk)
                            // Try to detect port from output
                            self?.detectPort(from: chunk, projectPath: projectPath)
                        }
                    },
                    onStderr: { [weak self] chunk in
                        Task { @MainActor in
                            self?.startLog.append(chunk)
                            self?.detectPort(from: chunk, projectPath: projectPath)
                        }
                    }
                )
            } catch {
                await MainActor.run {
                    self.startLog.append("Error: \(error.localizedDescription)")
                }
            }
        }

        // Wait a few seconds for the server to start and print its port
        try? await Task.sleep(nanoseconds: 5_000_000_000)

        // If we haven't detected a port yet, try scanning common ports
        if activePreview == nil {
            await detectRunningServer(projectPath: projectPath)
        }

        return activePreview
    }

    /// Stop the currently running preview server.
    public func stopPreview() async {
        previewTask?.cancel()
        previewTask = nil
        if let preview = activePreview {
            // Kill the process on the remote PC
            if let pid = preview.processId {
                _ = try? await ssh.execute("taskkill /PID \(pid) /F 2>nul || kill \(pid) 2>/dev/null")
            } else {
                // Kill by port
                _ = try? await ssh.execute("powershell -Command \"Get-NetTCPConnection -LocalPort \(preview.port) -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id \\$_.OwningProcess -Force }\" 2>nul || fuser -k \(preview.port)/tcp 2>/dev/null")
            }
        }
        activePreview = nil
        startLog = []
    }

    /// Returns the preview URL for the active server.
    public var previewURL: String? {
        guard let preview = activePreview else { return nil }
        return preview.url
    }

    // MARK: - Private

    private func devServerCommand(for template: ProjectTemplate, projectPath: String) -> String {
        let escaped = projectPath.replacingOccurrences(of: "'", with: "'\\''")
        let cd = "cd '\(escaped)'"

        switch template {
        case .react:
            // Vite dev server with host 0.0.0.0 for LAN access
            return "\(cd) && npm run dev -- --host 0.0.0.0 2>&1"
        case .web, .html:
            // Try npx serve, or python http.server as fallback
            return "\(cd) && (npx serve -l 3000 --no-clipboard 2>&1 || python -m http.server 3000 --bind 0.0.0.0 2>&1)"
        case .javascript:
            return "\(cd) && npm start 2>&1"
        case .swiftUI, .iosApp:
            // Can't preview iOS apps on a Windows PC
            return "echo 'iOS preview is not available on remote PC. Use GitHub Actions for iOS builds.'"
        case .python:
            return "\(cd) && (python -m http.server 8080 --bind 0.0.0.0 2>&1 || python3 -m http.server 8080 --bind 0.0.0.0 2>&1)"
        case .rust:
            return "\(cd) && cargo run 2>&1"
        case .empty:
            return "echo 'No preview available for empty projects.'"
        }
    }

    private func detectPort(from output: String, projectPath: String) {
        // Common patterns:
        // "Local:   http://localhost:5173/"
        // "Local:   http://127.0.0.1:5173/"
        // "listening on port 3000"
        // "Server running at http://0.0.0.0:8080"
        let patterns = [
            #"https?://(?:localhost|127\.0\.0\.1|0\.0\.0\.0):(\d+)"#,
            #"port\s*(\d+)"#,
            #"listening.*?(\d{4,5})"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: output, options: [], range: NSRange(location: 0, length: output.utf16.count)),
               match.numberOfRanges >= 2 {
                let portStr = (output as NSString).substring(with: match.range(at: 1))
                if let port = Int(portStr), port > 0 {
                    setPreview(port: port, projectPath: projectPath)
                    return
                }
            }
        }
    }

    private func detectRunningServer(projectPath: String) async {
        // Check common dev server ports
        let commonPorts = [3000, 5173, 8080, 4200, 5000, 8000, 8888]
        for port in commonPorts {
            let result = try? await ssh.execute("powershell -Command \"Get-NetTCPConnection -LocalPort \(port) -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 | ForEach-Object { \\\"\\$_.OwningProcess\\\" }\" 2>nul || netstat -an 2>/dev/null | grep ':\(port) ' | grep LISTEN | head -1")
            if let output = result?.stdout.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
                setPreview(port: port, projectPath: projectPath)
                return
            }
        }
    }

    private func setPreview(port: Int, projectPath: String) {
        guard activePreview?.port != port else { return }
        let host = RemotePCStore.shared.activeMachine?.host ?? "localhost"
        let url = "http://\(host):\(port)"
        activePreview = PreviewServer(
            port: port,
            url: url,
            host: host,
            processId: nil,
            projectPath: projectPath
        )
        startLog.append("Preview server detected at \(url)")
    }
}
