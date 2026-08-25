import Foundation

// MARK: - Remote File Tools

public struct RemoteReadFileTool: Tool {
    public let definition = ToolDefinition.find("remote_read_file") ?? ToolDefinition(
        name: "remote_read_file", category: .file, summary: "Read a file on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path'.")
        }
        do {
            let content = try await RemoteFileService.shared.readFile(path)
            return ToolResult(toolName: definition.name, success: true, output: content)
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteWriteFileTool: Tool {
    public let definition = ToolDefinition.find("remote_write_file") ?? ToolDefinition(
        name: "remote_write_file", category: .file, summary: "Write a file on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String,
              let content = parameters["content"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path' or 'content'.")
        }
        if SecretDetector.containsSecrets(content) {
            let ok = await context.requestConfirmation("The content looks like it contains secrets. Write anyway?")
            if !ok { return ToolResult(toolName: definition.name, success: false, output: "", error: "Cancelled: secrets detected.") }
        }
        do {
            try await RemoteFileService.shared.writeFile(path, content: content)
            return ToolResult(toolName: definition.name, success: true, output: "Wrote \(content.count) chars to \(path).")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteEditFileTool: Tool {
    public let definition = ToolDefinition.find("remote_edit_file") ?? ToolDefinition(
        name: "remote_edit_file", category: .file, summary: "Edit a file on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String,
              let find = parameters["find"] as? String,
              let replace = parameters["replace"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path', 'find' or 'replace'.")
        }
        do {
            let diff = try await RemoteFileService.shared.editFile(path, find: find, replace: replace)
            return ToolResult(toolName: definition.name, success: true, output: diff)
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteDeleteFileTool: Tool {
    public let definition = ToolDefinition.find("remote_delete_file") ?? ToolDefinition(
        name: "remote_delete_file", category: .file, summary: "Delete a file on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path'.")
        }
        let ok = await context.requestConfirmation("Delete \(path) on the remote PC?")
        guard ok else { return ToolResult(toolName: definition.name, success: false, output: "", error: "Cancelled.") }
        do {
            try await RemoteFileService.shared.deleteFile(path)
            return ToolResult(toolName: definition.name, success: true, output: "Deleted \(path).")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteCreateDirectoryTool: Tool {
    public let definition = ToolDefinition.find("remote_create_directory") ?? ToolDefinition(
        name: "remote_create_directory", category: .file, summary: "Create a directory on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path'.")
        }
        do {
            try await RemoteFileService.shared.createDirectory(path)
            return ToolResult(toolName: definition.name, success: true, output: "Created directory \(path).")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteMoveFileTool: Tool {
    public let definition = ToolDefinition.find("remote_move_file") ?? ToolDefinition(
        name: "remote_move_file", category: .file, summary: "Move/rename a file on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let from = parameters["from"] as? String,
              let to = parameters["to"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'from' or 'to'.")
        }
        do {
            try await RemoteFileService.shared.moveFile(from, to: to)
            return ToolResult(toolName: definition.name, success: true, output: "Moved \(from) to \(to).")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteCopyFileTool: Tool {
    public let definition = ToolDefinition.find("remote_copy_file") ?? ToolDefinition(
        name: "remote_copy_file", category: .file, summary: "Copy a file on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let from = parameters["from"] as? String,
              let to = parameters["to"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'from' or 'to'.")
        }
        do {
            try await RemoteFileService.shared.copyFile(from, to: to)
            return ToolResult(toolName: definition.name, success: true, output: "Copied \(from) to \(to).")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteListFilesTool: Tool {
    public let definition = ToolDefinition.find("remote_list_files") ?? ToolDefinition(
        name: "remote_list_files", category: .file, summary: "List files on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let path = (parameters["path"] as? String) ?? (RemotePCStore.shared.environment?.workspacePath ?? ".")
        do {
            let entries = try await RemoteFileService.shared.listFiles(path)
            let arr: [[String: Any]] = entries.map { e in
                ["name": e.name, "path": e.path, "is_directory": e.isDirectory, "size": e.size]
            }
            let data = try JSONSerialization.data(withJSONObject: arr, options: [.prettyPrinted])
            return ToolResult(toolName: definition.name, success: true, output: String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteSearchFilesTool: Tool {
    public let definition = ToolDefinition.find("remote_search_files") ?? ToolDefinition(
        name: "remote_search_files", category: .search, summary: "Search files on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let query = parameters["query"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'query'.")
        }
        let dir = (parameters["directory"] as? String) ?? (RemotePCStore.shared.environment?.workspacePath ?? ".")
        do {
            let hits = try await RemoteFileService.shared.searchFiles(query: query, in: dir)
            let arr: [[String: Any]] = hits.map { ["path": $0.path, "line": $0.line, "snippet": $0.snippet] }
            let data = try JSONSerialization.data(withJSONObject: arr, options: [.prettyPrinted])
            return ToolResult(toolName: definition.name, success: true, output: String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

// MARK: - Remote Command / Process Tools

public struct RemoteExecuteCommandTool: Tool {
    public let definition = ToolDefinition.find("remote_execute_command") ?? ToolDefinition(
        name: "remote_execute_command", category: .terminal, summary: "Execute a command on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let command = parameters["command"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'command'.")
        }
        // Safety check: warn if command might modify files outside workspace
        if isPotentiallyDangerous(command) {
            let ok = await context.requestConfirmation("This command may modify files outside the project workspace:\n\n\(command)\n\nRun once?")
            guard ok else { return ToolResult(toolName: definition.name, success: false, output: "", error: "Cancelled by user.") }
        }
        do {
            let result = try await SSHService.shared.execute(command)
            let output = result.stdout + (result.stderr.isEmpty ? "" : "\n[stderr]\n\(result.stderr)") + "\n[exit: \(result.exitCode)]"
            return ToolResult(toolName: definition.name, success: result.success, output: output, error: result.success ? nil : "Exit code \(result.exitCode)")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }

    private func isPotentiallyDangerous(_ command: String) -> Bool {
        let lower = command.lowercased()
        let dangerous = ["rm -rf /", "format ", "del /f", "rd /s", "shutdown", "reboot", ":(){:|:&};:", "mkfs", "dd if=", "> /dev/sd"]
        return dangerous.contains { lower.contains($0) }
    }
}

public struct RemoteStartProcessTool: Tool {
    public let definition = ToolDefinition.find("remote_start_process") ?? ToolDefinition(
        name: "remote_start_process", category: .terminal, summary: "Start a long-running process on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let command = parameters["command"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'command'.")
        }
        guard let cwd = parameters["cwd"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'cwd'.")
        }
        // Start the process in the background, capturing its PID
        let escaped = cwd.replacingOccurrences(of: "'", with: "'\\''")
        let startCmd = "cd '\(escaped)' && nohup \(command) > /tmp/process.log 2>&1 & echo $! 2>/dev/null || powershell -Command \"Start-Process -FilePath '\(command)' -WorkingDirectory '\(escaped)' -PassThru | Select-Object -ExpandProperty Id\""
        do {
            let result = try await SSHService.shared.execute(startCmd)
            let pid = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return ToolResult(toolName: definition.name, success: true, output: "Started process. PID: \(pid)")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteStopProcessTool: Tool {
    public let definition = ToolDefinition.find("remote_stop_process") ?? ToolDefinition(
        name: "remote_stop_process", category: .terminal, summary: "Stop a running process on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let pid = parameters["pid"] as? Int ?? Int((parameters["pid"] as? String) ?? "") else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing or invalid 'pid'.")
        }
        let ok = await context.requestConfirmation("Stop process PID \(pid)?")
        guard ok else { return ToolResult(toolName: definition.name, success: false, output: "", error: "Cancelled.") }
        do {
            _ = try await SSHService.shared.execute("kill \(pid) 2>/dev/null; taskkill /PID \(pid) /F 2>nul")
            return ToolResult(toolName: definition.name, success: true, output: "Stopped process \(pid).")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteGetProcessesTool: Tool {
    public let definition = ToolDefinition.find("remote_get_processes") ?? ToolDefinition(
        name: "remote_get_processes", category: .terminal, summary: "List running processes on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        do {
            let result = try await SSHService.shared.execute("powershell -Command \"Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 Id, Name, CPU, @{N='Mem(MB)';E={[math]::Round($_.WorkingSet/1MB,1)}} | Format-Table -AutoSize\" 2>nul || ps aux --sort=-%cpu | head -20")
            return ToolResult(toolName: definition.name, success: true, output: result.stdout)
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteGetEnvironmentTool: Tool {
    public let definition = ToolDefinition.find("remote_get_environment") ?? ToolDefinition(
        name: "remote_get_environment", category: .analysis, summary: "Get remote PC environment info", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        if let env = RemotePCStore.shared.environment {
            let info: [String: Any] = [
                "os": env.os.displayName,
                "os_version": env.osVersion,
                "shell": env.shell,
                "cpu_architecture": env.cpuArchitecture,
                "cpu_usage_percent": Int(env.cpuUsage * 100),
                "ram_total_gb": String(format: "%.1f", env.ramTotalGB),
                "ram_usage_percent": Int(env.ramUsage * 100),
                "disk_total_gb": String(format: "%.1f", env.diskTotalGB),
                "disk_usage_percent": Int(env.diskUsage * 100),
                "hostname": env.hostname,
                "workspace": env.workspacePath
            ]
            let data = try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted])
            return ToolResult(toolName: definition.name, success: true, output: String(data: data, encoding: .utf8) ?? "{}")
        }
        return ToolResult(toolName: definition.name, success: false, output: "", error: "Not connected to a remote PC.")
    }
}

// MARK: - Remote Build / Test / Install Tools

public struct RemoteInstallDependencyTool: Tool {
    public let definition = ToolDefinition.find("remote_install_dependency") ?? ToolDefinition(
        name: "remote_install_dependency", category: .build, summary: "Install dependencies on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let cwd = parameters["cwd"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'cwd'.")
        }
        let package = (parameters["package"] as? String) ?? ""
        let escaped = cwd.replacingOccurrences(of: "'", with: "'\\''")
        // Detect package manager
        let hasPackageJson = (try? await SSHService.shared.execute("test -f '\(escaped)/package.json' && echo yes || echo no"))?.stdout.contains("yes") ?? false
        let hasCargoToml = (try? await SSHService.shared.execute("test -f '\(escaped)/Cargo.toml' && echo yes || echo no"))?.stdout.contains("yes") ?? false
        let hasRequirementsTxt = (try? await SSHService.shared.execute("test -f '\(escaped)/requirements.txt' && echo yes || echo no"))?.stdout.contains("yes") ?? false

        let cmd: String
        if hasPackageJson {
            cmd = package.isEmpty ? "cd '\(escaped)' && npm install" : "cd '\(escaped)' && npm install \(package)"
        } else if hasCargoToml {
            cmd = package.isEmpty ? "cd '\(escaped)' && cargo build" : "cd '\(escaped)' && cargo add \(package)"
        } else if hasRequirementsTxt {
            cmd = package.isEmpty ? "cd '\(escaped)' && pip install -r requirements.txt" : "cd '\(escaped)' && pip install \(package)"
        } else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Could not detect package manager in \(cwd).")
        }
        do {
            let result = try await SSHService.shared.execute(cmd, timeout: 120)
            let output = result.stdout + (result.stderr.isEmpty ? "" : "\n[stderr]\n\(result.stderr)")
            return ToolResult(toolName: definition.name, success: result.success, output: output, error: result.success ? nil : "Exit code \(result.exitCode)")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteBuildProjectTool: Tool {
    public let definition = ToolDefinition.find("remote_build_project") ?? ToolDefinition(
        name: "remote_build_project", category: .build, summary: "Build the project on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let cwd = parameters["cwd"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'cwd'.")
        }
        let escaped = cwd.replacingOccurrences(of: "'", with: "'\\''")
        let hasPackageJson = (try? await SSHService.shared.execute("test -f '\(escaped)/package.json' && echo yes || echo no"))?.stdout.contains("yes") ?? false
        let hasCargoToml = (try? await SSHService.shared.execute("test -f '\(escaped)/Cargo.toml' && echo yes || echo no"))?.stdout.contains("yes") ?? false

        let cmd: String
        if hasPackageJson {
            cmd = "cd '\(escaped)' && npm run build"
        } else if hasCargoToml {
            cmd = "cd '\(escaped)' && cargo build --release"
        } else {
            cmd = "cd '\(escaped)' && echo 'No build system detected'"
        }
        do {
            let result = try await SSHService.shared.execute(cmd, timeout: 300)
            let output = result.stdout + (result.stderr.isEmpty ? "" : "\n[stderr]\n\(result.stderr)")
            return ToolResult(toolName: definition.name, success: result.success, output: output, error: result.success ? nil : "Exit code \(result.exitCode)")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteRunTestsTool: Tool {
    public let definition = ToolDefinition.find("remote_run_tests") ?? ToolDefinition(
        name: "remote_run_tests", category: .test, summary: "Run tests on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let cwd = parameters["cwd"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'cwd'.")
        }
        let escaped = cwd.replacingOccurrences(of: "'", with: "'\\''")
        let hasPackageJson = (try? await SSHService.shared.execute("test -f '\(escaped)/package.json' && echo yes || echo no"))?.stdout.contains("yes") ?? false
        let hasCargoToml = (try? await SSHService.shared.execute("test -f '\(escaped)/Cargo.toml' && echo yes || echo no"))?.stdout.contains("yes") ?? false
        let hasPytest = (try? await SSHService.shared.execute("test -f '\(escaped)/pytest.ini' -o -f '\(escaped)/setup.cfg' && echo yes || echo no"))?.stdout.contains("yes") ?? false

        let cmd: String
        if hasPackageJson {
            cmd = "cd '\(escaped)' && npm test"
        } else if hasCargoToml {
            cmd = "cd '\(escaped)' && cargo test"
        } else if hasPytest {
            cmd = "cd '\(escaped)' && pytest"
        } else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "No test runner detected.")
        }
        do {
            let result = try await SSHService.shared.execute(cmd, timeout: 120)
            let output = result.stdout + (result.stderr.isEmpty ? "" : "\n[stderr]\n\(result.stderr)")
            return ToolResult(toolName: definition.name, success: result.success, output: output)
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteGetLogsTool: Tool {
    public let definition = ToolDefinition.find("remote_get_logs") ?? ToolDefinition(
        name: "remote_get_logs", category: .analysis, summary: "Get build/runtime logs from the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let logFile = (parameters["log_file"] as? String) ?? "/tmp/process.log"
        do {
            let content = try await RemoteFileService.shared.readFile(logFile)
            return ToolResult(toolName: definition.name, success: true, output: content)
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

// MARK: - Remote Git Tools

public struct RemoteGitStatusTool: Tool {
    public let definition = ToolDefinition.find("remote_git_status") ?? ToolDefinition(
        name: "remote_git_status", category: .git, summary: "Git status on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let cwd = parameters["cwd"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'cwd'.")
        }
        let escaped = cwd.replacingOccurrences(of: "'", with: "'\\''")
        do {
            let result = try await SSHService.shared.execute("cd '\(escaped)' && git status")
            return ToolResult(toolName: definition.name, success: result.success, output: result.stdout)
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteGitDiffTool: Tool {
    public let definition = ToolDefinition.find("remote_git_diff") ?? ToolDefinition(
        name: "remote_git_diff", category: .git, summary: "Git diff on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let cwd = parameters["cwd"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'cwd'.")
        }
        let escaped = cwd.replacingOccurrences(of: "'", with: "'\\''")
        let staged = (parameters["staged"] as? Bool) ?? false
        let cmd = staged ? "cd '\(escaped)' && git diff --cached" : "cd '\(escaped)' && git diff"
        do {
            let result = try await SSHService.shared.execute(cmd)
            return ToolResult(toolName: definition.name, success: true, output: result.stdout)
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteGitCommitTool: Tool {
    public let definition = ToolDefinition.find("remote_git_commit") ?? ToolDefinition(
        name: "remote_git_commit", category: .git, summary: "Git commit on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let cwd = parameters["cwd"] as? String,
              let message = parameters["message"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'cwd' or 'message'.")
        }
        if SecretDetector.containsSecrets(message) {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Commit message contains secrets.")
        }
        let ok = await context.requestConfirmation("Commit all changes on remote PC with message: \(message)?")
        guard ok else { return ToolResult(toolName: definition.name, success: false, output: "", error: "Cancelled.") }
        let escaped = cwd.replacingOccurrences(of: "'", with: "'\\''")
        let msgEsc = message.replacingOccurrences(of: "\"", with: "\\\"")
        do {
            let result = try await SSHService.shared.execute("cd '\(escaped)' && git add -A && git commit -m \"\(msgEsc)\"")
            return ToolResult(toolName: definition.name, success: result.success, output: result.stdout)
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteGitPushTool: Tool {
    public let definition = ToolDefinition.find("remote_git_push") ?? ToolDefinition(
        name: "remote_git_push", category: .git, summary: "Git push from the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let cwd = parameters["cwd"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'cwd'.")
        }
        let ok = await context.requestConfirmation("Push changes from the remote PC to GitHub?")
        guard ok else { return ToolResult(toolName: definition.name, success: false, output: "", error: "Cancelled.") }
        let escaped = cwd.replacingOccurrences(of: "'", with: "'\\''")
        do {
            let result = try await SSHService.shared.execute("cd '\(escaped)' && git push", timeout: 60)
            return ToolResult(toolName: definition.name, success: result.success, output: result.stdout)
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct RemoteGitPullTool: Tool {
    public let definition = ToolDefinition.find("remote_git_pull") ?? ToolDefinition(
        name: "remote_git_pull", category: .git, summary: "Git pull on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let cwd = parameters["cwd"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'cwd'.")
        }
        let ok = await context.requestConfirmation("Pull changes from GitHub to the remote PC?")
        guard ok else { return ToolResult(toolName: definition.name, success: false, output: "", error: "Cancelled.") }
        let escaped = cwd.replacingOccurrences(of: "'", with: "'\\''")
        do {
            let result = try await SSHService.shared.execute("cd '\(escaped)' && git pull", timeout: 60)
            return ToolResult(toolName: definition.name, success: result.success, output: result.stdout)
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

// MARK: - Remote Preview Tools

public struct RemoteStartPreviewTool: Tool {
    public let definition = ToolDefinition.find("remote_start_preview") ?? ToolDefinition(
        name: "remote_start_preview", category: .preview, summary: "Start a preview server on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let cwd = parameters["cwd"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'cwd'.")
        }
        let template = ProjectTemplate(rawValue: (parameters["template"] as? String) ?? "web") ?? .web
        let preview = await RemotePreviewService.shared.startPreview(projectPath: cwd, template: template)
        if let preview = preview {
            return ToolResult(toolName: definition.name, success: true, output: "Preview server running at \(preview.url)")
        }
        return ToolResult(toolName: definition.name, success: false, output: "", error: "Could not detect preview server port.")
    }
}

public struct RemoteStopPreviewTool: Tool {
    public let definition = ToolDefinition.find("remote_stop_preview") ?? ToolDefinition(
        name: "remote_stop_preview", category: .preview, summary: "Stop the preview server on the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        await RemotePreviewService.shared.stopPreview()
        return ToolResult(toolName: definition.name, success: true, output: "Preview server stopped.")
    }
}

// MARK: - Remote Download Tool

public struct RemoteDownloadProjectTool: Tool {
    public let definition = ToolDefinition.find("remote_download_project") ?? ToolDefinition(
        name: "remote_download_project", category: .file, summary: "Download project source as ZIP from the remote PC", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path'.")
        }
        do {
            let zipURL = try await RemoteDownloadService.shared.downloadProjectSource(at: path)
            if let saved = RemoteDownloadService.shared.saveToFilesApp(zipURL) {
                return ToolResult(toolName: definition.name, success: true, output: "Downloaded project source to \(saved.lastPathComponent). Available in Files app → Adventure Coder → Downloads.")
            }
            return ToolResult(toolName: definition.name, success: true, output: "Downloaded to \(zipURL.path)")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}
