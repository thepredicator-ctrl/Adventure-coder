import Foundation

// MARK: - File tools

public struct ReadFileTool: Tool {
    public let definition = ToolDefinition.find("read_file") ?? ToolDefinition(
        name: "read_file", category: .file, summary: "Read a file", description: "")
    private let fs: FileSystem
    public init(fs: FileSystem) { self.fs = fs }

    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path' parameter.")
        }
        let absolute = fs.join(context.project.rootPath, path)
        do {
            let content = try fs.read(absolute)
            return ToolResult(toolName: definition.name, success: true, output: content)
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct WriteFileTool: Tool {
    public let definition = ToolDefinition.find("write_file") ?? ToolDefinition(
        name: "write_file", category: .file, summary: "Write a file", description: "")
    private let fs: FileSystem
    public init(fs: FileSystem) { self.fs = fs }

    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String,
              let content = parameters["content"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path' or 'content'.")
        }
        if SecretDetector.containsSecrets(content) {
            let ok = await context.requestConfirmation("The content you're about to write looks like it contains a secret (API key, token, etc.). Write anyway?")
            if !ok {
                return ToolResult(toolName: definition.name, success: false, output: "", error: "Write cancelled because secrets were detected.")
            }
        }
        let absolute = fs.join(context.project.rootPath, path)
        do {
            try fs.write(absolute, content: content)
            return ToolResult(toolName: definition.name, success: true, output: "Wrote \(content.count) characters to \(path).")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct EditFileTool: Tool {
    public let definition = ToolDefinition.find("edit_file") ?? ToolDefinition(
        name: "edit_file", category: .file, summary: "Edit a file", description: "")
    private let fs: FileSystem
    public init(fs: FileSystem) { self.fs = fs }

    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String,
              let find = parameters["find"] as? String,
              let replace = parameters["replace"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path', 'find' or 'replace'.")
        }
        let absolute = fs.join(context.project.rootPath, path)
        do {
            let original = try fs.read(absolute)
            guard original.contains(find) else {
                return ToolResult(toolName: definition.name, success: false, output: "", error: "The text to find was not present in \(path).")
            }
            let modified = original.replacingOccurrences(of: find, with: replace)
            try fs.write(absolute, content: modified)
            let diff = DiffAlgorithm.unifiedDiff(old: original, new: modified, path: path)
            return ToolResult(toolName: definition.name, success: true, output: "Edited \(path).\n\n\(diff)")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct DeleteFileTool: Tool {
    public let definition = ToolDefinition.find("delete_file") ?? ToolDefinition(
        name: "delete_file", category: .file, summary: "Delete a file", description: "")
    private let fs: FileSystem
    public init(fs: FileSystem) { self.fs = fs }

    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let path = parameters["path"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'path'.")
        }
        let ok = await context.requestConfirmation("Delete \(path)? This cannot be undone.")
        guard ok else { return ToolResult(toolName: definition.name, success: false, output: "", error: "Cancelled.") }
        let absolute = fs.join(context.project.rootPath, path)
        do {
            try fs.delete(absolute)
            return ToolResult(toolName: definition.name, success: true, output: "Deleted \(path).")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct ListFilesTool: Tool {
    public let definition = ToolDefinition.find("list_files") ?? ToolDefinition(
        name: "list_files", category: .file, summary: "List files", description: "")
    private let fs: FileSystem
    public init(fs: FileSystem) { self.fs = fs }

    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let path = (parameters["path"] as? String) ?? "."
        let absolute = fs.join(context.project.rootPath, path)
        do {
            let nodes = try fs.list(directory: absolute)
            let serialized = nodes.map { node in
                return [
                    "name": node.name,
                    "path": node.relativePath,
                    "is_directory": node.isDirectory,
                    "size": node.size
                ]
            }
            let data = try JSONSerialization.data(withJSONObject: serialized, options: [.prettyPrinted])
            return ToolResult(toolName: definition.name, success: true, output: String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct SearchFilesTool: Tool {
    public let definition = ToolDefinition.find("search_files") ?? ToolDefinition(
        name: "search_files", category: .search, summary: "Search file contents", description: "")
    private let fs: FileSystem
    public init(fs: FileSystem) { self.fs = fs }

    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let query = parameters["query"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'query'.")
        }
        let extensions = (parameters["extensions"] as? String)?
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
        do {
            let hits = try fs.search(query: query, in: context.project.rootPath, extensions: extensions)
            let serialized = hits.map { hit in
                [
                    "path": hit.relativePath,
                    "line": hit.line,
                    "column": hit.column,
                    "snippet": hit.snippet
                ]
            }
            let data = try JSONSerialization.data(withJSONObject: serialized, options: [.prettyPrinted])
            return ToolResult(toolName: definition.name, success: true, output: String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct SearchProjectTool: Tool {
    public let definition = ToolDefinition.find("search_project") ?? ToolDefinition(
        name: "search_project", category: .search, summary: "Regex project search", description: "")
    private let fs: FileSystem
    public init(fs: FileSystem) { self.fs = fs }

    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let pattern = parameters["pattern"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'pattern'.")
        }
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Invalid regex: \(error.localizedDescription)")
        }
        // Walk all files, scan each
        var hits: [[String: Any]] = []
        let walker = WalkingSearch(root: context.project.rootPath, fs: fs)
        let matches = walker.search(regex: regex)
        for m in matches.prefix(100) {
            hits.append([
                "path": m.relativePath,
                "line": m.line,
                "snippet": m.snippet
            ])
        }
        let data = try JSONSerialization.data(withJSONObject: hits, options: [.prettyPrinted])
        return ToolResult(toolName: definition.name, success: true, output: String(data: data, encoding: .utf8) ?? "[]")
    }
}

private struct WalkingSearch {
    let root: String
    let fs: FileSystem
    let fm = FileManager.default

    struct Match { let relativePath: String; let line: Int; let snippet: String }

    func search(regex: NSRegularExpression) -> [Match] {
        var matches: [Match] = []
        walk(root) { path in
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }
            let lines = content.components(separatedBy: .newlines)
            for (idx, line) in lines.enumerated() {
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                if regex.firstMatch(in: line, options: [], range: range) != nil {
                    let rel = self.fs.relativePath(of: path, from: self.root)
                    matches.append(Match(relativePath: rel, line: idx + 1, snippet: line.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
        }
        return matches
    }

    private func walk(_ dir: String, _ cb: (String) -> Void) {
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return }
        for entry in entries {
            if entry.hasPrefix(".") || entry == "node_modules" || entry == "DerivedData" || entry == "build" || entry == ".build" { continue }
            let full = (dir as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            if isDir.boolValue {
                walk(full, cb)
            } else {
                cb(full)
            }
        }
    }
}
