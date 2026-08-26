import SwiftUI

/// Theme system supporting light, dark, and custom monochrome themes.
public struct AppTheme: Hashable {
    public let name: String
    public let backgroundColor: Color
    public let panelColor: Color
    public let insetColor: Color
    public let primaryTextColor: Color
    public let secondaryTextColor: Color
    public let tertiaryTextColor: Color
    public let separatorColor: Color
    public let accentColor: Color
    public let successColor: Color
    public let warningColor: Color
    public let errorColor: Color

    public static let light = AppTheme(
        name: "Light",
        backgroundColor: Color.white,
        panelColor: Color(red: 249/255, green: 249/255, blue: 251/255),
        insetColor: Color(red: 243/255, green: 243/255, blue: 246/255),
        primaryTextColor: Color(red: 17/255, green: 17/255, blue: 23/255),
        secondaryTextColor: Color(red: 55/255, green: 55/255, blue: 60/255),
        tertiaryTextColor: Color(red: 107/255, green: 107/255, blue: 114/255),
        separatorColor: Color(red: 229/255, green: 229/255, blue: 234/255),
        accentColor: Color(red: 30/255, green: 95/255, blue: 165/255),
        successColor: Color(red: 16/255, green: 122/255, blue: 75/255),
        warningColor: Color(red: 161/255, green: 98/255, blue: 7/255),
        errorColor: Color(red: 190/255, green: 52/255, blue: 52/255)
    )

    public static let dark = AppTheme(
        name: "Dark",
        backgroundColor: Color(red: 17/255, green: 17/255, blue: 23/255),
        panelColor: Color(red: 28/255, green: 28/255, blue: 35/255),
        insetColor: Color(red: 40/255, green: 40/255, blue: 47/255),
        primaryTextColor: Color.white,
        secondaryTextColor: Color(red: 180/255, green: 180/255, blue: 186/255),
        tertiaryTextColor: Color(red: 130/255, green: 130/255, blue: 136/255),
        separatorColor: Color(red: 50/255, green: 50/255, blue: 57/255),
        accentColor: Color(red: 100/255, green: 165/255, blue: 235/255),
        successColor: Color(red: 76/255, green: 182/255, blue: 135/255),
        warningColor: Color(red: 221/255, green: 158/255, blue: 67/255),
        errorColor: Color(red: 230/255, green: 92/255, blue: 92/255)
    )

    public static let midnight = AppTheme(
        name: "Midnight",
        backgroundColor: Color.black,
        panelColor: Color(red: 12/255, green: 12/255, blue: 16/255),
        insetColor: Color(red: 20/255, green: 20/255, blue: 26/255),
        primaryTextColor: Color.white,
        secondaryTextColor: Color(red: 160/255, green: 160/255, blue: 166/255),
        tertiaryTextColor: Color(red: 100/255, green: 100/255, blue: 106/255),
        separatorColor: Color(red: 30/255, green: 30/255, blue: 36/255),
        accentColor: Color(red: 80/255, green: 145/255, blue: 215/255),
        successColor: Color(red: 56/255, green: 162/255, blue: 115/255),
        warningColor: Color(red: 201/255, green: 138/255, blue: 47/255),
        errorColor: Color(red: 210/255, green: 72/255, blue: 72/255)
    )

    public static let paper = AppTheme(
        name: "Paper",
        backgroundColor: Color(red: 252/255, green: 248/255, blue: 240/255),
        panelColor: Color(red: 245/255, green: 240/255, blue: 230/255),
        insetColor: Color(red: 235/255, green: 228/255, blue: 216/255),
        primaryTextColor: Color(red: 30/255, green: 25/255, blue: 20/255),
        secondaryTextColor: Color(red: 70/255, green: 65/255, blue: 60/255),
        tertiaryTextColor: Color(red: 120/255, green: 115/255, blue: 110/255),
        separatorColor: Color(red: 200/255, green: 193/255, blue: 181/255),
        accentColor: Color(red: 60/255, green: 80/255, blue: 120/255),
        successColor: Color(red: 40/255, green: 100/255, blue: 60/255),
        warningColor: Color(red: 140/255, green: 90/255, blue: 20/255),
        errorColor: Color(red: 160/255, green: 40/255, blue: 40/255)
    )

    public static let allThemes: [AppTheme] = [.light, .dark, .midnight, .paper]
}

/// Theme manager that persists the selected theme.
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    @Published public var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.name, forKey: "app_theme")
        }
    }

    private init() {
        let savedName = UserDefaults.standard.string(forKey: "app_theme") ?? "Light"
        currentTheme = AppTheme.allThemes.first { $0.name == savedName } ?? .light
    }

    public func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }

    public func setThemeByName(_ name: String) {
        if let theme = AppTheme.allThemes.first(where: { $0.name == name }) {
            currentTheme = theme
        }
    }
}

/// Theme picker view for settings.
public struct ThemePickerView: View {
    @StateObject private var themeManager = ThemeManager.shared

    public init() {}

    public var body: some View {
        Form {
            Section("Appearance") {
                ForEach(AppTheme.allThemes, id: \.name) { theme in
                    Button(action: { themeManager.setTheme(theme) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: MonoSpace.xxs) {
                                Text(theme.name)
                                    .font(MonoType.body)
                                    .foregroundColor(MonoColor.primaryText)
                                // Color preview
                                HStack(spacing: 2) {
                                    previewCircle(theme.backgroundColor)
                                    previewCircle(theme.panelColor)
                                    previewCircle(theme.primaryTextColor)
                                    previewCircle(theme.accentColor)
                                    previewCircle(theme.successColor)
                                }
                            }
                            Spacer()
                            if themeManager.currentTheme.name == theme.name {
                                Image(systemName: MonoIcon.check)
                                    .foregroundColor(MonoColor.active)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Editor Theme") {
                NavigationLink("Editor Colors") { EditorThemeSettingsView() }
            }
        }
        .navigationTitle("Themes")
    }

    private func previewCircle(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 16, height: 16)
            .overlay(Circle().stroke(MonoColor.hairline, lineWidth: 0.5))
    }
}

struct EditorThemeSettingsView: View {
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section("Syntax Colors") {
                colorRow("Plain Text", MonoColor.Code.plain)
                colorRow("Keywords", MonoColor.Code.keyword)
                colorRow("Types", MonoColor.Code.type)
                colorRow("Strings", MonoColor.Code.string)
                colorRow("Comments", MonoColor.Code.comment)
                colorRow("Numbers", MonoColor.Code.number)
                colorRow("Attributes", MonoColor.Code.attribute)
            }
        }
        .navigationTitle("Editor Colors")
    }

    private func colorRow(_ name: String, _ color: Color) -> some View {
        HStack {
            Text(name)
                .font(MonoType.body)
            Spacer()
            Rectangle()
                .fill(color)
                .frame(width: 40, height: 20)
                .cornerRadius(MonoSpace.cornerRadiusSm)
                .overlay(RoundedRectangle(cornerRadius: MonoSpace.cornerRadiusSm).stroke(MonoColor.hairline, lineWidth: 1))
        }
    }
}

/// Help system view.
public struct HelpSystemView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Getting Started") {
                    NavigationLink("Quick Start") { QuickStartHelpView() }
                    NavigationLink("Keyboard Shortcuts") { KeyboardShortcutsView() }
                    NavigationLink("Configuring AI Providers") { ProvidersHelpView() }
                    NavigationLink("Remote PC Setup") { RemotePCHelpView() }
                }
                Section("Features") {
                    NavigationLink("AI Agent System") { AgentsHelpView() }
                    NavigationLink("Code Editor") { EditorHelpView() }
                    NavigationLink("Git & GitHub") { GitHelpView() }
                    NavigationLink("Remote Terminal") { TerminalHelpView() }
                    NavigationLink("Live Preview") { PreviewHelpView() }
                    NavigationLink("Code Analysis") { AnalysisHelpView() }
                }
                Section("Reference") {
                    NavigationLink("Tool Catalog") { ToolCatalogHelpView() }
                    NavigationLink("Agent Catalog") { AgentCatalogHelpView() }
                    NavigationLink("Project Templates") { TemplatesHelpView() }
                }
            }
            .navigationTitle("Help")
        }
    }
}

struct QuickStartHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MonoSpace.lg) {
                helpSection("1. Create a Project", """
                Tap the + button in the Projects sidebar to create a new project. Choose a template (SwiftUI, React, Web, Python, etc.) and give your project a name.
                """)

                helpSection("2. Configure AI Providers", """
                Go to Settings → AI Providers and add your OpenRouter or Hugging Face API key. Keys are stored securely in the iOS Keychain and never leave the device except to the provider's API.
                """)

                helpSection("3. Start Coding with AI", """
                Open the AI chat panel (⌘J) and type a request like "Build a habit tracker" or "Fix the build error". The AI orchestrator will plan, code, build, and report back.
                """)

                helpSection("4. Connect a Remote PC", """
                For real compilation and preview, connect a remote PC via SSH. Go to Settings → Remote PC, add your machine's IP and credentials, then create remote projects that build and preview on your PC.
                """)

                helpSection("5. Use the Command Palette", """
                Press ⌘K to open the command palette. Search for files, commands, agents, and settings. Use ⌘F for global search.
                """)
            }
            .padding()
        }
        .navigationTitle("Quick Start")
    }

    private func helpSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: MonoSpace.sm) {
            Text(title)
                .font(MonoType.title2)
                .foregroundColor(MonoColor.primaryText)
            Text(body)
                .font(MonoType.body)
                .foregroundColor(MonoColor.secondaryText)
        }
    }
}

struct ProvidersHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MonoSpace.lg) {
                Text("AI Providers")
                    .font(MonoType.title)
                Text("Adventure Coder supports multiple AI providers. By default, free models are preferred.")
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.secondaryText)

                VStack(alignment: .leading, spacing: MonoSpace.sm) {
                    Text("OpenRouter")
                        .font(MonoType.headline)
                    Text("OpenRouter provides access to many models including free ones. Get your API key at openrouter.ai/keys.")
                        .font(MonoType.body)
                        .foregroundColor(MonoColor.secondaryText)
                }

                VStack(alignment: .leading, spacing: MonoSpace.sm) {
                    Text("Hugging Face")
                        .font(MonoType.headline)
                    Text("Hugging Face provides free inference for many open-source models. Get your token at huggingface.co/settings/tokens.")
                        .font(MonoType.body)
                        .foregroundColor(MonoColor.secondaryText)
                }
            }
            .padding()
        }
        .navigationTitle("AI Providers")
    }
}

struct RemotePCHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MonoSpace.lg) {
                Text("Remote PC Setup")
                    .font(MonoType.title)

                Text("Adventure Coder can connect to your PC via SSH for real compilation, testing, and preview hosting.")
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.secondaryText)

                VStack(alignment: .leading, spacing: MonoSpace.sm) {
                    Text("1. Install OpenSSH on your PC")
                        .font(MonoType.headline)
                    Text("On Windows, install OpenSSH Server from Settings → Apps → Optional Features. On macOS/Linux, SSH is pre-installed.")
                        .font(MonoType.body)
                        .foregroundColor(MonoColor.secondaryText)
                }

                VStack(alignment: .leading, spacing: MonoSpace.sm) {
                    Text("2. Find your PC's IP address")
                        .font(MonoType.headline)
                    Text("On Windows: run `ipconfig` in PowerShell. On macOS: `ifconfig` or System Settings → Network.")
                        .font(MonoType.body)
                        .foregroundColor(MonoColor.secondaryText)
                }

                VStack(alignment: .leading, spacing: MonoSpace.sm) {
                    Text("3. Add the machine in Settings")
                        .font(MonoType.headline)
                    Text("Go to Settings → Remote PC → Add Remote PC. Enter the host IP, port (22), username, and password.")
                        .font(MonoType.body)
                        .foregroundColor(MonoColor.secondaryText)
                }

                VStack(alignment: .leading, spacing: MonoSpace.sm) {
                    Text("4. Test the connection")
                        .font(MonoType.headline)
                    Text("Tap Test Connection. The app will detect OS, shell, CPU, RAM, and disk space.")
                        .font(MonoType.body)
                        .foregroundColor(MonoColor.secondaryText)
                }
            }
            .padding()
        }
        .navigationTitle("Remote PC Setup")
    }
}

struct AgentsHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MonoSpace.lg) {
                Text("AI Agent System")
                    .font(MonoType.title)
                Text("Adventure Coder includes \(AgentRegistry.shared.count) specialized agents across 8 categories. The orchestrator routes tasks to the right agents based on context.")
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.secondaryText)

                ForEach(AgentCategory.allCases, id: \.self) { category in
                    VStack(alignment: .leading, spacing: MonoSpace.xs) {
                        Text(category.displayName)
                            .font(MonoType.headline)
                        Text("\(AgentRegistry.shared.agents(in: category).count) agents")
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("AI Agent System")
    }
}

struct EditorHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MonoSpace.lg) {
                Text("Code Editor")
                    .font(MonoType.title)
                Text("The built-in code editor supports syntax highlighting, line numbers, search, and multi-tab editing.")
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.secondaryText)

                VStack(alignment: .leading, spacing: MonoSpace.sm) {
                    Text("Features:")
                        .font(MonoType.headline)
                    Text("• Syntax highlighting for 25+ languages\n• Line numbers\n• Find & Replace (⌘F)\n• Multi-tab editing\n• Auto-indentation\n• Live Swift syntax checking\n• Code folding\n• Bracket matching")
                        .font(MonoType.body)
                        .foregroundColor(MonoColor.secondaryText)
                }
            }
            .padding()
        }
        .navigationTitle("Code Editor")
    }
}

struct GitHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MonoSpace.lg) {
                Text("Git & GitHub")
                    .font(MonoType.title)
                Text("Adventure Coder includes a file-system-backed mini-git for local operations and GitHub API integration for remote sync.")
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.secondaryText)

                Text("Supported operations: init, status, diff, commit, branches, checkout, history, push, pull.")
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.secondaryText)
            }
            .padding()
        }
        .navigationTitle("Git & GitHub")
    }
}

struct TerminalHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MonoSpace.lg) {
                Text("Terminal")
                    .font(MonoType.title)
                Text("The terminal runs sandboxed commands locally, or connects to your remote PC via SSH for full shell access.")
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.secondaryText)

                Text("Local commands: ls, cat, grep, find, tree, head, tail, wc, echo, pwd, env, date, whoami")
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.secondaryText)
            }
            .padding()
        }
        .navigationTitle("Terminal")
    }
}

struct PreviewHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MonoSpace.lg) {
                Text("Live Preview")
                    .font(MonoType.title)
                Text("Preview HTML/CSS/JS and React projects in an embedded WKWebView. For remote projects, the preview loads from the dev server running on your PC.")
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.secondaryText)
            }
            .padding()
        }
        .navigationTitle("Live Preview")
    }
}

struct AnalysisHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MonoSpace.lg) {
                Text("Code Analysis")
                    .font(MonoType.title)
                Text("Adventure Coder includes powerful code analysis tools:")
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.secondaryText)

                Text("• Complexity analysis (cyclomatic, cognitive)\n• Duplicate code detection\n• Dead code detection\n• Security scanning\n• Dependency auditing\n• Code formatting\n• Linting\n• Test generation\n• Documentation generation")
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.secondaryText)
            }
            .padding()
        }
        .navigationTitle("Code Analysis")
    }
}

struct ToolCatalogHelpView: View {
    var body: some View {
        List {
            ForEach(ToolRegistry.shared.definitions().sorted { $0.name < $1.name }, id: \.name) { tool in
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.name)
                        .font(MonoType.codeBody)
                        .foregroundColor(MonoColor.primaryText)
                    Text(tool.summary)
                        .font(MonoType.caption)
                        .foregroundColor(MonoColor.tertiaryText)
                }
                .padding(.vertical, MonoSpace.xs)
            }
        }
        .navigationTitle("Tool Catalog (\(ToolRegistry.shared.definitions().count))")
    }
}

struct AgentCatalogHelpView: View {
    var body: some View {
        List {
            ForEach(AgentCategory.allCases, id: \.self) { category in
                Section(category.displayName) {
                    ForEach(AgentRegistry.shared.agents(in: category)) { agent in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(agent.name)
                                .font(MonoType.body)
                                .foregroundColor(MonoColor.primaryText)
                            Text(agent.role)
                                .font(MonoType.caption)
                                .foregroundColor(MonoColor.tertiaryText)
                        }
                        .padding(.vertical, MonoSpace.xs)
                    }
                }
            }
        }
        .navigationTitle("Agents (\(AgentRegistry.shared.count))")
    }
}

struct TemplatesHelpView: View {
    var body: some View {
        List {
            Section("Built-in Templates") {
                ForEach(ProjectTemplate.allCases, id: \.self) { template in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.displayName)
                            .font(MonoType.body)
                            .foregroundColor(MonoColor.primaryText)
                        Text(template.description)
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                    .padding(.vertical, MonoSpace.xs)
                }
            }
            Section("Advanced Templates") {
                Text("Flutter, Kotlin, Go, Java, C#, Vue, Svelte, Next.js, Express, Django, FastAPI, Rails, .NET MAUI")
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.secondaryText)
            }
        }
        .navigationTitle("Project Templates")
    }
}
