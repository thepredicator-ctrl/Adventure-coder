import Foundation

// MARK: - Terminal, build, test, analysis, diff, preview tools

public struct RunCommandTool: Tool {
    public let definition = ToolDefinition.find("run_command") ?? ToolDefinition(name: "run_command", category: .terminal, summary: "Run command", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let command = parameters["command"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'command'.")
        }
        let timeout = (parameters["timeout"] as? Int) ?? 15
        // Whitelist / sandbox check
        guard TerminalEngine.shared.isAllowed(command: command) else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Command is not in the allowed whitelist. Adventure Coder runs in a sandbox; use the in-app terminal to inspect files, build, and run tests.")
        }
        let ok = await context.requestConfirmation("Run: \(command)?")
        guard ok else { return ToolResult(toolName: definition.name, success: false, output: "", error: "Cancelled.") }
        let result = TerminalEngine.shared.run(command: command, in: context.project.rootPath, timeout: TimeInterval(timeout))
        return ToolResult(toolName: definition.name, success: result.exitCode == 0, output: result.output, error: result.exitCode == 0 ? nil : "Exit code \(result.exitCode)")
    }
}

public struct BuildProjectTool: Tool {
    public let definition = ToolDefinition.find("build_project") ?? ToolDefinition(name: "build_project", category: .build, summary: "Build project", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let configuration = (parameters["configuration"] as? String) ?? "debug"
        // For web projects: try `npm run build`
        // For Swift/iOS: local builds not supported on device; trigger GitHub Actions workflow instead.
        let result = BuildService.shared.build(project: context.project, configuration: configuration)
        switch result {
        case .success(let output):
            return ToolResult(toolName: definition.name, success: true, output: output)
        case .failure(let err):
            return ToolResult(toolName: definition.name, success: false, output: "", error: err)
        }
    }
}

public struct RunTestsTool: Tool {
    public let definition = ToolDefinition.find("run_tests") ?? ToolDefinition(name: "run_tests", category: .test, summary: "Run tests", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let result = BuildService.shared.runTests(project: context.project)
        switch result {
        case .success(let output):
            return ToolResult(toolName: definition.name, success: true, output: output)
        case .failure(let err):
            return ToolResult(toolName: definition.name, success: false, output: "", error: err)
        }
    }
}

public struct AnalyzeLogsTool: Tool {
    public let definition = ToolDefinition.find("analyze_logs") ?? ToolDefinition(name: "analyze_logs", category: .analysis, summary: "Analyze logs", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let logs = parameters["logs"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'logs'.")
        }
        let analysis = LogAnalyzer.analyze(logs)
        let data = try JSONSerialization.data(withJSONObject: analysis, options: [.prettyPrinted])
        return ToolResult(toolName: definition.name, success: true, output: String(data: data, encoding: .utf8) ?? "{}")
    }
}

public struct GenerateDiffTool: Tool {
    public let definition = ToolDefinition.find("generate_diff") ?? ToolDefinition(name: "generate_diff", category: .file, summary: "Generate diff", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let old = parameters["old_text"] as? String,
              let new = parameters["new_text"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'old_text' or 'new_text'.")
        }
        let path = (parameters["path"] as? String) ?? "file"
        let diff = DiffAlgorithm.unifiedDiff(old: old, new: new, path: path)
        return ToolResult(toolName: definition.name, success: true, output: diff)
    }
}

public struct PreviewProjectTool: Tool {
    public let definition = ToolDefinition.find("preview_project") ?? ToolDefinition(name: "preview_project", category: .preview, summary: "Preview project", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let device = (parameters["device"] as? String) ?? "default"
        let summary = PreviewService.shared.summary(project: context.project, device: device)
        return ToolResult(toolName: definition.name, success: true, output: summary)
    }
}

// MARK: - Log analyzer

public enum LogAnalyzer {
    public static func analyze(_ logs: String) -> [String: Any] {
        let lines = logs.components(separatedBy: .newlines)
        var errors: [[String: Any]] = []
        var warnings: [[String: Any]] = []
        var hints: [String] = []
        for (idx, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.contains("error:") || lower.contains("error ") || lower.contains("failed") || lower.contains("fatal") {
                errors.append(["line": idx + 1, "message": line.trimmingCharacters(in: .whitespacesAndNewlines)])
            } else if lower.contains("warning:") || lower.contains("warn ") {
                warnings.append(["line": idx + 1, "message": line.trimmingCharacters(in: .whitespacesAndNewlines)])
            }
            if lower.contains("could not find") {
                hints.append("Check that the referenced file or symbol actually exists in the project.")
            }
            if lower.contains("no such module") {
                hints.append("Add the missing package dependency, or check your import statement.")
            }
            if lower.contains("ambiguous") {
                hints.append("Disambiguate by adding an explicit type annotation.")
            }
        }
        return [
            "errors": errors,
            "warnings": warnings,
            "hints": hints,
            "summary": "\(errors.count) errors, \(warnings.count) warnings"
        ]
    }
}
