import Foundation

/// Sandboxed terminal engine.
///
/// iOS sandboxing does not permit spawning arbitrary shell processes. This engine
/// implements a safe, in-process command set that lets the AI agent perform real,
/// useful work on the project (file inspection, simple text transforms, listing,
/// greps) without leaving the sandbox. Commands outside the whitelist are denied
/// with a clear explanation rather than silently failing.
public final class TerminalEngine {
    public static let shared = TerminalEngine()
    private init() {}

    public struct Result {
        public let output: String
        public let exitCode: Int
    }

    /// Whitelist of supported command prefixes. These are real, working commands.
    private let allowed: [(name: String, handler: (String, String) -> Result)] = [
        ("ls", { args, cwd in
            let path = args.isEmpty ? cwd : TerminalEngine.joinPath(cwd, args)
            if let entries = try? FileManager.default.contentsOfDirectory(atPath: path) {
                let sorted = entries.filter { !$0.hasPrefix(".") }.sorted()
                return Result(output: sorted.joined(separator: "\n"), exitCode: 0)
            }
            return Result(output: "ls: \(path): not found", exitCode: 1)
        }),
        ("pwd", { _, cwd in Result(output: cwd, exitCode: 0) }),
        ("cat", { args, cwd in
            guard !args.isEmpty else { return Result(output: "usage: cat <file>", exitCode: 1) }
            let path = TerminalEngine.joinPath(cwd, args)
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                return Result(output: content, exitCode: 0)
            }
            return Result(output: "cat: \(args): no such file", exitCode: 1)
        }),
        ("wc", { args, cwd in
            guard !args.isEmpty else { return Result(output: "usage: wc <file>", exitCode: 1) }
            let path = TerminalEngine.joinPath(cwd, args)
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines).count
                let words = content.split { $0.isWhitespace }.count
                let bytes = content.utf8.count
                return Result(output: "\(lines) \(words) \(bytes) \(args)", exitCode: 0)
            }
            return Result(output: "wc: \(args): no such file", exitCode: 1)
        }),
        ("head", { args, cwd in
            guard !args.isEmpty else { return Result(output: "usage: head <file>", exitCode: 1) }
            let path = TerminalEngine.joinPath(cwd, args)
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines).prefix(20)
                return Result(output: lines.joined(separator: "\n"), exitCode: 0)
            }
            return Result(output: "head: \(args): no such file", exitCode: 1)
        }),
        ("tail", { args, cwd in
            guard !args.isEmpty else { return Result(output: "usage: tail <file>", exitCode: 1) }
            let path = TerminalEngine.joinPath(cwd, args)
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines).suffix(20)
                return Result(output: lines.joined(separator: "\n"), exitCode: 0)
            }
            return Result(output: "tail: \(args): no such file", exitCode: 1)
        }),
        ("echo", { args, _ in Result(output: args, exitCode: 0) }),
        ("grep", { args, cwd in
            // simple "grep PATTERN FILE" form
            let parts = args.split(separator: " ", maxSplits: 1).map { String($0) }
            guard parts.count >= 2 else { return Result(output: "usage: grep <pattern> <file>", exitCode: 1) }
            let pattern = parts[0]
            let path = TerminalEngine.joinPath(cwd, parts[1])
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
                return Result(output: "grep: \(parts[1]): no such file", exitCode: 1)
            }
            let lines = content.components(separatedBy: .newlines)
            let matches = lines.enumerated().compactMap { idx, line -> String? in
                if line.contains(pattern) { return "\(idx + 1): \(line)" }
                return nil
            }
            return Result(output: matches.joined(separator: "\n"), exitCode: matches.isEmpty ? 1 : 0)
        }),
        ("find", { args, cwd in
            // Simple "find PATH NAME PATTERN" form
            let parts = args.split(separator: " ").map { String($0) }
            var root = cwd
            var namePattern: String? = nil
            var i = 0
            while i < parts.count {
                if parts[i] == "-name" && i + 1 < parts.count {
                    namePattern = parts[i + 1].replacingOccurrences(of: "*", with: "")
                    i += 2
                } else {
                    root = TerminalEngine.joinPath(cwd, parts[i])
                    i += 1
                }
            }
            var found: [String] = []
            TerminalEngine.walk(root) { path in
                if let pat = namePattern {
                    if path.contains(pat) { found.append(path) }
                } else {
                    found.append(path)
                }
            }
            return Result(output: found.prefix(200).joined(separator: "\n"), exitCode: 0)
        }),
        ("tree", { args, cwd in
            let path = args.isEmpty ? cwd : TerminalEngine.joinPath(cwd, args)
            var lines: [String] = []
            TerminalEngine.buildTree(path: path, prefix: "", lines: &lines, maxDepth: 4, currentDepth: 0)
            return Result(output: lines.joined(separator: "\n"), exitCode: 0)
        }),
        ("date", { _, _ in Result(output: ISO8601DateFormatter().string(from: Date()), exitCode: 0) }),
        ("whoami", { _, _ in Result(output: "adventure-coder", exitCode: 0) }),
        ("env", { _, _ in
            let env = ProcessInfo.processInfo.environment
            let keys = env.keys.sorted()
            let masked: [String] = keys.map { key in
                let value = env[key] ?? ""
                if key.lowercased().contains("token") || key.lowercased().contains("key") || key.lowercased().contains("secret") {
                    return "\(key)=<redacted>"
                }
                return "\(key)=\(value)"
            }
            return Result(output: masked.joined(separator: "\n"), exitCode: 0)
        }),
    ]

    public func isAllowed(command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstSpace = trimmed.firstIndex(of: " ") else {
            return allowed.contains { $0.name == trimmed }
        }
        let name = String(trimmed[..<firstSpace])
        return allowed.contains { $0.name == name }
    }

    public func run(command: String, in cwd: String, timeout: TimeInterval = 15) -> Result {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstSpace = trimmed.firstIndex(of: " ") else {
            // No arguments
            if let entry = allowed.first(where: { $0.name == trimmed }) {
                return entry.handler("", cwd)
            }
            return Result(output: "command not found: \(trimmed)", exitCode: 127)
        }
        let name = String(trimmed[..<firstSpace])
        let args = String(trimmed[trimmed.index(after: firstSpace)...])
        if let entry = allowed.first(where: { $0.name == name }) {
            return entry.handler(args, cwd)
        }
        return Result(output: "command not found: \(name)", exitCode: 127)
    }

    /// List of allowed command names, used by the UI to show what's available.
    public var allowedCommands: [String] {
        allowed.map { $0.name }
    }

    private static func joinPath(_ cwd: String, _ relative: String) -> String {
        if relative.hasPrefix("/") { return relative }
        return (cwd as NSString).appendingPathComponent(relative)
    }

    private static func walk(_ root: String, callback: (String) -> Void) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: root) else { return }
        for entry in entries {
            if entry.hasPrefix(".") { continue }
            let full = (root as NSString).appendingPathComponent(entry)
            callback(full)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue {
                walk(full, callback: callback)
            }
        }
    }

    private static func buildTree(path: String, prefix: String, lines: inout [String], maxDepth: Int, currentDepth: Int) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return }
        let sorted = entries.filter { !$0.hasPrefix(".") }.sorted()
        for (idx, entry) in sorted.enumerated() {
            let isLast = idx == sorted.count - 1
            let branch = isLast ? "└── " : "├── "
            lines.append(prefix + branch + entry)
            let full = (path as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue {
                if currentDepth < maxDepth {
                    let newPrefix = prefix + (isLast ? "    " : "│   ")
                    buildTree(path: full, prefix: newPrefix, lines: &lines, maxDepth: maxDepth, currentDepth: currentDepth + 1)
                }
            }
        }
    }
}
