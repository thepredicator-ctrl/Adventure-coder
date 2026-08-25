import SwiftUI

/// Comprehensive settings view.
public struct SettingsView: View {
    @StateObject private var settings = SettingsStore.shared

    public init() {}

    public var body: some View {
        Form {
            Section("Account") {
                NavigationLink("Account") { AccountSettingsView() }
            }
            Section("AI Providers") {
                NavigationLink("OpenRouter") { OpenRouterSettingsView() }
                NavigationLink("Hugging Face") { HuggingFaceSettingsView() }
            }
            Section("Models") {
                NavigationLink("Model Selection") { ModelsSettingsView() }
                Toggle("Free models only", isOn: $settings.freeModelsOnly)
                Toggle("Allow paid models", isOn: $settings.allowPaidModels)
            }
            Section("Agents") {
                NavigationLink("Agents") { AgentsSettingsView() }
                Toggle("Parallel agent execution", isOn: $settings.parallelAgentExecution)
                Toggle("Auto-repair failed builds", isOn: $settings.autoRepairBuilds)
            }
            Section("GitHub") {
                NavigationLink("GitHub Account") { GitHubSettingsView() }
            }
            Section("Remote PC") {
                NavigationLink("Remote Machines") { RemoteSettingsView() }
            }
            Section("Editor") {
                NavigationLink("Editor") { EditorSettingsView() }
            }
            Section("Appearance") {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(SettingsStore.Appearance.allCases, id: \.self) { appearance in
                        Text(appearance.displayName).tag(appearance)
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct AccountSettingsView: View {
    @State private var login = ""
    var body: some View {
        Form {
            Section("Login") {
                TextField("Email or username", text: $login)
                Button("Log in") {}
                    .disabled(login.isEmpty)
            }
            Section("Danger Zone") {
                Button("Log out", role: .destructive) {}
                Button("Delete account", role: .destructive) {}
            }
        }
        .navigationTitle("Account")
    }
}

struct OpenRouterSettingsView: View {
    @State private var key: String = ""
    @State private var testResult: String = ""
    @State private var testing = false

    var body: some View {
        Form {
            Section("API Key") {
                SecureField("OpenRouter API key", text: $key)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                HStack {
                    Button("Save") { save() }
                        .disabled(key.isEmpty)
                    Button("Test") {
                        testing = true
                        Task {
                            let result = await OpenRouterProvider().testConnection()
                            testResult = result.message
                            testing = false
                        }
                    }
                    .disabled(testing || !KeychainService.has(.openRouterAPIKey))
                    Button("Delete", role: .destructive) {
                        _ = KeychainService.delete(.openRouterAPIKey)
                        testResult = ""
                    }
                    .disabled(!KeychainService.has(.openRouterAPIKey))
                }
                if testing { ProgressView() }
                if !testResult.isEmpty {
                    Text(testResult)
                        .font(MonoType.footnote)
                        .foregroundColor(MonoColor.secondaryText)
                }
            }
            Section("Stored Key") {
                Text(KeychainService.masked(.openRouterAPIKey))
                    .font(MonoType.codeBody)
                    .foregroundColor(MonoColor.secondaryText)
            }
            Section("How to get a key") {
                Text("Sign in at openrouter.ai, open Settings → Keys, and create a key. Adventure Coder stores it in the iOS Keychain and sends it only to OpenRouter over HTTPS.")
                    .font(MonoType.footnote)
                    .foregroundColor(MonoColor.secondaryText)
            }
        }
        .navigationTitle("OpenRouter")
    }

    private func save() {
        _ = KeychainService.save(.openRouterAPIKey, value: key)
        key = ""
        testResult = "Saved."
    }
}

struct HuggingFaceSettingsView: View {
    @State private var token: String = ""
    @State private var testResult: String = ""
    @State private var testing = false

    var body: some View {
        Form {
            Section("Access Token") {
                SecureField("Hugging Face access token", text: $token)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                HStack {
                    Button("Save") { save() }
                        .disabled(token.isEmpty)
                    Button("Test") {
                        testing = true
                        Task {
                            let result = await HuggingFaceProvider().testConnection()
                            testResult = result.message
                            testing = false
                        }
                    }
                    .disabled(testing || !KeychainService.has(.huggingFaceToken))
                    Button("Delete", role: .destructive) {
                        _ = KeychainService.delete(.huggingFaceToken)
                        testResult = ""
                    }
                    .disabled(!KeychainService.has(.huggingFaceToken))
                }
                if testing { ProgressView() }
                if !testResult.isEmpty {
                    Text(testResult)
                        .font(MonoType.footnote)
                        .foregroundColor(MonoColor.secondaryText)
                }
            }
            Section("Stored Token") {
                Text(KeychainService.masked(.huggingFaceToken))
                    .font(MonoType.codeBody)
                    .foregroundColor(MonoColor.secondaryText)
            }
            Section("How to get a token") {
                Text("Sign in at huggingface.co, open Settings → Access Tokens, and create a token with `read` scope. Adventure Coder stores it in the iOS Keychain and sends it only to Hugging Face over HTTPS.")
                    .font(MonoType.footnote)
                    .foregroundColor(MonoColor.secondaryText)
            }
        }
        .navigationTitle("Hugging Face")
    }

    private func save() {
        _ = KeychainService.save(.huggingFaceToken, value: token)
        token = ""
        testResult = "Saved."
    }
}

struct ModelsSettingsView: View {
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
                Button("Refresh model list") {
                    Task { await modelStore.refresh() }
                }
                if modelStore.isRefreshing { ProgressView() }
            }
        }
        .navigationTitle("Models")
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

struct AgentsSettingsView: View {
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        Form {
            ForEach(AgentCategory.allCases, id: \.self) { category in
                Section(category.displayName) {
                    ForEach(AgentRegistry.shared.agents(in: category)) { agent in
                        Toggle(agent.name, isOn: Binding(
                            get: { settings.isAgentEnabled(agent.agentId) },
                            set: { settings.setAgent(agent.agentId, enabled: $0) }
                        ))
                    }
                }
            }
        }
        .navigationTitle("Agents")
    }
}

struct GitHubSettingsView: View {
    @State private var token: String = ""
    @State private var user: String = SettingsStore.shared.githubUser ?? ""
    @State private var testing = false
    @State private var testResult: String = ""

    var body: some View {
        Form {
            Section("Token") {
                SecureField("GitHub personal access token", text: $token)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                HStack {
                    Button("Save") {
                        _ = KeychainService.save(.githubToken, value: token)
                        token = ""
                    }
                    .disabled(token.isEmpty)
                    Button("Test") {
                        testing = true
                        Task {
                            let result = await testGitHub()
                            testResult = result
                            testing = false
                        }
                    }
                    .disabled(testing || !KeychainService.has(.githubToken))
                    Button("Delete", role: .destructive) {
                        _ = KeychainService.delete(.githubToken)
                        SettingsStore.shared.githubUser = nil
                        testResult = ""
                    }
                    .disabled(!KeychainService.has(.githubToken))
                }
                if testing { ProgressView() }
                if !testResult.isEmpty {
                    Text(testResult)
                        .font(MonoType.footnote)
                        .foregroundColor(MonoColor.secondaryText)
                }
            }
            Section("Stored Token") {
                Text(KeychainService.masked(.githubToken))
                    .font(MonoType.codeBody)
                    .foregroundColor(MonoColor.secondaryText)
            }
            Section("Account") {
                TextField("GitHub username", text: $user)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Save username") {
                    SettingsStore.shared.githubUser = user
                }
            }
        }
        .navigationTitle("GitHub")
    }

    private func testGitHub() async -> String {
        guard let token = KeychainService.load(.githubToken) else { return "No token stored." }
        do {
            let repos = try await GitHubService.shared.listRepositories(token: token)
            return "Connected. Found \(repos.count) repositories."
        } catch {
            return "Connection failed: \(error.localizedDescription)"
        }
    }
}

struct EditorSettingsView: View {
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section("Font") {
                TextField("Font name", text: $settings.editorFont)
                Stepper("Size: \(settings.editorFontSize)", value: $settings.editorFontSize, in: 9...24)
            }
            Section("Indentation") {
                Stepper("Tab size: \(settings.editorTabSize)", value: $settings.editorTabSize, in: 2...8)
            }
            Section("Display") {
                Toggle("Show line numbers", isOn: $settings.editorShowLineNumbers)
                Toggle("Word wrap", isOn: $settings.editorWordWrap)
            }
        }
        .navigationTitle("Editor")
    }
}
