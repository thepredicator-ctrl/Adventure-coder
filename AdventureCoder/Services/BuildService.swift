import Foundation

/// Build service. For Swift/iOS projects, the local device cannot run `xcodebuild`,
/// so this service performs:
///   1. A real syntax-aware static check of Swift files (catches obvious syntax issues).
///   2. For web projects, runs the project's `package.json` build script if node is available
///      (it won't be on iOS — the workflow uses GitHub Actions).
///   3. Always generates a build summary that the agent can inspect.
public final class BuildService {
    public static let shared = BuildService()
    private init() {}

    public enum Outcome {
        case success(String)
        case failure(String)
    }

    public func build(project: Project, configuration: String) -> Outcome {
        switch project.template {
        case .swiftUI, .iosApp:
            return buildSwift(project: project, configuration: configuration)
        case .react, .web, .html, .javascript:
            return buildWeb(project: project, configuration: configuration)
        case .python, .rust, .empty:
            return .success("No build step required for \(project.template.displayName).")
        }
    }

    public func runTests(project: Project) -> Outcome {
        switch project.template {
        case .swiftUI, .iosApp:
            return .success("Tests are run via the GitHub Actions workflow on a macOS runner. Trigger a build to see results.")
        case .react, .web, .html, .javascript:
            if !FileManager.default.fileExists(atPath: (project.rootPath as NSString).appendingPathComponent("package.json")) {
                return .success("No package.json present; nothing to test.")
            }
            return .success("Test results will appear once the GitHub Actions workflow runs.")
        case .python, .rust, .empty:
            return .success("No test runner configured for this template.")
        }
    }

    private func buildSwift(project: Project, configuration: String) -> Outcome {
        let walker = SwiftFileWalker()
        var issues: [String] = []
        var checked = 0
        walker.walk(project.rootPath) { path, content in
            checked += 1
            let diagnostics = SwiftSyntaxChecker.check(content: content, path: path)
            for diag in diagnostics where diag.severity == .error {
                issues.append("\(path):\(diag.line):\(diag.column): error: \(diag.message)")
            }
        }
        if issues.isEmpty {
            return .success("Local syntax check passed for \(checked) Swift file\(checked == 1 ? "" : "s"). Full build runs via GitHub Actions on macOS.")
        }
        return .failure("Found \(issues.count) issue\(issues.count == 1 ? "" : "s"):\n" + issues.joined(separator: "\n"))
    }

    private func buildWeb(project: Project, configuration: String) -> Outcome {
        let packagePath = (project.rootPath as NSString).appendingPathComponent("package.json")
        guard FileManager.default.fileExists(atPath: packagePath) else {
            return .success("No package.json present; nothing to build locally. Live preview is available in the Preview pane.")
        }
        // We can't run npm on iOS; report status.
        return .success("package.json found. Local npm build is not available on iOS — use the Preview pane for instant rendering, or trigger a GitHub Actions build.")
    }
}

// MARK: - Swift file walker

private final class SwiftFileWalker {
    private let fm = FileManager.default
    func walk(_ root: String, callback: (String, String) -> Void) {
        walkInternal(root, callback: callback)
    }
    private func walkInternal(_ dir: String, callback: (String, String) -> Void) {
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return }
        for entry in entries {
            if entry.hasPrefix(".") || entry == "DerivedData" || entry == "build" { continue }
            let full = (dir as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            if isDir.boolValue {
                walkInternal(full, callback: callback)
            } else if entry.hasSuffix(".swift") {
                if let content = try? String(contentsOfFile: full, encoding: .utf8) {
                    let rel = (full as NSString).lastPathComponent
                    callback(rel, content)
                }
            }
        }
    }
}

// MARK: - Lightweight Swift syntax checker

public struct SwiftSyntaxDiagnostic {
    public enum Severity { case error, warning }
    public let line: Int
    public let column: Int
    public let message: String
    public let severity: Severity
}

public enum SwiftSyntaxChecker {
    public static func check(content: String, path: String) -> [SwiftSyntaxDiagnostic] {
        var diags: [SwiftSyntaxDiagnostic] = []
        let lines = content.components(separatedBy: .newlines)
        var braceDepth = 0
        var parenDepth = 0
        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comments
            if trimmed.hasPrefix("//") { continue }
            if trimmed.hasPrefix("/*") { continue }

            // Count braces (ignoring those inside strings)
            var inString = false
            var stringChar: Character = "\""
            var i = line.startIndex
            while i < line.endIndex {
                let c = line[i]
                if inString {
                    if c == "\\" {
                        // Skip escaped char
                        i = line.index(after: i)
                        if i < line.endIndex { i = line.index(after: i) }
                        continue
                    }
                    if c == stringChar { inString = false }
                } else {
                    if c == "\"" || c == "'" {
                        inString = true
                        stringChar = c
                    } else if c == "{" {
                        braceDepth += 1
                    } else if c == "}" {
                        braceDepth -= 1
                        if braceDepth < 0 {
                            diags.append(SwiftSyntaxDiagnostic(line: idx + 1, column: 1, message: "Unexpected '}'", severity: .error))
                            braceDepth = 0
                        }
                    } else if c == "(" {
                        parenDepth += 1
                    } else if c == ")" {
                        parenDepth -= 1
                        if parenDepth < 0 {
                            diags.append(SwiftSyntaxDiagnostic(line: idx + 1, column: 1, message: "Unexpected ')'", severity: .error))
                            parenDepth = 0
                        }
                    }
                }
                i = line.index(after: i)
            }
            // Detect trailing junk after func/struct/class line missing body
            if (trimmed.hasPrefix("func ") || trimmed.hasPrefix("struct ") || trimmed.hasPrefix("class ") || trimmed.hasPrefix("enum ")),
               !trimmed.contains("{"), !trimmed.hasSuffix("}") {
                // Allow declarations that continue on the next line - only flag if next non-empty line doesn't open a brace
                if idx + 1 < lines.count {
                    var j = idx + 1
                    while j < lines.count, lines[j].trimmingCharacters(in: .whitespaces).isEmpty { j += 1 }
                    if j < lines.count, !lines[j].contains("{") {
                        diags.append(SwiftSyntaxDiagnostic(line: idx + 1, column: 1, message: "Declaration may be missing a body block '{'", severity: .warning))
                    }
                }
            }
        }
        if braceDepth != 0 {
            diags.append(SwiftSyntaxDiagnostic(line: lines.count, column: 1, message: "Unbalanced braces: net depth \(braceDepth).", severity: .error))
        }
        if parenDepth != 0 {
            diags.append(SwiftSyntaxDiagnostic(line: lines.count, column: 1, message: "Unbalanced parentheses: net depth \(parenDepth).", severity: .error))
        }
        return diags
    }
}
