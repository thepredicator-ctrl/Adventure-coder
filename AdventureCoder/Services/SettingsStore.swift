import Foundation
import SwiftUI

/// User-configurable application settings persisted to UserDefaults.
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    // MARK: - Models

    @Published public var freeModelsOnly: Bool {
        didSet { defaults.set(freeModelsOnly, forKey: Keys.freeModelsOnly) }
    }
    @Published public var allowPaidModels: Bool {
        didSet { defaults.set(allowPaidModels, forKey: Keys.allowPaidModels) }
    }
    @Published public var primaryModelId: String? {
        didSet { defaults.set(primaryModelId, forKey: Keys.primaryModelId) }
    }
    @Published public var codingModelId: String? {
        didSet { defaults.set(codingModelId, forKey: Keys.codingModelId) }
    }
    @Published public var planningModelId: String? {
        didSet { defaults.set(planningModelId, forKey: Keys.planningModelId) }
    }
    @Published public var reviewModelId: String? {
        didSet { defaults.set(reviewModelId, forKey: Keys.reviewModelId) }
    }
    @Published public var fastModelId: String? {
        didSet { defaults.set(fastModelId, forKey: Keys.fastModelId) }
    }

    // MARK: - Agents

    @Published public var enabledAgents: Set<String> {
        didSet { defaults.set(Array(enabledAgents), forKey: Keys.enabledAgents) }
    }
    @Published public var parallelAgentExecution: Bool {
        didSet { defaults.set(parallelAgentExecution, forKey: Keys.parallelAgentExecution) }
    }
    @Published public var autoRepairBuilds: Bool {
        didSet { defaults.set(autoRepairBuilds, forKey: Keys.autoRepairBuilds) }
    }

    // MARK: - Editor

    @Published public var editorFont: String {
        didSet { defaults.set(editorFont, forKey: Keys.editorFont) }
    }
    @Published public var editorFontSize: Int {
        didSet { defaults.set(editorFontSize, forKey: Keys.editorFontSize) }
    }
    @Published public var editorTabSize: Int {
        didSet { defaults.set(editorTabSize, forKey: Keys.editorTabSize) }
    }
    @Published public var editorShowLineNumbers: Bool {
        didSet { defaults.set(editorShowLineNumbers, forKey: Keys.editorShowLineNumbers) }
    }
    @Published public var editorWordWrap: Bool {
        didSet { defaults.set(editorWordWrap, forKey: Keys.editorWordWrap) }
    }

    // MARK: - Appearance

    @Published public var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    // MARK: - GitHub

    @Published public var githubUser: String? {
        didSet { defaults.set(githubUser, forKey: Keys.githubUser) }
    }

    private enum Keys {
        static let freeModelsOnly = "settings.freeModelsOnly"
        static let allowPaidModels = "settings.allowPaidModels"
        static let primaryModelId = "settings.primaryModelId"
        static let codingModelId = "settings.codingModelId"
        static let planningModelId = "settings.planningModelId"
        static let reviewModelId = "settings.reviewModelId"
        static let fastModelId = "settings.fastModelId"
        static let enabledAgents = "settings.enabledAgents"
        static let parallelAgentExecution = "settings.parallelAgentExecution"
        static let autoRepairBuilds = "settings.autoRepairBuilds"
        static let editorFont = "settings.editorFont"
        static let editorFontSize = "settings.editorFontSize"
        static let editorTabSize = "settings.editorTabSize"
        static let editorShowLineNumbers = "settings.editorShowLineNumbers"
        static let editorWordWrap = "settings.editorWordWrap"
        static let appearance = "settings.appearance"
        static let githubUser = "settings.githubUser"
    }

    public enum Appearance: String, CaseIterable {
        case system, light, dark
        public var displayName: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
        public var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    public init() {
        freeModelsOnly = defaults.object(forKey: Keys.freeModelsOnly) as? Bool ?? true
        allowPaidModels = defaults.object(forKey: Keys.allowPaidModels) as? Bool ?? false
        primaryModelId = defaults.string(forKey: Keys.primaryModelId)
        codingModelId = defaults.string(forKey: Keys.codingModelId)
        planningModelId = defaults.string(forKey: Keys.planningModelId)
        reviewModelId = defaults.string(forKey: Keys.reviewModelId)
        fastModelId = defaults.string(forKey: Keys.fastModelId)
        enabledAgents = Set(defaults.stringArray(forKey: Keys.enabledAgents) ?? [])
        parallelAgentExecution = defaults.object(forKey: Keys.parallelAgentExecution) as? Bool ?? true
        autoRepairBuilds = defaults.object(forKey: Keys.autoRepairBuilds) as? Bool ?? true
        editorFont = defaults.string(forKey: Keys.editorFont) ?? "SF Mono"
        editorFontSize = defaults.object(forKey: Keys.editorFontSize) as? Int ?? 13
        editorTabSize = defaults.object(forKey: Keys.editorTabSize) as? Int ?? 4
        editorShowLineNumbers = defaults.object(forKey: Keys.editorShowLineNumbers) as? Bool ?? true
        editorWordWrap = defaults.object(forKey: Keys.editorWordWrap) as? Bool ?? false
        appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "system") ?? .system
        githubUser = defaults.string(forKey: Keys.githubUser)

        // Default: enable all agents
        if enabledAgents.isEmpty {
            enabledAgents = Set(AgentRegistry.shared.all.map { $0.agentId })
        }
    }

    public var colorScheme: ColorScheme? { appearance.colorScheme }

    public func isAgentEnabled(_ id: String) -> Bool { enabledAgents.contains(id) }
    public func setAgent(_ id: String, enabled: Bool) {
        if enabled { enabledAgents.insert(id) } else { enabledAgents.remove(id) }
    }
}
