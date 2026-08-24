import Foundation

/// Git service that operates inside a project's sandboxed directory.
///
/// On iOS, the system `git` binary is not available, so this service implements a
/// pure-Swift "mini-git" over the filesystem: it tracks HEAD, branches, and an object
/// store laid out under `.adventure/git/`. It is NOT a complete reimplementation of
/// Git — it supports the operations Adventure Coder actually needs:
///
/// - init
/// - status (using file modification times + last commit snapshot)
/// - diff (line-level unified diff)
/// - add / commit
/// - branches / checkout
/// - history (log)
/// - push / pull (delegated to GitHub API when a remote is configured)
///
/// When projects are pushed to GitHub, the GitHub Actions workflow clones using real
/// Git, so the remote repository remains a fully standard Git repo.
public final class GitService {
    public static let shared = GitService()
    private init() {}

    public enum Result<T> {
        case success(T)
        case notARepo
        case failure(String)
    }

    private let fm = FileManager.default

    // MARK: - Repo layout helpers

    public func gitDir(project: Project) -> URL {
        URL(fileURLWithPath: project.rootPath).appendingPathComponent(".adventure", isDirectory: true).appendingPathComponent("git", isDirectory: true)
    }

    public func isRepo(_ project: Project) -> Bool {
        fm.fileExists(atPath: gitDir(project: project).path)
    }

    public func initialize(_ project: Project) -> Result<Void> {
        let gitDir = gitDir(project: project)
        do {
            try fm.createDirectory(at: gitDir, withIntermediateDirectories: true)
            try fm.createDirectory(at: gitDir.appendingPathComponent("objects", isDirectory: true), withIntermediateDirectories: true)
            try fm.createDirectory(at: gitDir.appendingPathComponent("refs", isDirectory: true), withIntermediateDirectories: true)
            try "ref: refs/heads/\(project.defaultBranch)".write(
                to: gitDir.appendingPathComponent("HEAD"),
                atomically: true,
                encoding: .utf8
            )
            try "{}".write(
                to: gitDir.appendingPathComponent("config.json"),
                atomically: true,
                encoding: .utf8
            )
            return .success(())
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - Status

    public func status(project: Project) -> Result<String> {
        guard isRepo(project) else { return .notARepo }
        let snapshot = currentSnapshot(project: project)
        let current = scan(project: project)
        var lines: [String] = []
        lines.append("On branch \(currentBranch(project: project))")
        let added = current.filter { c in !snapshot.contains { $0.path == c.path } }
        let modified = current.filter { c in snapshot.contains { $0.path == c.path && $0.hash != c.hash } }
        let deleted = snapshot.filter { s in !current.contains { $0.path == s.path } }
        if added.isEmpty && modified.isEmpty && deleted.isEmpty {
            lines.append("nothing to commit, working tree clean")
        } else {
            if !added.isEmpty {
                lines.append("Changes to be committed:")
                lines.append(contentsOf: added.map { "  new file:   \($0.path)" })
            }
            if !modified.isEmpty {
                lines.append("Changes not staged for commit:")
                lines.append(contentsOf: modified.map { "  modified:   \($0.path)" })
            }
            if !deleted.isEmpty {
                lines.append("Deleted files:")
                lines.append(contentsOf: deleted.map { "  deleted:    \($0.path)" })
            }
        }
        return .success(lines.joined(separator: "\n"))
    }

    // MARK: - Diff

    public func diff(project: Project, staged: Bool) -> Result<String> {
        guard isRepo(project) else { return .notARepo }
        let snapshot = currentSnapshot(project: project)
        let current = scan(project: project)
        var diffs: [String] = []
        for entry in current {
            if let snap = snapshot.first(where: { $0.path == entry.path }) {
                if snap.hash != entry.hash {
                    let old = readContent(project: project, hash: snap.hash) ?? ""
                    let new = (try? String(contentsOfFile: URL(fileURLWithPath: project.rootPath).appendingPathComponent(entry.path).path, encoding: .utf8)) ?? ""
                    diffs.append(DiffAlgorithm.unifiedDiff(old: old, new: new, path: entry.path))
                }
            } else {
                let new = (try? String(contentsOfFile: URL(fileURLWithPath: project.rootPath).appendingPathComponent(entry.path).path, encoding: .utf8)) ?? ""
                diffs.append(DiffAlgorithm.unifiedDiff(old: "", new: new, path: entry.path))
            }
        }
        let deleted = snapshot.filter { s in !current.contains { $0.path == s.path } }
        for d in deleted {
            let old = readContent(project: project, hash: d.hash) ?? ""
            diffs.append(DiffAlgorithm.unifiedDiff(old: old, new: "", path: d.path))
        }
        return .success(diffs.joined(separator: "\n\n"))
    }

    // MARK: - Commit

    public func commit(project: Project, message: String) -> Result<String> {
        guard isRepo(project) else { return .notARepo }
        let entries = scan(project: project)
        var treeHashes: [String] = []
        for entry in entries {
            let content = (try? String(contentsOfFile: URL(fileURLWithPath: project.rootPath).appendingPathComponent(entry.path).path, encoding: .utf8)) ?? ""
            let hash = hashContent(content)
            writeContent(project: project, hash: hash, content: content)
            treeHashes.append("\(hash)\t\(entry.path)")
        }
        let parent = currentHead(project: project)
        let commit = GitCommit(
            sha: UUID().uuidString,
            message: message,
            author: "Adventure Coder",
            email: "adventure-coder@app.local",
            date: Date(),
            parents: parent.map { [$0] } ?? []
        )
        let commitHash = hashContent(commit.sha + commit.message + commit.date.description)
        writeCommit(project: project, commit: commit, hash: commitHash, treeHashes: treeHashes)
        updateBranch(project: project, sha: commitHash)
        return .success(commit.sha)
    }

    // MARK: - Branches

    public func branches(project: Project) -> Result<[GitReference]> {
        guard isRepo(project) else { return .notARepo }
        let refsDir = gitDir(project: project).appendingPathComponent("refs", isDirectory: true)
        guard let entries = try? fm.contentsOfDirectory(atPath: refsDir.path) else {
            return .success([GitReference(name: project.defaultBranch, sha: currentHead(project: project) ?? "", isBranch: true, isCurrent: true)])
        }
        let current = currentBranch(project: project)
        var refs: [GitReference] = entries.map { name in
            let sha = (try? String(contentsOfFile: refsDir.appendingPathComponent(name).path, encoding: .utf8)) ?? ""
            return GitReference(name: name, sha: sha.trimmingCharacters(in: .whitespacesAndNewlines), isBranch: true, isCurrent: name == current)
        }
        if !refs.contains(where: { $0.name == project.defaultBranch }) {
            refs.append(GitReference(name: project.defaultBranch, sha: currentHead(project: project) ?? "", isBranch: true, isCurrent: current == project.defaultBranch))
        }
        return .success(refs)
    }

    public func checkout(project: Project, branch: String) -> Result<Void> {
        guard isRepo(project) else { return .notARepo }
        let headPath = gitDir(project: project).appendingPathComponent("HEAD")
        do {
            try "ref: refs/heads/\(branch)".write(to: headPath, atomically: true, encoding: .utf8)
            return .success(())
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - History

    public func history(project: Project, limit: Int) -> Result<[GitCommit]> {
        guard isRepo(project) else { return .notARepo }
        let logPath = gitDir(project: project).appendingPathComponent("log.json")
        guard let data = try? Data(contentsOf: logPath),
              let decoded = try? JSONDecoder().decode([GitCommit].self, from: data) else {
            return .success([])
        }
        return .success(Array(decoded.prefix(limit)))
    }

    // MARK: - Push / Pull (delegated to GitHub API)

    public func push(project: Project) -> Result<String> {
        guard let repo = project.githubRepo else { return .failure("No GitHub remote configured.") }
        guard let token = KeychainService.load(.githubToken) else { return .failure("GitHub token is missing.") }
        let historyResult = history(project: project, limit: 1000)
        guard case .success(let commits) = historyResult, !commits.isEmpty else {
            return .failure("No commits to push.")
        }
        do {
            try GitHubService.shared.pushCommits(project: project, repo: repo, token: token, commits: commits)
            return .success("Pushed \(commits.count) commits to \(repo).")
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    public func pull(project: Project) -> Result<String> {
        guard let repo = project.githubRepo else { return .failure("No GitHub remote configured.") }
        guard let token = KeychainService.load(.githubToken) else { return .failure("GitHub token is missing.") }
        do {
            let pulled = try GitHubService.shared.pullCommits(project: project, repo: repo, token: token)
            return .success("Pulled \(pulled) commits from \(repo).")
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - Internals

    private struct SnapshotEntry: Codable, Hashable {
        let path: String
        let hash: String
    }

    private func currentSnapshot(project: Project) -> [SnapshotEntry] {
        let path = gitDir(project: project).appendingPathComponent("snapshot.json")
        guard let data = try? Data(contentsOf: path),
              let decoded = try? JSONDecoder().decode([SnapshotEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    private func scan(project: Project) -> [SnapshotEntry] {
        var entries: [SnapshotEntry] = []
        let root = URL(fileURLWithPath: project.rootPath)
        let walker = { (current: URL) in
            guard let items = try? self.fm.contentsOfDirectory(at: current, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
            for item in items {
                if item.lastPathComponent.hasPrefix(".") || item.lastPathComponent == "node_modules" || item.lastPathComponent == "DerivedData" || item.lastPathComponent == "build" { continue }
                var isDir: ObjCBool = false
                self.fm.fileExists(atPath: item.path, isDirectory: &isDir)
                if isDir.boolValue {
                    self.walk(current: item, root: root, entries: &entries)
                } else {
                    self.addEntry(url: item, root: root, entries: &entries)
                }
            }
        }
        walker(root)
        return entries
    }

    private func walk(current: URL, root: URL, entries: inout [SnapshotEntry]) {
        guard let items = try? fm.contentsOfDirectory(at: current, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
        for item in items {
            if item.lastPathComponent.hasPrefix(".") || item.lastPathComponent == "node_modules" || item.lastPathComponent == "DerivedData" || item.lastPathComponent == "build" { continue }
            var isDir: ObjCBool = false
            fm.fileExists(atPath: item.path, isDirectory: &isDir)
            if isDir.boolValue {
                walk(current: item, root: root, entries: &entries)
            } else {
                addEntry(url: item, root: root, entries: &entries)
            }
        }
    }

    private func addEntry(url: URL, root: URL, entries: inout [SnapshotEntry]) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let rel = relativePath(url: url, root: root)
        entries.append(SnapshotEntry(path: rel, hash: hashContent(content)))
    }

    private func relativePath(url: URL, root: URL) -> String {
        let rootPath = root.path
        let fullPath = url.path
        guard fullPath.hasPrefix(rootPath) else { return url.lastPathComponent }
        let stripped = String(fullPath.dropFirst(rootPath.count))
        return stripped.hasPrefix("/") ? String(stripped.dropFirst()) : stripped
    }

    private func hashContent(_ content: String) -> String {
        let data = content.data(using: .utf8) ?? Data()
        var hash = SimpleHash()
        hash.update(data: data)
        return hash.finalHex()
    }

    private func writeContent(project: Project, hash: String, content: String) {
        let objectsDir = gitDir(project: project).appendingPathComponent("objects", isDirectory: true)
        try? fm.createDirectory(at: objectsDir, withIntermediateDirectories: true)
        let path = objectsDir.appendingPathComponent(hash)
        try? content.write(to: path, atomically: true, encoding: .utf8)
    }

    private func readContent(project: Project, hash: String) -> String? {
        let path = gitDir(project: project).appendingPathComponent("objects", isDirectory: true).appendingPathComponent(hash)
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    private func writeCommit(project: Project, commit: GitCommit, hash: String, treeHashes: [String]) {
        let logPath = gitDir(project: project).appendingPathComponent("log.json")
        var log: [GitCommit] = []
        if let data = try? Data(contentsOf: logPath),
           let decoded = try? JSONDecoder().decode([GitCommit].self, from: data) {
            log = decoded
        }
        log.insert(commit, at: 0)
        if let data = try? JSONEncoder().encode(log) {
            try? data.write(to: logPath)
        }
        // Save tree
        let treePath = gitDir(project: project).appendingPathComponent("trees", isDirectory: true)
        try? fm.createDirectory(at: treePath, withIntermediateDirectories: true)
        let treeContent = treeHashes.joined(separator: "\n")
        try? treeContent.write(to: treePath.appendingPathComponent(hash), atomically: true, encoding: .utf8)
        // Update snapshot
        let snapshot = treeHashes.map { line -> SnapshotEntry in
            let parts = line.split(separator: "\t", maxCount: 2).map { String($0) }
            return SnapshotEntry(path: parts.count > 1 ? parts[1] : "", hash: parts[0])
        }
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: gitDir(project: project).appendingPathComponent("snapshot.json"))
        }
    }

    private func currentBranch(project: Project) -> String {
        let head = (try? String(contentsOfFile: gitDir(project: project).appendingPathComponent("HEAD").path, encoding: .utf8)) ?? "ref: refs/heads/main"
        if head.hasPrefix("ref: refs/heads/") {
            return String(head.dropFirst("ref: refs/heads/".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "main"
    }

    private func currentHead(project: Project) -> String? {
        let branch = currentBranch(project: project)
        let refPath = gitDir(project: project).appendingPathComponent("refs", isDirectory: true).appendingPathComponent(branch)
        guard let sha = try? String(contentsOfFile: refPath.path, encoding: .utf8) else { return nil }
        return sha.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateBranch(project: Project, sha: String) {
        let branch = currentBranch(project: project)
        let refsDir = gitDir(project: project).appendingPathComponent("refs", isDirectory: true)
        try? fm.createDirectory(at: refsDir, withIntermediateDirectories: true)
        try? sha.write(to: refsDir.appendingPathComponent(branch), atomically: true, encoding: .utf8)
    }
}

// MARK: - Tiny non-cryptographic hash (deterministic, used for content addressing inside the sandbox only)

public struct SimpleHash {
    private var h1: UInt64 = 0x9E3779B97F4A7C15
    private var h2: UInt64 = 0xC2B2AE3D27D4EB4F

    public init() {}

    public mutating func update(data: Data) {
        for byte in data {
            h1 ^= UInt64(byte)
            h1 &*= 0x100000001B3
            h2 ^= UInt64(byte) &+ (h1 << 1)
            h2 &*= 0xFF51AFD7ED558CCD
        }
    }

    public mutating func finalHex() -> String {
        let combined = h1 ^ h2
        return String(format: "%016llx", combined)
    }
}

// MARK: - Diff algorithm

public enum DiffAlgorithm {
    public static func unifiedDiff(old: String, new: String, path: String) -> String {
        let oldLines = old.components(separatedBy: .newlines)
        let newLines = new.components(separatedBy: .newlines)
        let hunks = computeHunks(oldLines: oldLines, newLines: newLines)
        var output = "diff --git a/\(path) b/\(path)\n"
        for hunk in hunks {
            output += "@@ -\(hunk.oldStart),\(hunk.oldCount) +\(hunk.newStart),\(hunk.newCount) @@\n"
            for line in hunk.lines {
                output += line.kind.prefix + line.content + "\n"
            }
        }
        return output
    }

    public static func computeHunks(oldLines: [String], newLines: [String]) -> [DiffHunk] {
        // Use LCS to compute diff
        let (lcs, oldAligned, newAligned) = longestCommonSubsequence(oldLines, newLines)
        var hunks: [DiffHunk] = []
        var oldIdx = 0
        var newIdx = 0
        var lcsIdx = 0
        var lines: [DiffLine] = []
        var oldStart = oldIdx + 1
        var newStart = newIdx + 1
        var oldCount = 0
        var newCount = 0
        while oldIdx < oldLines.count || newIdx < newLines.count {
            if lcsIdx < lcs.count && oldIdx < oldAligned.count && newIdx < newAligned.count && oldAligned[oldIdx] == lcs[lcsIdx] && newAligned[newIdx] == lcs[lcsIdx] {
                lines.append(DiffLine(kind: .context, content: lcs[lcsIdx], oldLineNumber: oldIdx + 1, newLineNumber: newIdx + 1))
                oldCount += 1; newCount += 1
                oldIdx += 1; newIdx += 1; lcsIdx += 1
            } else if oldIdx < oldAligned.count && (lcsIdx >= lcs.count || oldAligned[oldIdx] != lcs[lcsIdx]) {
                lines.append(DiffLine(kind: .removed, content: oldLines[oldIdx], oldLineNumber: oldIdx + 1, newLineNumber: nil))
                oldCount += 1
                oldIdx += 1
            } else if newIdx < newAligned.count && (lcsIdx >= lcs.count || newAligned[newIdx] != lcs[lcsIdx]) {
                lines.append(DiffLine(kind: .added, content: newLines[newIdx], oldLineNumber: nil, newLineNumber: newIdx + 1))
                newCount += 1
                newIdx += 1
            } else {
                oldIdx += 1; newIdx += 1
            }
            if !lines.isEmpty && (oldIdx >= oldLines.count && newIdx >= newLines.count) {
                hunks.append(DiffHunk(oldStartLine: oldStart, oldLineCount: oldCount, newStartLine: newStart, newLineCount: newCount, lines: lines))
                lines = []
            }
        }
        if !lines.isEmpty {
            hunks.append(DiffHunk(oldStartLine: oldStart, oldLineCount: oldCount, newStartLine: newStart, newLineCount: newCount, lines: lines))
        }
        return hunks
    }

    private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> (lcs: [String], alignedA: [String], alignedB: [String]) {
        let m = a.count
        let n = b.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0..<m {
            for j in 0..<n {
                if a[i] == b[j] {
                    dp[i+1][j+1] = dp[i][j] + 1
                } else {
                    dp[i+1][j+1] = max(dp[i+1][j], dp[i][j+1])
                }
            }
        }
        var lcs: [String] = []
        var i = m, j = n
        while i > 0 && j > 0 {
            if a[i-1] == b[j-1] {
                lcs.insert(a[i-1], at: 0)
                i -= 1; j -= 1
            } else if dp[i-1][j] > dp[i][j-1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        return (lcs, a, b)
    }
}
