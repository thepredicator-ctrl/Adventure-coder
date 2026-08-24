import Foundation

/// Persistent on-disk stores for projects, conversations, and settings.
public final class ProjectStore: ObservableObject {
    public static let shared = ProjectStore()

    @Published public var projects: [Project] = []
    @Published public var conversations: [Conversation] = []

    private let fileManager = FileManager.default
    private let projectsURL: URL
    private let conversationsURL: URL

    private init() {
        let appSupport = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fileManager.temporaryDirectory
        let root = appSupport.appendingPathComponent("AdventureCoder", isDirectory: true)
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        self.projectsURL = root.appendingPathComponent("projects.json")
        self.conversationsURL = root.appendingPathComponent("conversations.json")
        load()
    }

    // MARK: - Projects

    public func createProject(name: String, template: ProjectTemplate) throws -> Project {
        let safeName = name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let projectsRoot = try ensureProjectsRoot()
        let projectDir = projectsRoot.appendingPathComponent(safeName, isDirectory: true)
        try fileManager.createDirectory(at: projectDir, withIntermediateDirectories: true)
        try TemplateInstaller.install(template: template, at: projectDir, name: safeName)

        let project = Project(
            name: safeName,
            rootPath: projectDir.path,
            template: template,
            primaryLanguage: template.primaryLanguage,
            icon: template.icon
        )
        projects.insert(project, at: 0)
        try persist()
        return project
    }

    public func importProject(at url: URL, name: String) throws -> Project {
        let projectsRoot = try ensureProjectsRoot()
        let safeName = name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let dest = projectsRoot.appendingPathComponent(safeName, isDirectory: true)
        if fileManager.fileExists(atPath: dest.path) {
            try fileManager.removeItem(at: dest)
        }
        try fileManager.copyItem(at: url, to: dest)
        let project = Project(
            name: safeName,
            rootPath: dest.path,
            template: .empty,
            primaryLanguage: "Mixed",
            icon: MonoIcon.folder
        )
        projects.insert(project, at: 0)
        try persist()
        return project
    }

    public func delete(_ project: Project) throws {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects.remove(at: idx)
            try persist()
        }
        if fileManager.fileExists(atPath: project.rootPath) {
            try fileManager.removeItem(atPath: project.rootPath)
        }
        conversations.removeAll { $0.projectId == project.id }
        try persistConversations()
    }

    public func touch(_ project: Project) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx].lastOpenedAt = Date()
            projects[idx].updatedAt = Date()
            try? persist()
        }
    }

    public func update(_ project: Project) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
            try? persist()
        }
    }

    public func project(for id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    // MARK: - Conversations

    public func conversations(for projectId: UUID) -> [Conversation] {
        conversations
            .filter { $0.projectId == projectId }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func createConversation(projectId: UUID, title: String = "New Conversation") -> Conversation {
        let conv = Conversation(projectId: projectId, title: title)
        conversations.insert(conv, at: 0)
        try? persistConversations()
        return conv
    }

    public func update(_ conversation: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            var updated = conversation
            updated.updatedAt = Date()
            conversations[idx] = updated
            try? persistConversations()
        }
    }

    public func delete(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        try? persistConversations()
    }

    public func appendMessage(_ message: ChatMessage, to conversation: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx].messages.append(message)
            conversations[idx].updatedAt = Date()
            try? persistConversations()
        }
    }

    // MARK: - Persistence

    private func ensureProjectsRoot() throws -> URL {
        let appSupport = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let root = appSupport.appendingPathComponent("AdventureCoder", isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func load() {
        if let data = try? Data(contentsOf: projectsURL),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = decoded
        }
        if let data = try? Data(contentsOf: conversationsURL),
           let decoded = try? JSONDecoder().decode([Conversation].self, from: data) {
            conversations = decoded
        }
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(projects)
        try data.write(to: projectsURL, options: .atomic)
    }

    private func persistConversations() throws {
        let data = try JSONEncoder().encode(conversations)
        try data.write(to: conversationsURL, options: .atomic)
    }

    /// URL where on-disk projects live. Useful for Files app exposure.
    public var projectsRootURL: URL {
        (try? ensureProjectsRoot()) ?? fileManager.temporaryDirectory
    }
}
