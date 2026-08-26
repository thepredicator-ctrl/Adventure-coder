import SwiftUI

/// Comprehensive settings page that configures everything in the app.
/// This is a full-screen settings experience with all configurable options.
public struct CompleteSettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var auth = AuthManager.shared
    @StateObject private var remoteStore = RemotePCStore.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Account section
                accountSection

                // AI Providers
                aiProvidersSection

                // Models
                modelsSection

                // Agents
                agentsSection

                // Remote PC
                remotePCSection

                // GitHub
                githubSection

                // Editor
                editorSection

                // Appearance
                appearanceSection

                // Security
                securitySection

                // About
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.black.opacity(0.9))
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section("Account") {
            if let user = auth.currentUser {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text(user.displayName.prefix(1).uppercased())
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text(user.email)
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.5))
                        Text(user.plan.displayName + " Plan")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.4))
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                NavigationLink {
                    AccountDetailSettingsView()
                } label: {
                    Label("Account Details", systemImage: "person.circle")
                }

                Button(role: .destructive) {
                    auth.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } else {
                Label("Not signed in", systemImage: "person.crop.circle.badge.questionmark")
                    .foregroundColor(Color(white: 0.5))
            }
        }
        .listRowBackground(Color.white.opacity(0.02))
    }

    // MARK: - AI Providers

    private var aiProvidersSection: some View {
        Section("AI Providers") {
            NavigationLink {
                ProviderSettingsView(providerId: "openrouter")
            } label: {
                HStack {
                    Label("OpenRouter", systemImage: "network")
                    Spacer()
                    if KeychainService.has(.openRouterAPIKey) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                    } else {
                        Text("Not set")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.4))
                    }
                }
            }

            NavigationLink {
                ProviderSettingsView(providerId: "huggingface")
            } label: {
                HStack {
                    Label("Hugging Face", systemImage: "face.smiling")
                    Spacer()
                    if KeychainService.has(.huggingFaceToken) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                    } else {
                        Text("Not set")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.4))
                    }
                }
            }
        }
        .listRowBackground(Color.white.opacity(0.02))
    }

    // MARK: - Models

    private var modelsSection: some View {
        Section("Models") {
            Toggle("Free models only", isOn: $settings.freeModelsOnly)
            Toggle("Allow paid models", isOn: $settings.allowPaidModels)

            NavigationLink {
                ModelSelectionSettingsView()
            } label: {
                Label("Model Selection", systemImage: "cpu")
            }
        }
        .listRowBackground(Color.white.opacity(0.02))
    }

    // MARK: - Agents

    private var agentsSection: some View {
        Section("Agents") {
            NavigationLink {
                AgentSettingsView()
            } label: {
                HStack {
                    Label("Agents", systemImage: "person.3")
                    Spacer()
                    Text("\(settings.enabledAgents.count} enabled")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.4))
                }
            }
            Toggle("Parallel agent execution", isOn: $settings.parallelAgentExecution)
            Toggle("Auto-repair failed builds", isOn: $settings.autoRepairBuilds)
        }
        .listRowBackground(Color.white.opacity(0.02))
    }

    // MARK: - Remote PC

    private var remotePCSection: some View {
        Section("Remote PC") {
            NavigationLink {
                RemoteSettingsView()
            } label: {
                HStack {
                    Label("Remote Machines", systemImage: "pc")
                    Spacer()
                    if remoteStore.isConnected {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Text("Connected")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.4))
                        }
                    } else {
                        Text("Disconnected")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.4))
                    }
                }
            }
        }
        .listRowBackground(Color.white.opacity(0.02))
    }

    // MARK: - GitHub

    private var githubSection: some View {
        Section("GitHub") {
            NavigationLink {
                GitHubSettingsView()
            } label: {
                HStack {
                    Label("GitHub Account", systemImage: "network")
                    Spacer()
                    if KeychainService.has(.githubToken) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                    } else {
                        Text("Not set")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.4))
                    }
                }
            }
        }
        .listRowBackground(Color.white.opacity(0.02))
    }

    // MARK: - Editor

    private var editorSection: some View {
        Section("Editor") {
            HStack {
                Text("Font")
                Spacer()
                TextField("SF Mono", text: $settings.editorFont)
                    .font(.system(size: 13, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }
            Stepper("Font Size: \(settings.editorFontSize)", value: $settings.editorFontSize, in: 9...24)
            Stepper("Tab Size: \(settings.editorTabSize)", value: $settings.editorTabSize, in: 2...8)
            Toggle("Show line numbers", isOn: $settings.editorShowLineNumbers)
            Toggle("Word wrap", isOn: $settings.editorWordWrap)
        }
        .listRowBackground(Color.white.opacity(0.02))
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Appearance", selection: $settings.appearance) {
                ForEach(SettingsStore.Appearance.allCases, id: \.self) { appearance in
                    Text(appearance.displayName).tag(appearance)
                }
            }
            NavigationLink {
                ThemePickerView()
            } label: {
                Label("Themes", systemImage: "paintpalette")
            }
        }
        .listRowBackground(Color.white.opacity(0.02))
    }

    // MARK: - Security

    private var securitySection: some View {
        Section("Security") {
            Label("SSH keys in Keychain", systemImage: "lock.shield")
                .foregroundColor(Color(white: 0.6))
            Label("Host key verification", systemImage: "checkmark.shield")
                .foregroundColor(Color(white: 0.6))
            Label("Secret detection enabled", systemImage: "eye.slash")
                .foregroundColor(Color(white: 0.6))

            Button(role: .destructive) {
                auth.deleteAccount()
            } label: {
                Label("Delete Account & All Data", systemImage: "trash")
            }
        }
        .listRowBackground(Color.white.opacity(0.02))
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.4))
            }
            HStack {
                Text("Build")
                Spacer()
                Text("1")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.4))
            }
            HStack {
                Text("Agents")
                Spacer()
                Text("\(AgentRegistry.shared.count)")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.4))
            }
            HStack {
                Text("Tools")
                Spacer()
                Text("\(ToolRegistry.shared.tools.count)")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.4))
            }
            NavigationLink {
                HelpSystemView()
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
            NavigationLink {
                KeyboardShortcutsView()
            } label: {
                Label("Keyboard Shortcuts", systemImage: "keyboard")
            }
        }
        .listRowBackground(Color.white.opacity(0.02))
    }
}

// MARK: - Account Detail

struct AccountDetailSettingsView: View {
    @StateObject private var auth = AuthManager.shared
    @State private var displayName = ""

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display Name", text: $displayName)
                    .onAppear { displayName = auth.currentUser?.displayName ?? "" }
                if let user = auth.currentUser {
                    LabeledContent("Email", value: user.email)
                    LabeledContent("Member Since", value: user.createdAt.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Plan", value: user.plan.displayName)
                }
            }

            Section("Plan") {
                ForEach(UserAccount.Plan.allCases, id: \.self) { plan in
                    Button(action: { auth.upgradeToPlan(plan) }) {
                        HStack {
                            Text(plan.displayName)
                            Spacer()
                            if auth.currentUser?.plan == plan {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Danger Zone") {
                Button("Sign Out", role: .destructive) {
                    auth.signOut()
                }
                Button("Delete Account & All Data", role: .destructive) {
                    auth.deleteAccount()
                }
            }
        }
        .navigationTitle("Account")
        .scrollContentBackground(.hidden)
        .background(Color.black.opacity(0.9))
    }
}

// MARK: - Provider Settings

struct ProviderSettingsView: View {
    let providerId: String
    @State private var key = ""
    @State private var testResult = ""
    @State private var testing = false

    var body: some View {
        Form {
            Section("API Key") {
                SecureField("Enter key", text: $key)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)

                HStack {
                    Button("Save") { saveKey() }
                    Button("Test") { testConnection() }
                    Button("Delete", role: .destructive) { deleteKey() }
                }
            }

            if testing {
                ProgressView("Testing…")
            }

            if !testResult.isEmpty {
                Text(testResult)
                    .font(.system(size: 13))
                    .foregroundColor(testResult.contains("Connected") ? .green : .red)
            }

            Section("Stored Key") {
                Text(maskedKey)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(white: 0.5))
            }

            Section("How to get a key") {
                Text(helpText)
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.5))
            }
        }
        .navigationTitle(providerName)
        .scrollContentBackground(.hidden)
        .background(Color.black.opacity(0.9))
    }

    private var providerName: String {
        providerId == "openrouter" ? "OpenRouter" : "Hugging Face"
    }

    private var keychainKey: KeychainService.Key {
        providerId == "openrouter" ? .openRouterAPIKey : .huggingFaceToken
    }

    private var maskedKey: String {
        KeychainService.masked(keychainKey)
    }

    private var helpText: String {
        providerId == "openrouter"
            ? "Sign in at openrouter.ai, open Settings → Keys, and create a key. Adventure Coder stores it in the iOS Keychain and sends it only to OpenRouter over HTTPS."
            : "Sign in at huggingface.co, open Settings → Access Tokens, and create a token with read scope. Adventure Coder stores it in the iOS Keychain."
    }

    private func saveKey() {
        _ = KeychainService.save(keychainKey, value: key)
        key = ""
        testResult = "Saved."
    }

    private func deleteKey() {
        _ = KeychainService.delete(keychainKey)
        testResult = "Deleted."
    }

    private func testConnection() {
        testing = true
        testResult = ""
        Task {
            let result: ProviderTestResult
            if providerId == "openrouter" {
                result = await OpenRouterProvider().testConnection()
            } else {
                result = await HuggingFaceProvider().testConnection()
            }
            testResult = result.success ? "Connected. \(result.modelsDiscovered) models found." : result.message
            testing = false
        }
    }
}

// MARK: - Model Selection Settings

struct ModelSelectionSettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var modelStore = CachedModelStore.shared

    var body: some View {
        Form {
            Section("Routing") {
                Toggle("Free models only", isOn: $settings.freeModelsOnly)
                Toggle("Allow paid models", isOn: $settings.allowPaidModels)
            }

            Section("Primary Model") {
                modelPicker($settings.primaryModelId)
            }
            Section("Coding Model") {
                modelPicker($settings.codingModelId)
            }
            Section("Planning Model") {
                modelPicker($settings.planningModelId)
            }
            Section("Review Model") {
                modelPicker($settings.reviewModelId)
            }
            Section("Fast Model") {
                modelPicker($settings.fastModelId)
            }

            Section {
                Button("Refresh Models") {
                    Task { await modelStore.refresh() }
                }
                if modelStore.isRefreshing {
                    ProgressView()
                }
            }
        }
        .navigationTitle("Models")
        .scrollContentBackground(.hidden)
        .background(Color.black.opacity(0.9))
        .task { await modelStore.refresh() }
    }

    @ViewBuilder
    private func modelPicker(_ binding: Binding<String?>) -> some View {
        Picker("Model", selection: binding) {
            Text("Automatic").tag(String?.none)
            ForEach(modelStore.models) { model in
                Text("\(model.displayName) (\(model.displayPrice))").tag(Optional(model.modelId))
            }
        }
    }
}

// MARK: - Agent Settings

struct AgentSettingsView: View {
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        Form {
            ForEach(AgentCategory.allCases, id: \.self) { category in
                Section(category.displayName + " (\(AgentRegistry.shared.agents(in: category).count))") {
                    ForEach(AgentRegistry.shared.agents(in: category)) { agent in
                        Toggle(agent.name, isOn: Binding(
                            get: { settings.isAgentEnabled(agent.agentId) },
                            set: { settings.setAgent(agent.agentId, enabled: $0) }
                        ))
                    }
                }
            }
        }
        .navigationTitle("Agents (\(AgentRegistry.shared.count))")
        .scrollContentBackground(.hidden)
        .background(Color.black.opacity(0.9))
    }
}
