import Foundation

/// High-level file operations on the remote PC via SSH.
public final class RemoteFileService {
    public static let shared = RemoteFileService()
    private init() {}

    private let ssh = SSHService.shared

    // MARK: - Read / Write

    public func readFile(_ path: String) async throws -> String {
        try await ssh.readFile(path)
    }

    public func writeFile(_ path: String, content: String) async throws {
        try await ssh.writeFile(path, content: content)
    }

    public func editFile(_ path: String, find: String, replace: String) async throws -> String {
        let original = try await readFile(path)
        guard original.contains(find) else {
            throw SSHService.SSHError.unknown("Text not found in file")
        }
        let modified = original.replacingOccurrences(of: find, with: replace)
        try await writeFile(path, content: modified)
        return DiffAlgorithm.unifiedDiff(old: original, new: modified, path: path)
    }

    public func deleteFile(_ path: String) async throws {
        try await ssh.deletePath(path)
    }

    public func createDirectory(_ path: String) async throws {
        try await ssh.createDirectory(path)
    }

    public func moveFile(_ from: String, to: String) async throws {
        try await ssh.movePath(from: from, to: to)
    }

    public func copyFile(_ from: String, to: String) async throws {
        try await ssh.copyPath(from: from, to: to)
    }

    // MARK: - Listing

    public func listFiles(_ path: String) async throws -> [RemoteFileEntry] {
        try await ssh.listFiles(path)
    }

    public func searchFiles(query: String, in directory: String) async throws -> [RemoteSearchHit] {
        try await ssh.searchFiles(query: query, in: directory)
    }

    // MARK: - Tree

    public func fileTree(at path: String, maxDepth: Int = 5) async throws -> [RemoteFileNode] {
        let entries = try await listFiles(path)
        var nodes: [RemoteFileNode] = []
        for entry in entries {
            var node = RemoteFileNode(from: entry)
            if entry.isDirectory && maxDepth > 0 {
                node.children = try await fileTree(at: entry.path, maxDepth: maxDepth - 1)
            }
            nodes.append(node)
        }
        return nodes.sorted { $0.isDirectory && !$1.isDirectory }
    }
}

/// A file tree node for the remote filesystem.
public struct RemoteFileNode: Identifiable, Hashable {
    public var id: String { path }
    public var name: String
    public var path: String
    public var isDirectory: Bool
    public var size: Int64
    public var children: [RemoteFileNode]

    public init(from entry: RemoteFileEntry) {
        self.name = entry.name
        self.path = entry.path
        self.isDirectory = entry.isDirectory
        self.size = entry.size
        self.children = []
    }

    public var optionalChildren: [RemoteFileNode]? {
        isDirectory ? children : nil
    }

    public var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }

    public var language: Language {
        Language.forExtension(fileExtension)
    }

    public var fileIcon: String {
        if isDirectory { return MonoIcon.folder }
        return language.icon
    }
}
