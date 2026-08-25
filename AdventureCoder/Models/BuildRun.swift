import Foundation

/// Represents a build run, either local (preview build) or remote (GitHub Actions).
public struct BuildRun: Identifiable, Codable, Hashable {
    public var id: UUID
    public var projectId: UUID
    public var number: Int
    public var branch: String
    public var commitSha: String
    public var commitMessage: String
    public var status: Status
    public var conclusion: Conclusion?
    public var startedAt: Date
    public var finishedAt: Date?
    public var durationSeconds: Int?
    public var runnerOS: String
    public var logsURL: String?
    public var artifactURL: String?
    public var artifactName: String?
    public var artifactSize: Int64?
    public var isUnsigned: Bool
    public var workflowName: String
    public var triggeredBy: String

    public enum Status: String, Codable {
        case queued, inProgress = "in_progress", completed, waiting, pending
        public var label: String {
            switch self {
            case .queued: return "Queued"
            case .inProgress: return "Running"
            case .completed: return "Completed"
            case .waiting: return "Waiting"
            case .pending: return "Pending"
            }
        }
    }

    public enum Conclusion: String, Codable {
        case success, failure, cancelled, neutral, timedOut = "timed_out", actionRequired = "action_required"
        public var label: String {
            switch self {
            case .success: return "Success"
            case .failure: return "Failed"
            case .cancelled: return "Cancelled"
            case .neutral: return "Neutral"
            case .timedOut: return "Timed Out"
            case .actionRequired: return "Action Required"
            }
        }
    }

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        number: Int,
        branch: String,
        commitSha: String,
        commitMessage: String,
        status: Status,
        conclusion: Conclusion? = nil,
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        durationSeconds: Int? = nil,
        runnerOS: String = "macOS",
        logsURL: String? = nil,
        artifactURL: String? = nil,
        artifactName: String? = nil,
        artifactSize: Int64? = nil,
        isUnsigned: Bool = true,
        workflowName: String = "Build Unsigned IPA",
        triggeredBy: String = "Adventure Coder"
    ) {
        self.id = id
        self.projectId = projectId
        self.number = number
        self.branch = branch
        self.commitSha = commitSha
        self.commitMessage = commitMessage
        self.status = status
        self.conclusion = conclusion
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.durationSeconds = durationSeconds
        self.runnerOS = runnerOS
        self.logsURL = logsURL
        self.artifactURL = artifactURL
        self.artifactName = artifactName
        self.artifactSize = artifactSize
        self.isUnsigned = isUnsigned
        self.workflowName = workflowName
        self.triggeredBy = triggeredBy
    }

    public var durationText: String {
        guard let d = durationSeconds else { return "—" }
        let m = d / 60
        let s = d % 60
        return "\(m)m \(s)s"
    }

    public var shortSha: String {
        String(commitSha.prefix(7))
    }
}

public struct GitHubRepository: Identifiable, Codable, Hashable {
    public var id: Int
    public var fullName: String
    public var name: String
    public var owner: String
    public var cloneURL: String
    public var sshURL: String
    public var htmlURL: String
    public var defaultBranch: String
    public var isPrivate: Bool
    public var description: String?
    public var updatedAt: Date

    public init(
        id: Int,
        fullName: String,
        name: String,
        owner: String,
        cloneURL: String,
        sshURL: String,
        htmlURL: String,
        defaultBranch: String,
        isPrivate: Bool,
        description: String?,
        updatedAt: Date
    ) {
        self.id = id
        self.fullName = fullName
        self.name = name
        self.owner = owner
        self.cloneURL = cloneURL
        self.sshURL = sshURL
        self.htmlURL = htmlURL
        self.defaultBranch = defaultBranch
        self.isPrivate = isPrivate
        self.description = description
        self.updatedAt = updatedAt
    }
}

public struct GitReference: Codable, Hashable {
    public var name: String
    public var sha: String
    public var isBranch: Bool
    public var isCurrent: Bool

    public init(name: String, sha: String, isBranch: Bool, isCurrent: Bool) {
        self.name = name
        self.sha = sha
        self.isBranch = isBranch
        self.isCurrent = isCurrent
    }
}

public struct GitCommit: Identifiable, Codable, Hashable {
    public var id: String
    public var sha: String
    public var shortSha: String
    public var message: String
    public var author: String
    public var email: String
    public var date: Date
    public var parents: [String]

    public init(
        sha: String,
        message: String,
        author: String,
        email: String,
        date: Date,
        parents: [String] = []
    ) {
        self.id = sha
        self.sha = sha
        self.shortSha = String(sha.prefix(7))
        self.message = message
        self.author = author
        self.email = email
        self.date = date
        self.parents = parents
    }
}
