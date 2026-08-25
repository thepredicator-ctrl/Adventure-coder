import Foundation

/// A file diff produced by an AI edit.
public struct FileDiff: Identifiable, Codable, Hashable {
    public var id: UUID
    public var filePath: String
    public var agentId: String
    public var agentName: String
    public var hunks: [DiffHunk]
    public var originalContent: String
    public var modifiedContent: String
    public var createdAt: Date
    public var status: Status

    public enum Status: String, Codable {
        case pending, accepted, rejected, reverted

        public var label: String {
            switch self {
            case .pending: return "Pending"
            case .accepted: return "Accepted"
            case .rejected: return "Rejected"
            case .reverted: return "Reverted"
            }
        }
    }

    public init(
        id: UUID = UUID(),
        filePath: String,
        agentId: String,
        agentName: String,
        hunks: [DiffHunk],
        originalContent: String,
        modifiedContent: String,
        createdAt: Date = Date(),
        status: Status = .pending
    ) {
        self.id = id
        self.filePath = filePath
        self.agentId = agentId
        self.agentName = agentName
        self.hunks = hunks
        self.originalContent = originalContent
        self.modifiedContent = modifiedContent
        self.createdAt = createdAt
        self.status = status
    }

    public var addedLineCount: Int {
        hunks.reduce(0) { $0 + $1.lines.filter { $0.kind == .added }.count }
    }

    public var removedLineCount: Int {
        hunks.reduce(0) { $0 + $1.lines.filter { $0.kind == .removed }.count }
    }

    public var summary: String {
        "+\(addedLineCount) −\(removedLineCount)"
    }
}

public struct DiffHunk: Identifiable, Codable, Hashable {
    public var id: UUID
    public var oldStartLine: Int
    public var oldLineCount: Int
    public var newStartLine: Int
    public var newLineCount: Int
    public var lines: [DiffLine]

    public init(
        id: UUID = UUID(),
        oldStartLine: Int,
        oldLineCount: Int,
        newStartLine: Int,
        newLineCount: Int,
        lines: [DiffLine]
    ) {
        self.id = id
        self.oldStartLine = oldStartLine
        self.oldLineCount = oldLineCount
        self.newStartLine = newStartLine
        self.newLineCount = newLineCount
        self.lines = lines
    }

    public var header: String {
        "@@ -\(oldStartLine),\(oldLineCount) +\(newStartLine),\(newLineCount) @@"
    }
}

public struct DiffLine: Identifiable, Codable, Hashable {
    public var id: UUID
    public var kind: Kind
    public var content: String
    public var oldLineNumber: Int?
    public var newLineNumber: Int?

    public enum Kind: String, Codable {
        case context, added, removed

        public var prefix: String {
            switch self {
            case .context: return " "
            case .added: return "+"
            case .removed: return "-"
            }
        }
    }

    public init(id: UUID = UUID(), kind: Kind, content: String, oldLineNumber: Int? = nil, newLineNumber: Int? = nil) {
        self.id = id
        self.kind = kind
        self.content = content
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
    }
}
