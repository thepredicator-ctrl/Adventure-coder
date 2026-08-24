import Foundation

/// GitHub REST API client used by GitHub tools and push/pull operations.
public final class GitHubService {
    public static let shared = GitHubService()
    private let session: URLSession
    private let api = URL(string: "https://api.github.com")!

    private init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Search

    public struct SearchRepo: Codable, Hashable {
        public let id: Int
        public let fullName: String
        public let htmlURL: String
        public let stars: Int
        public let description: String?
        enum CodingKeys: String, CodingKey {
            case id
            case fullName = "full_name"
            case htmlURL = "html_url"
            case stars = "stargazers_count"
            case description
        }
    }

    public func searchRepositories(query: String) async throws -> [SearchRepo] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = api.appendingPathComponent("search/repositories?q=\(encoded)&per_page=15")
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token = KeychainService.load(.githubToken) {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ProviderError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8) ?? "")
        }
        let decoded = try JSONDecoder().decode(GitHubSearchResponse.self, from: data)
        return decoded.items
    }

    // MARK: - List user repositories

    public func listRepositories(token: String) async throws -> [GitHubRepository] {
        let url = api.appendingPathComponent("user/repos?per_page=100&sort=updated")
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ProviderError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8) ?? "")
        }
        let decoded = try JSONDecoder().decode([GitHubRepoJSON].self, from: data)
        return decoded.map { r in
            GitHubRepository(
                id: r.id,
                fullName: r.fullName,
                name: r.name,
                owner: r.owner.login,
                cloneURL: r.cloneUrl,
                sshURL: r.sshUrl,
                htmlURL: r.htmlUrl,
                defaultBranch: r.defaultBranch,
                isPrivate: r.isPrivate,
                description: r.description,
                updatedAt: ISO8601DateFormatter().date(from: r.updatedAt) ?? Date()
            )
        }
    }

    // MARK: - Workflow runs

    public func listWorkflowRuns(repo: String, token: String) async throws -> [BuildRun] {
        let encoded = repo.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? repo
        let url = api.appendingPathComponent("repos/\(encoded)/actions/runs?per_page=20")
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ProviderError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8) ?? "")
        }
        let decoded = try JSONDecoder().decode(GitHubActionsRunsResponse.self, from: data)
        return decoded.workflowRuns.map { run in
            BuildRun(
                projectId: UUID(),
                number: run.runNumber,
                branch: run.headBranch,
                commitSha: run.headSha,
                commitMessage: run.displayTitle ?? "",
                status: BuildRun.Status(rawValue: run.status) ?? .pending,
                conclusion: run.conclusion.flatMap { BuildRun.Conclusion(rawValue: $0) },
                startedAt: ISO8601DateFormatter().date(from: run.runStartedAt ?? run.createdAt) ?? Date(),
                finishedAt: run.updatedAt.flatMap { ISO8601DateFormatter().date(from: $0) },
                durationSeconds: nil,
                runnerOS: "macOS",
                logsURL: run.htmlUrl,
                artifactURL: nil,
                artifactName: nil,
                artifactSize: nil,
                isUnsigned: true,
                workflowName: run.name ?? "Build Unsigned IPA",
                triggeredBy: run.actor?.login ?? "unknown"
            )
        }
    }

    // MARK: - Trigger workflow

    public func triggerWorkflow(repo: String, workflowID: String, ref: String, token: String) async throws {
        let encoded = repo.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? repo
        let workflowEncoded = workflowID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? workflowID
        let url = api.appendingPathComponent("repos/\(encoded)/actions/workflows/\(workflowEncoded)/dispatches")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["ref": ref]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1, "Failed to trigger workflow.")
        }
    }

    // MARK: - Push commits (creates/updates files via the Contents API)

    public func pushCommits(project: Project, repo: String, token: String, commits: [GitCommit]) throws {
        guard !commits.isEmpty else { return }
        let encoded = repo.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? repo
        // Walk project files and push each via the Contents API.
        let walker = FileWalker()
        let files = walker.walk(project.rootPath)
        for file in files {
            let path = file.relativePath
            let url = api.appendingPathComponent("repos/\(encoded)/contents/\(path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path)")
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            var existingSHA: String? = nil
            if let (data, response) = try? session.synchronousData(for: req),
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sha = dict["sha"] as? String {
                existingSHA = sha
            }
            // PUT the new content
            var putReq = URLRequest(url: url)
            putReq.httpMethod = "PUT"
            putReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            putReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            putReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let content = file.content
            let base64 = (content.data(using: .utf8) ?? Data()).base64EncodedString()
            var body: [String: Any] = [
                "message": "Adventure Coder: update \(path)",
                "content": base64,
                "branch": project.defaultBranch
            ]
            if let sha = existingSHA { body["sha"] = sha }
            putReq.httpBody = try JSONSerialization.data(withJSONObject: body)
            _ = try? session.synchronousData(for: putReq)
        }
    }

    // MARK: - Pull (clone-and-extract the latest tree)

    public func pullCommits(project: Project, repo: String, token: String) throws -> Int {
        let encoded = repo.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? repo
        // Fetch the default branch tree and write each file to disk.
        let branchURL = api.appendingPathComponent("repos/\(encoded)/branches/\(project.defaultBranch)")
        var req = URLRequest(url: branchURL)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? session.synchronousData(for: req),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commit = dict["commit"] as? [String: Any],
              let treeSHA = (commit["tree"] as? [String: Any])?["sha"] as? String else {
            return 0
        }
        let treeURL = api.appendingPathComponent("repos/\(encoded)/git/trees/\(treeSHA)?recursive=1")
        var treeReq = URLRequest(url: treeURL)
        treeReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        treeReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (treeData, treeResponse) = try? session.synchronousData(for: treeReq),
              let treeHTTP = treeResponse as? HTTPURLResponse, treeHTTP.statusCode == 200,
              let treeDict = try? JSONSerialization.jsonObject(with: treeData) as? [String: Any],
              let tree = treeDict["tree"] as? [[String: Any]] else {
            return 0
        }
        var pulled = 0
        for entry in tree {
            guard let type = entry["type"] as? String, type == "blob",
                  let path = entry["path"] as? String,
                  let sha = entry["sha"] as? String else { continue }
            let blobURL = api.appendingPathComponent("repos/\(encoded)/git/blobs/\(sha)")
            var blobReq = URLRequest(url: blobURL)
            blobReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            blobReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            guard let (blobData, blobResponse) = try? session.synchronousData(for: blobReq),
                  let blobHTTP = blobResponse as? HTTPURLResponse, blobHTTP.statusCode == 200,
                  let blobDict = try? JSONSerialization.jsonObject(with: blobData) as? [String: Any],
                  let contentB64 = blobDict["content"] as? String,
                  let data = Data(base64Encoded: contentB64.replacingOccurrences(of: "\n", with: "")) else {
                continue
            }
            let dest = (project.rootPath as NSString).appendingPathComponent(path)
            try? FileManager.default.createDirectory(atPath: (dest as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            try? data.write(to: URL(fileURLWithPath: dest))
            pulled += 1
        }
        return pulled
    }

    // MARK: - Create repo

    public func createRepository(name: String, private isPrivate: Bool, token: String) async throws -> GitHubRepository {
        let url = api.appendingPathComponent("user/repos")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["name": name, "private": isPrivate, "auto_init": true]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8) ?? "")
        }
        let r = try JSONDecoder().decode(GitHubRepoJSON.self, from: data)
        return GitHubRepository(
            id: r.id,
            fullName: r.fullName,
            name: r.name,
            owner: r.owner.login,
            cloneURL: r.cloneUrl,
            sshURL: r.sshUrl,
            htmlURL: r.htmlUrl,
            defaultBranch: r.defaultBranch,
            isPrivate: r.isPrivate,
            description: r.description,
            updatedAt: Date()
        )
    }
}

// MARK: - JSON models

private struct GitHubSearchResponse: Decodable {
    let items: [GitHubService.SearchRepo]
}

private struct GitHubRepoJSON: Decodable {
    let id: Int
    let name: String
    let fullName: String
    let owner: Owner
    let cloneUrl: String
    let sshUrl: String
    let htmlUrl: String
    let defaultBranch: String
    let isPrivate: Bool
    let description: String?
    let updatedAt: String
    enum CodingKeys: String, CodingKey {
        case id, name, owner, description
        case fullName = "full_name"
        case cloneUrl = "clone_url"
        case sshUrl = "ssh_url"
        case htmlUrl = "html_url"
        case defaultBranch = "default_branch"
        case isPrivate = "private"
        case updatedAt = "updated_at"
    }
    struct Owner: Decodable { let login: String }
}

private struct GitHubActionsRunsResponse: Decodable {
    let workflowRuns: [Run]
    enum CodingKeys: String, CodingKey {
        case workflowRuns = "workflow_runs"
    }
    struct Run: Decodable {
        let runNumber: Int
        let headBranch: String
        let headSha: String
        let status: String
        let conclusion: String?
        let displayTitle: String?
        let name: String?
        let htmlUrl: String
        let runStartedAt: String?
        let createdAt: String
        let updatedAt: String?
        let actor: Actor?
        enum CodingKeys: String, CodingKey {
            case runNumber = "run_number"
            case headBranch = "head_branch"
            case headSha = "head_sha"
            case status, conclusion, name, actor
            case displayTitle = "display_title"
            case htmlUrl = "html_url"
            case runStartedAt = "run_started_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }
    struct Actor: Decodable { let login: String }
}

// MARK: - File walker used by push

private final class FileWalker {
    private let fm = FileManager.default
    struct File { let relativePath: String; let content: String }
    func walk(_ root: String) -> [File] {
        var files: [File] = []
        walkInternal(root, root: root, files: &files)
        return files
    }
    private func walkInternal(_ dir: String, root: String, files: inout [File]) {
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return }
        for entry in entries {
            if entry.hasPrefix(".") || entry == "node_modules" || entry == "DerivedData" || entry == "build" { continue }
            let full = (dir as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            if isDir.boolValue {
                walkInternal(full, root: root, files: &files)
            } else {
                if let content = try? String(contentsOfFile: full, encoding: .utf8) {
                    let rel = relativePath(full: full, root: root)
                    files.append(File(relativePath: rel, content: content))
                }
            }
        }
    }
    private func relativePath(full: String, root: String) -> String {
        guard full.hasPrefix(root) else { return (full as NSString).lastPathComponent }
        let stripped = String(full.dropFirst(root.count))
        return stripped.hasPrefix("/") ? String(stripped.dropFirst()) : stripped
    }
}

// MARK: - Synchronous URLSession helper

private extension URLSession {
    func synchronousData(for request: URLRequest) throws -> (Data, URLResponse) {
        var resultData: Data?
        var resultResponse: URLResponse?
        var resultError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        let task = self.dataTask(with: request) { data, response, error in
            resultData = data
            resultResponse = response
            resultError = error
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        if let error = resultError { throw error }
        guard let data = resultData, let response = resultResponse else {
            throw NSError(domain: "URLSession", code: -1)
        }
        return (data, response)
    }
}
