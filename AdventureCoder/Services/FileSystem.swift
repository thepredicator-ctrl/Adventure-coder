import Foundation

/// Wraps FileManager operations on the in-sandbox project directory.
public final class FileSystem {
    public static let shared = FileSystem()

    private let fm: FileManager

    public init(fm: FileManager = .default) {
        self.fm = fm
    }

    // MARK: - Listing

    public func list(directory path: String) throws -> [FileNode] {
        let url = URL(fileURLWithPath: path)
        let items = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
        var nodes: [FileNode] = []
        for item in items {
            let values = try item.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            let isDir = values.isDirectory ?? false
            let rel = relativePath(of: item.path, from: path)
            nodes.append(FileNode(
                name: item.lastPathComponent,
                relativePath: rel,
                absolutePath: item.path,
                isDirectory: isDir,
                children: isDir ? try list(directory: item.path) : [],
                size: Int64(values.fileSize ?? 0),
                modifiedAt: values.contentModificationDate ?? Date()
            ))
        }
        return FileNode.sorted(nodes)
    }

    public func tree(at path: String, maxDepth: Int = 8, currentDepth: Int = 0) throws -> [FileNode] {
        let items = try list(directory: path)
        if currentDepth >= maxDepth { return items.map { $0.isDirectory ? FileNode(name: $0.name, relativePath: $0.relativePath, absolutePath: $0.absolutePath, isDirectory: true, children: [], size: 0, modifiedAt: $0.modifiedAt) : $0 } }
        return items.map { node in
            guard node.isDirectory else { return node }
            var copy = node
            copy.children = (try? tree(at: node.absolutePath, maxDepth: maxDepth, currentDepth: currentDepth + 1)) ?? []
            return copy
        }
    }

    // MARK: - Read / write

    public func read(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }

    public func write(_ path: String, content: String) throws {
        let url = URL(fileURLWithPath: path)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.data(using: .utf8)?.write(to: url, options: .atomic)
    }

    public func createDirectory(_ path: String) throws {
        try fm.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    public func delete(_ path: String) throws {
        try fm.removeItem(atPath: path)
    }

    public func rename(_ path: String, to newName: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        if fm.fileExists(atPath: newURL.path) {
            throw NSError(domain: "FileSystem", code: 1, userInfo: [NSLocalizedDescriptionKey: "A file with that name already exists."])
        }
        try fm.moveItem(at: url, to: newURL)
        return newURL.path
    }

    public func move(_ srcPath: String, to destDir: String) throws -> String {
        let src = URL(fileURLWithPath: srcPath)
        let dest = URL(fileURLWithPath: destDir).appendingPathComponent(src.lastPathComponent)
        try fm.createDirectory(at: URL(fileURLWithPath: destDir), withIntermediateDirectories: true)
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.moveItem(at: src, to: dest)
        return dest.path
    }

    public func duplicate(_ path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        let copyURL = url.deletingLastPathComponent().appendingPathComponent(url.deletingPathExtension().lastPathComponent + " copy." + url.pathExtension)
        try fm.copyItem(at: url, to: copyURL)
        return copyURL.path
    }

    public func exists(_ path: String) -> Bool { fm.fileExists(atPath: path) }
    public func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    // MARK: - Search

    public struct SearchHit: Codable, Hashable {
        public var path: String
        public var relativePath: String
        public var line: Int
        public var column: Int
        public var snippet: String
    }

    public func search(query: String, in root: String, extensions: [String]? = nil, caseSensitive: Bool = false, maxResults: Int = 200) throws -> [SearchHit] {
        var hits: [SearchHit] = []
        let lowered = caseSensitive ? query : query.lowercased()
        let walker = { (current: String) in
            guard let entries = try? self.fm.contentsOfDirectory(atPath: current) else { return }
            for entry in entries {
                if entry.hasPrefix(".") { continue }
                let full = (current as NSString).appendingPathComponent(entry)
                var isDir: ObjCBool = false
                self.fm.fileExists(atPath: full, isDirectory: &isDir)
                if isDir.boolValue {
                    self.walkSearch(query: lowered, root: root, current: full, extensions: extensions, caseSensitive: caseSensitive, hits: &hits, maxResults: maxResults)
                } else {
                    self.examine(full: full, root: root, query: lowered, extensions: extensions, caseSensitive: caseSensitive, hits: &hits, maxResults: maxResults)
                }
                if hits.count >= maxResults { return }
            }
        }
        walker(root)
        return hits
    }

    private func walkSearch(query: String, root: String, current: String, extensions: [String]?, caseSensitive: Bool, hits: inout [SearchHit], maxResults: Int) {
        guard let entries = try? fm.contentsOfDirectory(atPath: current) else { return }
        for entry in entries {
            if entry.hasPrefix(".") { continue }
            let full = (current as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            if isDir.boolValue {
                walkSearch(query: query, root: root, current: full, extensions: extensions, caseSensitive: caseSensitive, hits: &hits, maxResults: maxResults)
            } else {
                examine(full: full, root: root, query: query, extensions: extensions, caseSensitive: caseSensitive, hits: &hits, maxResults: maxResults)
            }
            if hits.count >= maxResults { return }
        }
    }

    private func examine(full: String, root: String, query: String, extensions: [String]?, caseSensitive: Bool, hits: inout [SearchHit], maxResults: Int) {
        let ext = (full as NSString).pathExtension.lowercased()
        if let extensions, !extensions.isEmpty, !extensions.map({ $0.lowercased() }).contains(ext) { return }
        guard let content = try? String(contentsOfFile: full, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: .newlines)
        for (idx, line) in lines.enumerated() {
            let hay = caseSensitive ? line : line.lowercased()
            if let range = hay.range(of: query) {
                let col = line.distance(from: line.startIndex, to: range.lowerBound) + 1
                hits.append(SearchHit(
                    path: full,
                    relativePath: relativePath(of: full, from: root),
                    line: idx + 1,
                    column: col,
                    snippet: line.trimmingCharacters(in: .whitespacesAndNewlines)
                ))
                if hits.count >= maxResults { return }
            }
        }
    }

    // MARK: - Helpers

    public func relativePath(of absolute: String, from root: String) -> String {
        if absolute == root { return "." }
        if absolute.hasPrefix(root) {
            let stripped = String(absolute.dropFirst(root.count))
            return stripped.hasPrefix("/") ? String(stripped.dropFirst()) : stripped
        }
        return absolute
    }

    public func join(_ root: String, _ relative: String) -> String {
        if relative.hasPrefix("/") { return relative }
        return (root as NSString).appendingPathComponent(relative)
    }
}
