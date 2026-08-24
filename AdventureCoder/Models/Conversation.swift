import Foundation

/// A chat conversation scoped to a project.
public struct Conversation: Identifiable, Codable, Hashable {
    public var id: UUID
    public var projectId: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var messages: [ChatMessage]
    public var pinned: Bool
    public var summary: String?

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [ChatMessage] = [],
        pinned: Bool = false,
        summary: String? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
        self.pinned = pinned
        self.summary = summary
    }
}

public struct ChatMessage: Identifiable, Codable, Hashable {
    public var id: UUID
    public var role: Role
    public var content: String
    public var createdAt: Date
    public var attachments: [Attachment]
    public var agentActivity: [AgentActivity]
    public var toolResults: [ToolResult]
    public var diffs: [FileDiff]
    public var modelId: String?
    public var providerId: String?
    public var streaming: Bool

    public init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        createdAt: Date = Date(),
        attachments: [Attachment] = [],
        agentActivity: [AgentActivity] = [],
        toolResults: [ToolResult] = [],
        diffs: [FileDiff] = [],
        modelId: String? = nil,
        providerId: String? = nil,
        streaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.attachments = attachments
        self.agentActivity = agentActivity
        self.toolResults = toolResults
        self.diffs = diffs
        self.modelId = modelId
        self.providerId = providerId
        self.streaming = streaming
    }

    public enum Role: String, Codable {
        case user, assistant, system, tool
    }
}

public struct Attachment: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var kind: Kind
    public var data: Data        // base64 representation when needed
    public var mimeType: String

    public enum Kind: String, Codable {
        case image, file, codeSnippet, url, errorLog, buildLog
    }

    public init(id: UUID = UUID(), name: String, kind: Kind, data: Data, mimeType: String) {
        self.id = id
        self.name = name
        self.kind = kind
        self.data = data
        self.mimeType = mimeType
    }
}

public struct AgentActivity: Identifiable, Codable, Hashable {
    public var id: UUID
    public var agentId: String
    public var agentName: String
    public var status: Status
    public var summary: String
    public var startedAt: Date
    public var finishedAt: Date?
    public var toolInvocations: [ToolInvocation]
    public var filesAffected: [String]
    public var details: String?

    public enum Status: String, Codable {
        case pending, running, completed, failed, skipped

        public var label: String {
            switch self {
            case .pending: return "Pending"
            case .running: return "Running"
            case .completed: return "Completed"
            case .failed: return "Failed"
            case .skipped: return "Skipped"
            }
        }
    }

    public init(
        id: UUID = UUID(),
        agentId: String,
        agentName: String,
        status: Status,
        summary: String,
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        toolInvocations: [ToolInvocation] = [],
        filesAffected: [String] = [],
        details: String? = nil
    ) {
        self.id = id
        self.agentId = agentId
        self.agentName = agentName
        self.status = status
        self.summary = summary
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.toolInvocations = toolInvocations
        self.filesAffected = filesAffected
        self.details = details
    }
}
