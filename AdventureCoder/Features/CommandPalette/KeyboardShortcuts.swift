import Foundation
import SwiftUI

/// Centralized keyboard shortcut management system.
/// Defines all keyboard shortcuts used throughout the application.
public struct KeyboardShortcuts {
    public struct Shortcut: Hashable {
        public let key: KeyEquivalent
        public let modifiers: EventModifiers
        public let description: String

        public init(key: KeyEquivalent, modifiers: EventModifiers = .command, description: String) {
            self.key = key
            self.modifiers = modifiers
            self.description = description
        }
    }

    // File operations
    public static let newFile = Shortcut(key: "n", modifiers: [.command], description: "New File")
    public static let openFile = Shortcut(key: "o", modifiers: [.command], description: "Open File")
    public static let saveFile = Shortcut(key: "s", modifiers: [.command], description: "Save File")
    public static let closeTab = Shortcut(key: "w", modifiers: [.command], description: "Close Tab")

    // Edit operations
    public static let find = Shortcut(key: "f", modifiers: [.command], description: "Find")
    public static let findReplace = Shortcut(key: "f", modifiers: [.command, .option], description: "Find & Replace")
    public static let undo = Shortcut(key: "z", modifiers: [.command], description: "Undo")
    public static let redo = Shortcut(key: "z", modifiers: [.command, .shift], description: "Redo")
    public static let goToLine = Shortcut(key: "l", modifiers: [.command], description: "Go to Line")

    // Navigation
    public static let commandPalette = Shortcut(key: "k", modifiers: [.command], description: "Command Palette")
    public static let globalSearch = Shortcut(key: "f", modifiers: [.command, .shift], description: "Global Search")
    public static let quickOpen = Shortcut(key: "p", modifiers: [.command], description: "Quick Open File")

    // Workspace
    public static let toggleSidebar = Shortcut(key: "b", modifiers: [.command], description: "Toggle Sidebar")
    public static let toggleTerminal = Shortcut(key: "t", modifiers: [.command], description: "Toggle Terminal")
    public static let togglePreview = Shortcut(key: "p", modifiers: [.command, .option], description: "Toggle Preview")
    public static let toggleAIChat = Shortcut(key: "j", modifiers: [.command], description: "Toggle AI Chat")

    // Build / Run
    public static let build = Shortcut(key: "b", modifiers: [.command, .shift], description: "Build Project")
    public static let run = Shortcut(key: "r", modifiers: [.command], description: "Run Project")
    public static let test = Shortcut(key: "u", modifiers: [.command], description: "Run Tests")
    public static let stop = Shortcut(key: ".", modifiers: [.command], description: "Stop")

    // Git
    public static let gitStatus = Shortcut(key: "g", modifiers: [.control], description: "Git Status")
    public static let gitCommit = Shortcut(key: "c", modifiers: [.control, .shift], description: "Git Commit")
    public static let gitPush = Shortcut(key: "p", modifiers: [.control, .shift], description: "Git Push")
    public static let gitPull = Shortcut(key: "l", modifiers: [.control, .shift], description: "Git Pull")

    // AI
    public static let askAI = Shortcut(key: "i", modifiers: [.command], description: "Ask AI")
    public static let switchModel = Shortcut(key: "m", modifiers: [.control], description: "Switch Model")
    public static let switchAgent = Shortcut(key: "a", modifiers: [.control], description: "Switch Agent")

    // Settings
    public static let settings = Shortcut(key: ",", modifiers: [.command], description: "Settings")

    // Terminal
    public static let newTerminal = Shortcut(key: "t", modifiers: [.command, .shift], description: "New Terminal")
    public static let clearTerminal = Shortcut(key: "k", modifiers: [.command, .shift], description: "Clear Terminal")

    /// All shortcuts for display in the shortcuts help view.
    public static let all: [(category: String, shortcuts: [Shortcut])] = [
        ("File", [newFile, openFile, saveFile, closeTab]),
        ("Edit", [find, findReplace, undo, redo, goToLine]),
        ("Navigation", [commandPalette, globalSearch, quickOpen]),
        ("Workspace", [toggleSidebar, toggleTerminal, togglePreview, toggleAIChat]),
        ("Build & Run", [build, run, test, stop]),
        ("Git", [gitStatus, gitCommit, gitPush, gitPull]),
        ("AI", [askAI, switchModel, switchAgent]),
        ("Terminal", [newTerminal, clearTerminal]),
        ("Settings", [settings]),
    ]
}

/// A view that displays all keyboard shortcuts.
public struct KeyboardShortcutsView: View {
    public init() {}

    public var body: some View {
        List {
            ForEach(KeyboardShortcuts.all, id: \.category) { category in
                Section(category.category) {
                    ForEach(category.shortcuts.indices, id: \.self) { idx in
                        let shortcut = category.shortcuts[idx]
                        HStack {
                            Text(shortcut.description)
                                .font(MonoType.body)
                                .foregroundColor(MonoColor.primaryText)
                            Spacer()
                            ShortcutKeysView(shortcut: shortcut)
                        }
                    }
                }
            }
        }
        .navigationTitle("Keyboard Shortcuts")
    }
}

/// Displays the key combination for a shortcut.
public struct ShortcutKeysView: View {
    let shortcut: KeyboardShortcuts.Shortcut

    public var body: some View {
        HStack(spacing: MonoSpace.xxs) {
            ForEach(keyLabels.indices, id: \.self) { idx in
                Text(keyLabels[idx])
                    .font(MonoType.caption.weight(.medium))
                    .foregroundColor(MonoColor.secondaryText)
                    .padding(.horizontal, MonoSpace.xs)
                    .padding(.vertical, 2)
                    .background(MonoColor.inset)
                    .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadiusSm))
            }
        }
    }

    private var keyLabels: [String] {
        var labels: [String] = []
        if shortcut.modifiers.contains(.command) { labels.append("⌘") }
        if shortcut.modifiers.contains(.shift) { labels.append("⇧") }
        if shortcut.modifiers.contains(.option) { labels.append("⌥") }
        if shortcut.modifiers.contains(.control) { labels.append("⌃") }
        labels.append(shortcut.key.character.uppercased())
        return labels
    }
}

/// A command system that maps commands to actions.
public final class CommandSystem: ObservableObject {
    public static let shared = CommandSystem()

    public struct Command: Identifiable, Hashable {
        public let id: String
        public let title: String
        public let category: String
        public let icon: String
        public let shortcut: KeyboardShortcuts.Shortcut?
        public let action: () -> Void
    }

    @Published public var commands: [Command] = []

    private init() {
        registerDefaultCommands()
    }

    private func registerDefaultCommands() {
        commands = [
            Command(id: "new_file", title: "New File", category: "File", icon: MonoIcon.docPlus, shortcut: .newFile) {
                WorkspaceState.shared.bottomPanel = .newProject
            },
            Command(id: "save", title: "Save File", category: "File", icon: "arrow.down.to.line", shortcut: .saveFile) {},
            Command(id: "find", title: "Find", category: "Edit", icon: MonoIcon.search, shortcut: .find) {},
            Command(id: "command_palette", title: "Command Palette", category: "Navigation", icon: MonoIcon.command, shortcut: .commandPalette) {
                WorkspaceState.shared.showCommandPalette = true
            },
            Command(id: "global_search", title: "Global Search", category: "Navigation", icon: MonoIcon.search, shortcut: .globalSearch) {
                WorkspaceState.shared.showGlobalSearch = true
            },
            Command(id: "toggle_sidebar", title: "Toggle Sidebar", category: "View", icon: MonoIcon.sidebar, shortcut: .toggleSidebar) {
                WorkspaceState.shared.sidebarCollapsed.toggle()
            },
            Command(id: "toggle_terminal", title: "Toggle Terminal", category: "View", icon: MonoIcon.terminal, shortcut: .toggleTerminal) {
                WorkspaceState.shared.terminalCollapsed.toggle()
            },
            Command(id: "toggle_ai_chat", title: "Toggle AI Chat", category: "View", icon: MonoIcon.sparkles, shortcut: .toggleAIChat) {
                WorkspaceState.shared.chatCollapsed.toggle()
            },
            Command(id: "build", title: "Build Project", category: "Build", icon: MonoIcon.build, shortcut: .build) {
                WorkspaceState.shared.bottomPanel = .builds
            },
            Command(id: "settings", title: "Settings", category: "Settings", icon: MonoIcon.settings, shortcut: .settings) {
                WorkspaceState.shared.bottomPanel = .settings
            },
        ]
    }

    public func search(_ query: String) -> [Command] {
        if query.isEmpty { return commands }
        return commands.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    public func execute(_ command: Command) {
        command.action()
    }
}
