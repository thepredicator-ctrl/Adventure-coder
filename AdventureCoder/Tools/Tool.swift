import Foundation

/// Protocol that every concrete tool implements.
public protocol Tool {
    var definition: ToolDefinition { get }
    func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult
}

/// Context handed to every tool invocation. Provides access to the project root,
/// settings, and a confirmation callback for destructive operations.
public struct ToolContext {
    public let project: Project
    public let settings: SettingsStore
    public var requestConfirmation: (String) async -> Bool

    public init(project: Project, settings: SettingsStore = .shared, requestConfirmation: @escaping (String) async -> Bool) {
        self.project = project
        self.settings = settings
        self.requestConfirmation = requestConfirmation
    }

    /// Always-approve context used for tests and read-only tool previews.
    public static func approving(project: Project) -> ToolContext {
        ToolContext(project: project) { _ in true }
    }
}
