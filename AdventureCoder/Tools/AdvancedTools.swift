import Foundation

// MARK: - Advanced Analysis Tools

public struct AnalyzeComplexityTool: Tool {
    public let definition = ToolDefinition.find("analyze_complexity") ?? ToolDefinition(
        name: "analyze_complexity", category: .analysis, summary: "Analyze code complexity", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path'.")
        }
        let abs = FileSystem.shared.join(context.project.rootPath, path)
        guard let content = try? FileSystem.shared.read(abs) else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Could not read file.")
        }
        let metrics = CodeComplexityAnalyzer.shared.analyzeSwift(content: content, fileName: path)
        let hotspots = metrics.functions.filter { $0.isHotspot }

        var output = "File: \(path)\n"
        output += "Maintainability Index: \(String(format: "%.1f", metrics.maintainabilityIndex)) (Grade: \(metrics.grade.rawValue.uppercased()))\n"
        output += "Total Lines: \(metrics.totalLines)\n"
        output += "Code Lines: \(metrics.codeLines)\n"
        output += "Comment Lines: \(metrics.commentLines)\n"
        output += "Functions: \(metrics.functions.count)\n\n"

        if !hotspots.isEmpty {
            output += "⚠️  Hotspots (complexity > 10):\n"
            for hs in hotspots {
                output += "  \(hs.name) (line \(hs.line)): cyclomatic=\(hs.cyclomaticComplexity), cognitive=\(hs.cognitiveComplexity)\n"
            }
        }

        return ToolResult(toolName: definition.name, success: true, output: output)
    }
}

public struct DetectDuplicatesTool: Tool {
    public let definition = ToolDefinition.find("detect_duplicates") ?? ToolDefinition(
        name: "detect_duplicates", category: .analysis, summary: "Detect duplicate code", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path'.")
        }
        let abs = FileSystem.shared.join(context.project.rootPath, path)
        let files = collectFiles(at: abs)
        let duplicates = DuplicateDetector.shared.findDuplicates(in: files)

        if duplicates.isEmpty {
            return ToolResult(toolName: definition.name, success: true, output: "No duplicates found.")
        }

        var output = "Found \(duplicates.count) duplicate block(s):\n\n"
        for dup in duplicates {
            output += "  \(dup.originalFile):\(dup.originalLine) → \(dup.duplicateFile):\(dup.duplicateLine)\n"
            output += "    Similarity: \(String(format: "%.0f%%", dup.similarity * 100)), Tokens: \(dup.tokenCount)\n"
        }
        return ToolResult(toolName: definition.name, success: true, output: output)
    }

    private func collectFiles(at path: String) -> [(name: String, content: String)] {
        var files: [(String, String)] = []
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        for entry in entries {
            if entry.hasPrefix(".") || entry == "node_modules" || entry == "DerivedData" { continue }
            let full = (path as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            if isDir.boolValue {
                files.append(contentsOf: collectFiles(at: full))
            } else if let content = try? String(contentsOfFile: full, encoding: .utf8) {
                files.append((entry, content))
            }
        }
        return files
    }
}

public struct DetectDeadCodeTool: Tool {
    public let definition = ToolDefinition.find("detect_dead_code") ?? ToolDefinition(
        name: "detect_dead_code", category: .analysis, summary: "Detect dead code", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path'.")
        }
        let abs = FileSystem.shared.join(context.project.rootPath, path)
        guard let content = try? FileSystem.shared.read(abs) else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Could not read file.")
        }
        let allFiles = collectFiles(at: context.project.rootPath)
        let deadCode = DeadCodeDetector.shared.detect(in: content, fileName: path, allFiles: allFiles)

        if deadCode.isEmpty {
            return ToolResult(toolName: definition.name, success: true, output: "No dead code detected.")
        }

        var output = "Found \(deadCode.count) dead code item(s):\n\n"
        for item in deadCode {
            output += "  [\(item.type.rawValue)] \(item.file):\(item.line) — \(item.name)\n"
            output += "    \(item.suggestion)\n"
        }
        return ToolResult(toolName: definition.name, success: true, output: output)
    }

    private func collectFiles(at path: String) -> [(name: String, content: String)] {
        var files: [(String, String)] = []
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        for entry in entries {
            if entry.hasPrefix(".") || entry == "node_modules" || entry == "DerivedData" { continue }
            let full = (path as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            if isDir.boolValue {
                files.append(contentsOf: collectFiles(at: full))
            } else if let content = try? String(contentsOfFile: full, encoding: .utf8) {
                files.append((entry, content))
            }
        }
        return files
    }
}

public struct CalculateMetricsTool: Tool {
    public let definition = ToolDefinition.find("calculate_metrics") ?? ToolDefinition(
        name: "calculate_metrics", category: .analysis, summary: "Calculate code metrics", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let metrics = CodeMetricsCalculator.shared.calculate(for: context.project.rootPath)

        var output = "Project Metrics:\n"
        output += "  Total files: \(metrics.totalFiles)\n"
        output += "  Total lines: \(metrics.totalLines)\n"
        output += "  Source lines: \(metrics.sourceLines)\n"
        output += "  Comment lines: \(metrics.commentLines)\n"
        output += "  Comment density: \(String(format: "%.1f%%", metrics.commentDensity * 100))\n"
        output += "  Functions: \(metrics.totalFunctions)\n"
        output += "  Classes: \(metrics.totalClasses)\n"
        output += "  Structs: \(metrics.totalStructs)\n"
        output += "  Enums: \(metrics.totalEnums)\n"
        output += "  Protocols: \(metrics.totalProtocols)\n"
        output += "  Extensions: \(metrics.totalExtensions)\n\n"
        output += "Languages:\n"
        for (lang, count) in metrics.languages.sorted(by: { $0.value > $1.value }) {
            output += "  \(lang): \(count) files\n"
        }
        output += "\nFile Types:\n"
        for (type, count) in metrics.byFileType.sorted(by: { $0.value > $1.value }) {
            output += "  .\(type): \(count) files\n"
        }
        return ToolResult(toolName: definition.name, success: true, output: output)
    }
}

public struct FormatCodeTool: Tool {
    public let definition = ToolDefinition.find("format_code") ?? ToolDefinition(
        name: "format_code", category: .file, summary: "Format code", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path'.")
        }
        let abs = FileSystem.shared.join(context.project.rootPath, path)
        guard let content = try? FileSystem.shared.read(abs) else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Could not read file.")
        }
        let ext = (path as NSString).pathExtension.lowercased()
        let language = Language.forExtension(ext)
        let formatted = CodeFormatter.shared.format(content, language: language)
        try? FileSystem.shared.write(abs, content: formatted)

        let diff = DiffAlgorithm.unifiedDiff(old: content, new: formatted, path: path)
        return ToolResult(toolName: definition.name, success: true, output: "Formatted \(path).\n\n\(diff)")
    }
}

public struct LintCodeTool: Tool {
    public let definition = ToolDefinition.find("lint_code") ?? ToolDefinition(
        name: "lint_code", category: .analysis, summary: "Lint code for issues", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path'.")
        }
        let abs = FileSystem.shared.join(context.project.rootPath, path)
        guard let content = try? FileSystem.shared.read(abs) else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Could not read file.")
        }
        let ext = (path as NSString).pathExtension.lowercased()
        let language = Language.forExtension(ext)
        let findings = CodeLinter.shared.lint(content, fileName: path, language: language)

        if findings.isEmpty {
            return ToolResult(toolName: definition.name, success: true, output: "No lint issues found in \(path).")
        }

        var output = "Found \(findings.count) lint issue(s):\n\n"
        for finding in findings {
            output += "  [\(finding.severity.rawValue)] \(finding.file):\(finding.line) — \(finding.rule)\n"
            output += "    \(finding.message)\n"
            if let suggestion = finding.suggestion {
                output += "    Suggestion: \(suggestion)\n"
            }
        }
        return ToolResult(toolName: definition.name, success: true, output: output)
    }
}

public struct GenerateTestsTool: Tool {
    public let definition = ToolDefinition.find("generate_tests") ?? ToolDefinition(
        name: "generate_tests", category: .test, summary: "Generate unit tests", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path'.")
        }
        let abs = FileSystem.shared.join(context.project.rootPath, path)
        guard let content = try? FileSystem.shared.read(abs) else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Could not read file.")
        }
        // Extract function names
        let functionPattern = #"func\s+(test\w+)?(\w+)\s*\("#
        var functionNames: [String] = []
        if let regex = try? NSRegularExpression(pattern: functionPattern) {
            let ns = content as NSString
            regex.enumerateMatches(in: content, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
                guard let match = match, match.numberOfRanges >= 3 else { return }
                let name = ns.substring(with: match.range(at: 2))
                if name != "init" && name != "deinit" {
                    functionNames.append(name)
                }
            }
        }

        let fileName = (path as NSString).lastPathComponent
        let testName = fileName.replacingOccurrences(of: ".swift", with: "") + "Tests"

        var testContent = "import XCTest\n"
        testContent += "@testable import AdventureCoder\n\n"
        testContent += "final class \(testName): XCTestCase {\n\n"

        for funcName in functionNames {
            testContent += "    func test_\(funcName)_happyPath() {\n"
            testContent += "        // TODO: Implement test for \(funcName)\n"
            testContent += "        // Arrange\n"
            testContent += "        // Act\n"
            testContent += "        // Assert\n"
            testContent += "    }\n\n"

            testContent += "    func test_\(funcName)_edgeCase() {\n"
            testContent += "        // TODO: Test edge cases for \(funcName)\n"
            testContent += "    }\n\n"

            testContent += "    func test_\(funcName)_errorCase() {\n"
            testContent += "        // TODO: Test error paths for \(funcName)\n"
            testContent += "    }\n\n"
        }

        testContent += "}\n"

        let testPath = (path as NSString).deletingLastPathComponent + "/" + testName + ".swift"
        let testAbs = FileSystem.shared.join(context.project.rootPath, testPath)
        try? FileSystem.shared.write(testAbs, content: testContent)

        return ToolResult(toolName: definition.name, success: true, output: "Generated \(functionNames.count * 3) test cases for \(functionNames.count) functions.\nTest file: \(testPath)")
    }
}

public struct SecurityScanTool: Tool {
    public let definition = ToolDefinition.find("security_scan") ?? ToolDefinition(
        name: "security_scan", category: .analysis, summary: "Scan for security issues", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path'.")
        }
        let abs = FileSystem.shared.join(context.project.rootPath, path)
        guard let content = try? FileSystem.shared.read(abs) else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Could not read file.")
        }

        var issues: [String] = []
        let lines = content.components(separatedBy: .newlines)

        // Check for secrets
        let secretHits = SecretDetector.scan(content)
        for hit in secretHits {
            issues.append("  [SECRET] Line \(hit.lineNumber): \(hit.kind.rawValue) — \(hit.snippet.prefix(40))...")
        }

        // Check for insecure patterns
        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("http://") && !trimmed.contains("localhost") && !trimmed.hasPrefix("//") {
                issues.append("  [INSECURE] Line \(idx + 1): HTTP URL (use HTTPS)")
            }
            if trimmed.contains("eval(") {
                issues.append("  [DANGER] Line \(idx + 1): eval() usage is dangerous")
            }
            if trimmed.contains("force_try") || trimmed.contains("try!") {
                issues.append("  [WARNING] Line \(idx + 1): Force try can crash")
            }
            if trimmed.contains("NSThread.sleep") || trimmed.contains("Thread.sleep") {
                issues.append("  [WARNING] Line \(idx + 1): Thread.sleep blocks execution")
            }
        }

        if issues.isEmpty {
            return ToolResult(toolName: definition.name, success: true, output: "No security issues found in \(path).")
        }

        return ToolResult(toolName: definition.name, success: true, output: "Found \(issues.count) security issue(s):\n" + issues.joined(separator: "\n"))
    }
}

public struct DependencyScanTool: Tool {
    public let definition = ToolDefinition.find("dependency_scan") ?? ToolDefinition(
        name: "dependency_scan", category: .analysis, summary: "Scan dependencies", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let root = context.project.rootPath
        var dependencies: [String] = []

        // Check for Package.swift
        let packagePath = (root as NSString).appendingPathComponent("Package.swift")
        if let content = try? String(contentsOfFile: packagePath, encoding: .utf8) {
            dependencies.append("Swift Package Manager:")
            // Extract package URLs
            let pattern = #"url:\s*"([^"]+)""#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let ns = content as NSString
                regex.enumerateMatches(in: content, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
                    if let match = match, match.numberOfRanges >= 2 {
                        dependencies.append("  - \(ns.substring(with: match.range(at: 1)))")
                    }
                }
            }
        }

        // Check for package.json
        let npmPath = (root as NSString).appendingPathComponent("package.json")
        if let content = try? String(contentsOfFile: npmPath, encoding: .utf8),
           let json = try? JSONSerialization.jsonObject(with: content.data(using: .utf8)!) as? [String: Any] {
            dependencies.append("npm:")
            if let deps = json["dependencies"] as? [String: String] {
                for (name, version) in deps.sorted(by: { $0.key < $1.key }) {
                    dependencies.append("  - \(name)@\(version)")
                }
            }
            if let devDeps = json["devDependencies"] as? [String: String] {
                dependencies.append("Dev dependencies:")
                for (name, version) in devDeps.sorted(by: { $0.key < $1.key }) {
                    dependencies.append("  - \(name)@\(version)")
                }
            }
        }

        // Check for requirements.txt
        let pipPath = (root as NSString).appendingPathComponent("requirements.txt")
        if let content = try? String(contentsOfFile: pipPath, encoding: .utf8) {
            dependencies.append("Python:")
            for line in content.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                    dependencies.append("  - \(trimmed)")
                }
            }
        }

        // Check for Cargo.toml
        let cargoPath = (root as NSString).appendingPathComponent("Cargo.toml")
        if let content = try? String(contentsOfFile: cargoPath, encoding: .utf8) {
            dependencies.append("Cargo:")
            var inDeps = false
            for line in content.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed == "[dependencies]" { inDeps = true; continue }
                if trimmed.hasPrefix("[") { inDeps = false; continue }
                if inDeps && !trimmed.isEmpty {
                    dependencies.append("  - \(trimmed)")
                }
            }
        }

        if dependencies.isEmpty {
            return ToolResult(toolName: definition.name, success: true, output: "No dependency files found.")
        }

        return ToolResult(toolName: definition.name, success: true, output: dependencies.joined(separator: "\n"))
    }
}

public struct GenerateChangelogTool: Tool {
    public let definition = ToolDefinition.find("generate_changelog") ?? ToolDefinition(
        name: "generate_changelog", category: .file, summary: "Generate changelog", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let historyResult = GitService.shared.history(project: context.project, limit: 50)
        guard case .success(let commits) = historyResult else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Could not read git history.")
        }

        var added: [String] = []
        var changed: [String] = []
        var fixed: [String] = []
        var removed: [String] = []
        var security: [String] = []

        for commit in commits {
            let msg = commit.message.lowercased()
            if msg.hasPrefix("add") || msg.hasPrefix("feat") {
                added.append(commit.message)
            } else if msg.hasPrefix("fix") || msg.hasPrefix("bugfix") {
                fixed.append(commit.message)
            } else if msg.hasPrefix("remove") || msg.hasPrefix("delete") {
                removed.append(commit.message)
            } else if msg.hasPrefix("security") || msg.hasPrefix("cve") {
                security.append(commit.message)
            } else {
                changed.append(commit.message)
            }
        }

        var changelog = "# Changelog\n\n"
        changelog += "## [Unreleased]\n\n"

        if !added.isEmpty {
            changelog += "### Added\n"
            for item in added { changelog += "- \(item)\n" }
            changelog += "\n"
        }
        if !changed.isEmpty {
            changelog += "### Changed\n"
            for item in changed { changelog += "- \(item)\n" }
            changelog += "\n"
        }
        if !fixed.isEmpty {
            changelog += "### Fixed\n"
            for item in fixed { changelog += "- \(item)\n" }
            changelog += "\n"
        }
        if !removed.isEmpty {
            changelog += "### Removed\n"
            for item in removed { changelog += "- \(item)\n" }
            changelog += "\n"
        }
        if !security.isEmpty {
            changelog += "### Security\n"
            for item in security { changelog += "- \(item)\n" }
            changelog += "\n"
        }

        return ToolResult(toolName: definition.name, success: true, output: changelog)
    }
}

public struct GenerateDocsTool: Tool {
    public let definition = ToolDefinition.find("generate_docs") ?? ToolDefinition(
        name: "generate_docs", category: .file, summary: "Generate documentation", description: "")
    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path'.")
        }
        let abs = FileSystem.shared.join(context.project.rootPath, path)
        guard var content = try? FileSystem.shared.read(abs) else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Could not read file.")
        }

        let lines = content.components(separatedBy: .newlines)
        var documentedLines: [String] = []
        var pendingDoc: String? = nil

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect function/class/struct/enum declarations
            if trimmed.hasPrefix("func ") || trimmed.hasPrefix("class ") || trimmed.hasPrefix("struct ") || trimmed.hasPrefix("enum ") || trimmed.hasPrefix("protocol ") {
                let parts = trimmed.split(separator: " ", maxSplits: 2)
                if parts.count >= 2 {
                    let keyword = String(parts[0])
                    let name = String(parts[1]).split(separator: "(").first.map { String($0) } ?? String(parts[1])
                    let docComment = "/// \(keyword.capitalized) `\(name)`.\n///\n/// Description: TODO\n/// - Parameters: TODO\n/// - Returns: TODO\n"
                    documentedLines.append(docComment + line)
                    continue
                }
            }
            documentedLines.append(line)
        }

        let documented = documentedLines.joined(separator: "\n")
        try? FileSystem.shared.write(abs, content: documented)

        return ToolResult(toolName: definition.name, success: true, output: "Added documentation comments to \(path).")
    }
}
