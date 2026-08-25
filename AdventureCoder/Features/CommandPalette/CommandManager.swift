import Foundation
import SwiftUI

/// Comprehensive command system that provides a unified interface for all user actions.
/// Each command is a discrete, named action that can be triggered via:
/// - Command palette (⌘K)
/// - Keyboard shortcut
/// - Menu item
/// - Programmatic call
public final class CommandManager: ObservableObject {
    public static let shared = CommandManager()

    @Published public var allCommands: [UserCommand] = []
    @Published public var recentCommands: [UserCommand] = []
    @Published public var favorites: Set<String> = []

    private let defaults = UserDefaults.standard

    public struct UserCommand: Identifiable {
        public let id: String
        public let title: String
        public let category: CommandCategory
        public let icon: String
        public let shortcut: KeyboardShortcuts.Shortcut?
        public let isEnabled: Bool
        public let action: @MainActor () -> Void

        public init(id: String, title: String, category: CommandCategory, icon: String, shortcut: KeyboardShortcuts.Shortcut? = nil, isEnabled: Bool = true, action: @escaping @MainActor () -> Void) {
            self.id = id
            self.title = title
            self.category = category
            self.icon = icon
            self.shortcut = shortcut
            self.isEnabled = isEnabled
            self.action = action
        }
    }

    public enum CommandCategory: String, CaseIterable, Hashable {
        case file = "File"
        case edit = "Edit"
        case view = "View"
        case navigate = "Navigate"
        case build = "Build"
        case git = "Git"
        case ai = "AI"
        case remote = "Remote"
        case terminal = "Terminal"
        case tools = "Tools"
        case help = "Help"
        case settings = "Settings"
    }

    private init() {
        loadFavorites()
        registerAllCommands()
    }

    // MARK: - Command Registration

    private func registerAllCommands() {
        allCommands = [
            // File
            UserCommand(id: "file.new", title: "New File", category: .file, icon: "doc.badge.plus", shortcut: KeyboardShortcuts.newFile) {
                WorkspaceState.shared.bottomPanel = .newProject
            },
            UserCommand(id: "file.open", title: "Open File…", category: .file, icon: "folder", shortcut: KeyboardShortcuts.openFile) {},
            UserCommand(id: "file.save", title: "Save", category: .file, icon: "arrow.down.to.line", shortcut: KeyboardShortcuts.saveFile) {},
            UserCommand(id: "file.saveAll", title: "Save All", category: .file, icon: "arrow.down.to.line.circle") {},
            UserCommand(id: "file.close", title: "Close Tab", category: .file, icon: "xmark", shortcut: KeyboardShortcuts.closeTab) {},
            UserCommand(id: "file.closeAll", title: "Close All Tabs", category: .file, icon: "xmark.circle") {},
            UserCommand(id: "file.recent", title: "Open Recent…", category: .file, icon: "clock") {},
            UserCommand(id: "file.download", title: "Download Project", category: .file, icon: "arrow.down.circle") {},
            UserCommand(id: "file.upload", title: "Upload Project", category: .file, icon: "arrow.up.circle") {},

            // Edit
            UserCommand(id: "edit.find", title: "Find", category: .edit, icon: "magnifyingglass", shortcut: KeyboardShortcuts.find) {},
            UserCommand(id: "edit.findReplace", title: "Find & Replace", category: .edit, icon: "magnifyingglass.circle", shortcut: KeyboardShortcuts.findReplace) {},
            UserCommand(id: "edit.undo", title: "Undo", category: .edit, icon: "arrow.uturn.backward", shortcut: KeyboardShortcuts.undo) {},
            UserCommand(id: "edit.redo", title: "Redo", category: .edit, icon: "arrow.uturn.forward", shortcut: KeyboardShortcuts.redo) {},
            UserCommand(id: "edit.gotoLine", title: "Go to Line…", category: .edit, icon: "arrow.right.to.line", shortcut: KeyboardShortcuts.goToLine) {},
            UserCommand(id: "edit.format", title: "Format Code", category: .edit, icon: "paintbrush.pointed") {},
            UserCommand(id: "edit.comment", title: "Toggle Comment", category: .edit, icon: "text.bubble") {},
            UserCommand(id: "edit.indent", title: "Indent", category: .edit, icon: "increase.indent") {},
            UserCommand(id: "edit.outdent", title: "Outdent", category: .edit, icon: "decrease.indent") {},
            UserCommand(id: "edit.duplicate", title: "Duplicate Line", category: .edit, icon: "plus.square.on.square") {},
            UserCommand(id: "edit.delete", title: "Delete Line", category: .edit, icon: "minus.square") {},

            // View
            UserCommand(id: "view.toggleSidebar", title: "Toggle Sidebar", category: .view, icon: "sidebar.left", shortcut: KeyboardShortcuts.toggleSidebar) {
                WorkspaceState.shared.sidebarCollapsed.toggle()
            },
            UserCommand(id: "view.toggleTerminal", title: "Toggle Terminal", category: .view, icon: "terminal", shortcut: KeyboardShortcuts.toggleTerminal) {
                WorkspaceState.shared.terminalCollapsed.toggle()
            },
            UserCommand(id: "view.toggleAIChat", title: "Toggle AI Chat", category: .view, icon: "sparkles", shortcut: KeyboardShortcuts.toggleAIChat) {
                WorkspaceState.shared.chatCollapsed.toggle()
            },
            UserCommand(id: "view.togglePreview", title: "Toggle Preview", category: .view, icon: "eye", shortcut: KeyboardShortcuts.togglePreview) {
                WorkspaceState.shared.previewCollapsed.toggle()
            },
            UserCommand(id: "view.toggleInspector", title: "Toggle Inspector", category: .view, icon: "sidebar.right") {},
            UserCommand(id: "view.zoomIn", title: "Zoom In", category: .view, icon: "plus.magnifyingglass") {},
            UserCommand(id: "view.zoomOut", title: "Zoom Out", category: .view, icon: "minus.magnifyingglass") {},
            UserCommand(id: "view.resetZoom", title: "Reset Zoom", category: .view, icon: "1.magnifyingglass") {},
            UserCommand(id: "view.theme", title: "Change Theme…", category: .view, icon: "paintpalette") {},
            UserCommand(id: "view.minimap", title: "Toggle Minimap", category: .view, icon: "map") {},

            // Navigate
            UserCommand(id: "nav.commandPalette", title: "Command Palette", category: .navigate, icon: "command", shortcut: KeyboardShortcuts.commandPalette) {
                WorkspaceState.shared.showCommandPalette = true
            },
            UserCommand(id: "nav.globalSearch", title: "Global Search", category: .navigate, icon: "magnifyingglass", shortcut: KeyboardShortcuts.globalSearch) {
                WorkspaceState.shared.showGlobalSearch = true
            },
            UserCommand(id: "nav.quickOpen", title: "Quick Open File", category: .navigate, icon: "doc.text.magnifyingglass", shortcut: KeyboardShortcuts.quickOpen) {},
            UserCommand(id: "nav.goToSymbol", title: "Go to Symbol…", category: .navigate, icon: "square.grid.2x2") {},
            UserCommand(id: "nav.goToDefinition", title: "Go to Definition", category: .navigate, icon: "arrow.right.square") {},
            UserCommand(id: "nav.goBack", title: "Go Back", category: .navigate, icon: "arrow.left") {},
            UserCommand(id: "nav.goForward", title: "Go Forward", category: .navigate, icon: "arrow.right") {},
            UserCommand(id: "nav.nextTab", title: "Next Tab", category: .navigate, icon: "chevron.right") {},
            UserCommand(id: "nav.prevTab", title: "Previous Tab", category: .navigate, icon: "chevron.left") {},
            UserCommand(id: "nav.nextProblem", title: "Next Problem", category: .navigate, icon: "chevron.down.circle") {},
            UserCommand(id: "nav.prevProblem", title: "Previous Problem", category: .navigate, icon: "chevron.up.circle") {},
            UserCommand(id: "nav.bookmarks", title: "Show Bookmarks", category: .navigate, icon: "bookmark") {},
            UserCommand(id: "nav.toggleBookmark", title: "Toggle Bookmark", category: .navigate, icon: "bookmark.fill") {},
            UserCommand(id: "nav.nextBookmark", title: "Next Bookmark", category: .navigate, icon: "bookmark.fill") {},
            UserCommand(id: "nav.prevBookmark", title: "Previous Bookmark", category: .navigate, icon: "bookmark") {},

            // Build
            UserCommand(id: "build.run", title: "Build Project", category: .build, icon: "hammer", shortcut: KeyboardShortcuts.build) {
                WorkspaceState.shared.bottomPanel = .builds
            },
            UserCommand(id: "build.runTests", title: "Run Tests", category: .build, icon: "checkmark.seal", shortcut: KeyboardShortcuts.test) {},
            UserCommand(id: "build.stop", title: "Stop", category: .build, icon: "stop.fill", shortcut: KeyboardShortcuts.stop) {},
            UserCommand(id: "build.clean", title: "Clean Build", category: .build, icon: "trash") {},
            UserCommand(id: "build.profile", title: "Profile", category: .build, icon: "speedometer") {},
            UserCommand(id: "build.analyze", title: "Analyze Code", category: .build, icon: "waveform") {},
            UserCommand(id: "build.archive", title: "Archive", category: .build, icon: "archivebox") {},

            // Git
            UserCommand(id: "git.status", title: "Git Status", category: .git, icon: "circle.grid.cross", shortcut: KeyboardShortcuts.gitStatus) {
                WorkspaceState.shared.bottomPanel = .terminal
            },
            UserCommand(id: "git.commit", title: "Git Commit…", category: .git, icon: "arrow.triangle.merge", shortcut: KeyboardShortcuts.gitCommit) {},
            UserCommand(id: "git.push", title: "Git Push", category: .git, icon: "arrow.up.circle", shortcut: KeyboardShortcuts.gitPush) {},
            UserCommand(id: "git.pull", title: "Git Pull", category: .git, icon: "arrow.down.circle", shortcut: KeyboardShortcuts.gitPull) {},
            UserCommand(id: "git.branch", title: "Create Branch…", category: .git, icon: "arrow.triangle.branch") {},
            UserCommand(id: "git.checkout", title: "Switch Branch…", category: .git, icon: "arrow.triangle.swap") {},
            UserCommand(id: "git.merge", title: "Merge…", category: .git, icon: "arrow.triangle.merge") {},
            UserCommand(id: "git.history", title: "Show History", category: .git, icon: "clock.arrow.circlepath") {},
            UserCommand(id: "git.clone", title: "Clone Repository…", category: .git, icon: "arrow.down.doc") {},
            UserCommand(id: "git.stash", title: "Stash Changes", category: .git, icon: "tray") {},
            UserCommand(id: "git.unstash", title: "Unstash Changes…", category: .git, icon: "tray.full") {},

            // AI
            UserCommand(id: "ai.ask", title: "Ask AI", category: .ai, icon: "sparkles", shortcut: KeyboardShortcuts.askAI) {
                WorkspaceState.shared.chatCollapsed = false
            },
            UserCommand(id: "ai.switchModel", title: "Switch Model…", category: .ai, icon: "cpu", shortcut: KeyboardShortcuts.switchModel) {},
            UserCommand(id: "ai.switchAgent", title: "Switch Agent…", category: .ai, icon: "person.crop.circle", shortcut: KeyboardShortcuts.switchAgent) {},
            UserCommand(id: "ai.clearConversation", title: "Clear Conversation", category: .ai, icon: "trash") {},
            UserCommand(id: "ai.exportConversation", title: "Export Conversation", category: .ai, icon: "square.and.arrow.up") {},
            UserCommand(id: "ai.agentActivity", title: "Show Agent Activity", category: .ai, icon: "bolt") {},

            // Remote
            UserCommand(id: "remote.connect", title: "Connect to Remote PC…", category: .remote, icon: "link") {},
            UserCommand(id: "remote.disconnect", title: "Disconnect from Remote PC", category: .remote, icon: "link.badge.plus") {},
            UserCommand(id: "remote.terminal", title: "Open Remote Terminal", category: .remote, icon: "terminal") {
                WorkspaceState.shared.bottomPanel = .remoteTerminal
            },
            UserCommand(id: "remote.preview", title: "Open Remote Preview", category: .remote, icon: "play.rectangle") {
                WorkspaceState.shared.bottomPanel = .remotePreview
            },
            UserCommand(id: "remote.dashboard", title: "Open Remote Dashboard", category: .remote, icon: "gauge") {
                WorkspaceState.shared.bottomPanel = .remoteDashboard
            },
            UserCommand(id: "remote.upload", title: "Upload to Remote PC…", category: .remote, icon: "arrow.up.circle") {},
            UserCommand(id: "remote.download", title: "Download from Remote PC…", category: .remote, icon: "arrow.down.circle") {},
            UserCommand(id: "remote.status", title: "Show Remote PC Status", category: .remote, icon: "pc") {},

            // Terminal
            UserCommand(id: "terminal.new", title: "New Terminal", category: .terminal, icon: "plus.app", shortcut: KeyboardShortcuts.newTerminal) {},
            UserCommand(id: "terminal.clear", title: "Clear Terminal", category: .terminal, icon: "clear", shortcut: KeyboardShortcuts.clearTerminal) {},
            UserCommand(id: "terminal.split", title: "Split Terminal", category: .terminal, icon: "square.split.2x1") {},
            UserCommand(id: "terminal.close", title: "Close Terminal", category: .terminal, icon: "xmark") {},

            // Tools
            UserCommand(id: "tools.analyzeComplexity", title: "Analyze Code Complexity", category: .tools, icon: "chart.bar") {},
            UserCommand(id: "tools.detectDuplicates", title: "Detect Duplicate Code", category: .tools, icon: "doc.on.doc") {},
            UserCommand(id: "tools.detectDeadCode", title: "Detect Dead Code", category: .tools, icon: "trash") {},
            UserCommand(id: "tools.securityScan", title: "Security Scan", category: .tools, icon: "shield") {},
            UserCommand(id: "tools.formatCode", title: "Format Code", category: .tools, icon: "paintbrush.pointed") {},
            UserCommand(id: "tools.lintCode", title: "Lint Code", category: .tools, icon: "magnifyingglass") {},
            UserCommand(id: "tools.generateTests", title: "Generate Tests", category: .tools, icon: "checkmark.seal") {},
            UserCommand(id: "tools.generateDocs", title: "Generate Documentation", category: .tools, icon: "doc.text") {},
            UserCommand(id: "tools.generateChangelog", title: "Generate Changelog", category: .tools, icon: "list.bullet.rectangle") {},
            UserCommand(id: "tools.calculateMetrics", title: "Calculate Metrics", category: .tools, icon: "chart.bar.doc.horizontal") {},
            UserCommand(id: "tools.snippets", title: "Open Snippet Library", category: .tools, icon: "text.quote") {},
            UserCommand(id: "tools.bookmarks", title: "Show Bookmarks", category: .tools, icon: "bookmark") {},
            UserCommand(id: "tools.metrics", title: "Show Code Metrics", category: .tools, icon: "chart.bar") {},

            // Settings
            UserCommand(id: "settings.open", title: "Open Settings", category: .settings, icon: "gearshape", shortcut: KeyboardShortcuts.settings) {
                WorkspaceState.shared.bottomPanel = .settings
            },
            UserCommand(id: "settings.providers", title: "AI Provider Settings", category: .settings, icon: "key") {},
            UserCommand(id: "settings.models", title: "Model Settings", category: .settings, icon: "cpu") {},
            UserCommand(id: "settings.agents", title: "Agent Settings", category: .settings, icon: "person.3") {},
            UserCommand(id: "settings.editor", title: "Editor Settings", category: .settings, icon: "pencil") {},
            UserCommand(id: "settings.appearance", title: "Appearance Settings", category: .settings, icon: "paintpalette") {},
            UserCommand(id: "settings.remote", title: "Remote PC Settings", category: .settings, icon: "pc") {},
            UserCommand(id: "settings.github", title: "GitHub Settings", category: .settings, icon: "network") {},
            UserCommand(id: "settings.theme", title: "Change Theme", category: .settings, icon: "paintpalette") {},
            UserCommand(id: "settings.shortcuts", title: "Keyboard Shortcuts", category: .settings, icon: "keyboard") {},

            // Help
            UserCommand(id: "help.quickStart", title: "Quick Start Guide", category: .help, icon: "book") {},
            UserCommand(id: "help.documentation", title: "Documentation", category: .help, icon: "books.vertical") {},
            UserCommand(id: "help.agents", title: "Agent Catalog", category: .help, icon: "person.3") {},
            UserCommand(id: "help.tools", title: "Tool Catalog", category: .help, icon: "hammer") {},
            UserCommand(id: "help.templates", title: "Project Templates", category: .help, icon: "square.stack.3d.up") {},
            UserCommand(id: "help.remote", title: "Remote PC Help", category: .help, icon: "pc") {},
            UserCommand(id: "help.about", title: "About Adventure Coder", category: .help, icon: "info.circle") {},
        ]
    }

    // MARK: - Search

    public func search(_ query: String) -> [UserCommand] {
        if query.isEmpty { return allCommands }
        let lowered = query.lowercased()
        return allCommands.filter { $0.title.lowercased().contains(lowered) || $0.category.rawValue.lowercased().contains(lowered) }
    }

    public func commands(in category: CommandCategory) -> [UserCommand] {
        allCommands.filter { $0.category == category }
    }

    // MARK: - Execution

    public func execute(_ command: UserCommand) {
        Task { @MainActor in command.action() }
        // Track recent
        recentCommands.removeAll { $0.id == command.id }
        recentCommands.insert(command, at: 0)
        if recentCommands.count > 10 {
            recentCommands = Array(recentCommands.prefix(10))
        }
    }

    public func execute(id: String) {
        guard let command = allCommands.first(where: { $0.id == id }) else { return }
        execute(command)
    }

    // MARK: - Favorites

    public func toggleFavorite(_ command: UserCommand) {
        if favorites.contains(command.id) {
            favorites.remove(command.id)
        } else {
            favorites.insert(command.id)
        }
        saveFavorites()
    }

    public var favoriteCommands: [UserCommand] {
        allCommands.filter { favorites.contains($0.id) }
    }

    // MARK: - Persistence

    private func saveFavorites() {
        defaults.set(Array(favorites), forKey: "command_favorites")
    }

    private func loadFavorites() {
        if let favs = defaults.stringArray(forKey: "command_favorites") {
            favorites = Set(favs)
        }
    }
}

/// Menu bar view that shows all commands organized by category.
public struct CommandMenuBarView: View {
    @StateObject private var commandManager = CommandManager.shared

    public init() {}

    public var body: some View {
        List {
            ForEach(CommandManager.CommandCategory.allCases, id: \.self) { category in
                let commands = commandManager.commands(in: category)
                if !commands.isEmpty {
                    Section(category.rawValue) {
                        ForEach(commands) { command in
                            Button(action: { commandManager.execute(command) }) {
                                HStack {
                                    Image(systemName: command.icon)
                                        .foregroundColor(MonoColor.tertiaryText)
                                        .frame(width: 20)
                                    Text(command.title)
                                        .font(MonoType.body)
                                        .foregroundColor(MonoColor.primaryText)
                                    Spacer()
                                    if let shortcut = command.shortcut {
                                        ShortcutKeysView(shortcut: shortcut)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Commands")
    }
}
