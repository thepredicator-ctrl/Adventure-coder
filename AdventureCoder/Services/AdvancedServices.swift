import Foundation
import Combine

/// Advanced file watcher that monitors project directories for changes.
public final class FileWatcher: ObservableObject {
    public static let shared = FileWatcher()

    @Published public var changedFiles: Set<String> = []
    @Published public var isWatching = false

    private var timer: Timer?
    private var lastModified: [String: Date] = [:]
    private let fm = FileManager.default

    private init() {}

    /// Start watching a directory for changes.
    public func startWatching(_ directory: String) {
        stopWatching()
        isWatching = true
        // Initial scan
        scanDirectory(directory)
        // Poll for changes every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.scanDirectory(directory)
        }
    }

    /// Stop watching.
    public func stopWatching() {
        timer?.invalidate()
        timer = nil
        isWatching = false
    }

    /// Clear the changed files set.
    public func clearChanges() {
        changedFiles.removeAll()
    }

    private func scanDirectory(_ directory: String) {
        guard let entries = try? fm.contentsOfDirectory(atPath: directory) else { return }
        for entry in entries {
            if entry.hasPrefix(".") || entry == "node_modules" || entry == "DerivedData" || entry == "build" { continue }
            let full = (directory as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            if isDir.boolValue {
                scanDirectory(full)
            } else {
                checkFile(full)
            }
        }
    }

    private func checkFile(_ path: String) {
        guard let attrs = try? fm.attributesOfItem(atPath: path),
              let modified = attrs[.modificationDate] as? Date else { return }
        if let last = lastModified[path] {
            if modified > last {
                changedFiles.insert(path)
                lastModified[path] = modified
            }
        } else {
            lastModified[path] = modified
        }
    }
}

/// Manages editor sessions including undo/redo history and cursor positions.
public final class EditorSessionManager: ObservableObject {
    public static let shared = EditorSessionManager()

    @Published public var sessions: [String: EditorSession] = [:]

    public struct EditorSession {
        public var filePath: String
        public var content: String
        public var cursorPosition: Int
        public var scrollPosition: CGFloat
        public var undoStack: [String]
        public var redoStack: [String]
        public var lastSaved: String

        public init(filePath: String, content: String = "") {
            self.filePath = filePath
            self.content = content
            self.cursorPosition = 0
            self.scrollPosition = 0
            self.undoStack = []
            self.redoStack = []
            self.lastSaved = content
        }

        public mutating func updateContent(_ newContent: String) {
            if content != newContent {
                undoStack.append(content)
                if undoStack.count > 50 { undoStack.removeFirst() }
                redoStack.removeAll()
                content = newContent
            }
        }

        public mutating func undo() {
            guard let previous = undoStack.popLast() else { return }
            redoStack.append(content)
            content = previous
        }

        public mutating func redo() {
            guard let next = redoStack.popLast() else { return }
            undoStack.append(content)
            content = next
        }

        public var isDirty: Bool { content != lastSaved }

        public mutating func markSaved() {
            lastSaved = content
        }
    }

    private init() {}

    public func session(for path: String) -> EditorSession {
        if let session = sessions[path] {
            return session
        }
        let content = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        let session = EditorSession(filePath: path, content: content)
        sessions[path] = session
        return session
    }

    public func updateSession(for path: String, content: String) {
        var session = session(for: path)
        session.updateContent(content)
        sessions[path] = session
    }

    public func undo(path: String) {
        guard var session = sessions[path] else { return }
        session.undo()
        sessions[path] = session
    }

    public func redo(path: String) {
        guard var session = sessions[path] else { return }
        session.redo()
        sessions[path] = session
    }

    public func markSaved(path: String) {
        guard var session = sessions[path] else { return }
        session.markSaved()
        sessions[path] = session
    }

    public func isDirty(path: String) -> Bool {
        sessions[path]?.isDirty ?? false
    }

    public func removeSession(path: String) {
        sessions.removeValue(forKey: path)
    }
}

/// Manages project-level settings that override global settings.
public final class ProjectSettingsManager: ObservableObject {
    public static let shared = ProjectSettingsManager()

    @Published public var projectSettings: [UUID: ProjectSettings] = [:]

    private let defaults = UserDefaults.standard

    public struct ProjectSettings: Codable, Hashable {
        public var projectId: UUID
        public var customBuildCommand: String?
        public var customTestCommand: String?
        public var excludedPaths: [String]
        public var defaultRunDevice: String?
        public var autoFormatOnSave: Bool
        public var autoLintOnSave: Bool
        public var tabSize: Int?
        public var preferredModel: String?

        public init(projectId: UUID) {
            self.projectId = projectId
            self.excludedPaths = []
            self.autoFormatOnSave = false
            self.autoLintOnSave = false
        }
    }

    private init() {
        load()
    }

    public func settings(for projectId: UUID) -> ProjectSettings {
        if let settings = projectSettings[projectId] {
            return settings
        }
        let new = ProjectSettings(projectId: projectId)
        projectSettings[projectId] = new
        return new
    }

    public func update(_ settings: ProjectSettings) {
        projectSettings[settings.projectId] = settings
        save()
    }

    public func setBuildCommand(_ command: String?, for projectId: UUID) {
        var settings = settings(for: projectId)
        settings.customBuildCommand = command
        update(settings)
    }

    public func setTestCommand(_ command: String?, for projectId: UUID) {
        var settings = settings(for: projectId)
        settings.customTestCommand = command
        update(settings)
    }

    public func excludePath(_ path: String, for projectId: UUID) {
        var settings = settings(for: projectId)
        if !settings.excludedPaths.contains(path) {
            settings.excludedPaths.append(path)
            update(settings)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(projectSettings) {
            defaults.set(data, forKey: "project_settings")
        }
    }

    private func load() {
        if let data = defaults.data(forKey: "project_settings"),
           let decoded = try? JSONDecoder().decode([UUID: ProjectSettings].self, from: data) {
            projectSettings = decoded
        }
    }
}

/// Manages workspace layout persistence.
public final class WorkspaceLayoutManager: ObservableObject {
    public static let shared = WorkspaceLayoutManager()

    @Published public var layout: WorkspaceLayout

    private let defaults = UserDefaults.standard

    public struct WorkspaceLayout: Codable, Hashable {
        public var sidebarWidth: CGFloat
        public var chatWidth: CGFloat
        public var terminalHeight: CGFloat
        public var sidebarCollapsed: Bool
        public var chatCollapsed: Bool
        public var terminalCollapsed: Bool
        public var previewCollapsed: Bool
        public var inspectorVisible: Bool
        public var inspectorWidth: CGFloat
        public var bottomPanelTab: String

        public static let defaultLayout = WorkspaceLayout(
            sidebarWidth: 240,
            chatWidth: 360,
            terminalHeight: 240,
            sidebarCollapsed: false,
            chatCollapsed: false,
            terminalCollapsed: false,
            previewCollapsed: true,
            inspectorVisible: false,
            inspectorWidth: 240,
            bottomPanelTab: "terminal"
        )
    }

    private init() {
        if let data = defaults.data(forKey: "workspace_layout"),
           let decoded = try? JSONDecoder().decode(WorkspaceLayout.self, from: data) {
            layout = decoded
        } else {
            layout = .defaultLayout
        }
    }

    public func save() {
        if let data = try? JSONEncoder().encode(layout) {
            defaults.set(data, forKey: "workspace_layout")
        }
    }

    public func reset() {
        layout = .defaultLayout
        save()
    }
}

/// Provides intelligent code suggestions based on context.
public final class CodeSuggestionEngine {
    public static let shared = CodeSuggestionEngine()
    private init() {}

    public struct Suggestion: Identifiable, Hashable {
        public let id = UUID()
        public let text: String
        public let kind: SuggestionKind
        public let confidence: Double
        public let detail: String?
    }

    public enum SuggestionKind: String {
        case completion, refactoring, optimization, fix, documentation
    }

    /// Generate suggestions for the current context.
    public func suggestions(for code: String, language: Language, cursorPosition: Int) -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // Check for common patterns
        if code.contains("TODO") || code.contains("FIXME") {
            suggestions.append(Suggestion(
                text: "Resolve TODO/FIXME comments",
                kind: .fix,
                confidence: 0.9,
                detail: "Found unresolved TODO/FIXME comments"
            ))
        }

        // Check for force unwrapping
        if language == .swift && code.contains("!.") {
            suggestions.append(Suggestion(
                text: "Replace force unwrapping with optional binding",
                kind: .fix,
                confidence: 0.85,
                detail: "Force unwrapping can cause runtime crashes"
            ))
        }

        // Check for long functions
        let lines = code.components(separatedBy: "\n")
        if lines.count > 50 {
            suggestions.append(Suggestion(
                text: "Extract long function into smaller functions",
                kind: .refactoring,
                confidence: 0.7,
                detail: "Function is \(lines.count) lines long"
            ))
        }

        // Check for deep nesting
        let maxNesting = lines.map { line -> Int in
            let leading = line.prefix { $0 == " " }.count
            return leading / 4
        }.max() ?? 0
        if maxNesting > 4 {
            suggestions.append(Suggestion(
                text: "Reduce nesting depth",
                kind: .refactoring,
                confidence: 0.75,
                detail: "Maximum nesting depth is \(maxNesting)"
            ))
        }

        // Check for missing documentation
        if language == .swift {
            let funcCount = code.components(separatedBy: "func ").count - 1
            let docCount = code.components(separatedBy: "/// ").count - 1
            if funcCount > 0 && docCount < funcCount / 2 {
                suggestions.append(Suggestion(
                    text: "Add documentation comments",
                    kind: .documentation,
                    confidence: 0.6,
                    detail: "\(funcCount) functions, \(docCount) documented"
                ))
            }
        }

        // Check for print statements
        if code.contains("print(") && language == .swift {
            suggestions.append(Suggestion(
                text: "Replace print() with a proper logger",
                kind: .optimization,
                confidence: 0.5,
                detail: "print() is not suitable for production logging"
            ))
        }

        // Check for hardcoded strings
        if language == .swift {
            let stringLiteralPattern = "\"[A-Z][a-zA-Z ]{10,}\""
            if let regex = try? NSRegularExpression(pattern: stringLiteralPattern) {
                let ns = code as NSString
                let count = regex.numberOfMatches(in: code, options: [], range: NSRange(location: 0, length: ns.length))
                if count > 3 {
                    suggestions.append(Suggestion(
                        text: "Extract hardcoded strings into a localization file",
                        kind: .refactoring,
                        confidence: 0.55,
                        detail: "Found \(count) long string literals"
                    ))
                }
            }
        }

        return suggestions.sorted { $0.confidence > $1.confidence }
    }
}

/// Manages build configurations and profiles.
public final class BuildProfileManager: ObservableObject {
    public static let shared = BuildProfileManager()

    @Published public var profiles: [BuildProfile] = []

    private let defaults = UserDefaults.standard

    public struct BuildProfile: Identifiable, Codable, Hashable {
        public var id: UUID
        public var name: String
        public var configuration: String  // debug, release
        public var destination: String
        public var buildArguments: [String]
        public var environmentVariables: [String: String]
        public var preBuildScript: String?
        public var postBuildScript: String?

        public init(id: UUID = UUID(), name: String, configuration: String = "debug", destination: String = "iOS Simulator", buildArguments: [String] = [], environmentVariables: [String: String] = [:]) {
            self.id = id
            self.name = name
            self.configuration = configuration
            self.destination = destination
            self.buildArguments = buildArguments
            self.environmentVariables = environmentVariables
        }
    }

    private init() {
        load()
        if profiles.isEmpty {
            installDefaultProfiles()
        }
    }

    private func installDefaultProfiles() {
        profiles = [
            BuildProfile(name: "Debug", configuration: "debug", destination: "iOS Simulator"),
            BuildProfile(name: "Release", configuration: "release", destination: "iOS Device"),
            BuildProfile(name: "Test", configuration: "debug", destination: "iOS Simulator", buildArguments: ["test"]),
        ]
        save()
    }

    public func add(_ profile: BuildProfile) {
        profiles.append(profile)
        save()
    }

    public func remove(_ profile: BuildProfile) {
        profiles.removeAll { $0.id == profile.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: "build_profiles")
        }
    }

    private func load() {
        if let data = defaults.data(forKey: "build_profiles"),
           let decoded = try? JSONDecoder().decode([BuildProfile].self, from: data) {
            profiles = decoded
        }
    }
}

/// Manages project templates including custom templates.
public final class CustomTemplateManager: ObservableObject {
    public static let shared = CustomTemplateManager()

    @Published public var customTemplates: [CustomTemplate] = []

    private let defaults = UserDefaults.standard

    public struct CustomTemplate: Identifiable, Codable, Hashable {
        public var id: UUID
        public var name: String
        public var description: String
        public var icon: String
        public var files: [TemplateFile]
        public var createdAt: Date

        public struct TemplateFile: Codable, Hashable {
            public var path: String
            public var content: String
        }

        public init(id: UUID = UUID(), name: String, description: String, icon: String = "doc", files: [TemplateFile], createdAt: Date = Date()) {
            self.id = id
            self.name = name
            self.description = description
            self.icon = icon
            self.files = files
            self.createdAt = createdAt
        }
    }

    private init() {
        load()
    }

    public func add(_ template: CustomTemplate) {
        customTemplates.append(template)
        save()
    }

    public func remove(_ template: CustomTemplate) {
        customTemplates.removeAll { $0.id == template.id }
        save()
    }

    public func install(_ template: CustomTemplate, at directory: String) throws {
        let fm = FileManager.default
        for file in template.files {
            let path = (directory as NSString).appendingPathComponent(file.path)
            try fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            try file.content.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(customTemplates) {
            defaults.set(data, forKey: "custom_templates")
        }
    }

    private func load() {
        if let data = defaults.data(forKey: "custom_templates"),
           let decoded = try? JSONDecoder().decode([CustomTemplate].self, from: data) {
            customTemplates = decoded
        }
    }
}
