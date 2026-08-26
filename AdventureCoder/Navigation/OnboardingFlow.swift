import SwiftUI

/// New onboarding flow shown after sign-in:
/// Step 1: Connect AI provider
/// Step 2: Optional PC connection
/// Step 3: Completion
public struct OnboardingFlow: View {
    @State private var step: OnboardingStep = .aiProvider
    @StateObject private var settings = SettingsStore.shared
    @Binding var isCompleted: Bool

    enum OnboardingStep: Int, CaseIterable {
        case aiProvider, pcConnection, completion
    }

    public init(isCompleted: Binding<Bool>) {
        self._isCompleted = isCompleted
    }

    public var body: some View {
        ZStack {
            SubtleCRTBackground()
                .ignoresSafeArea()

            VStack {
                Spacer()

                // Progress dots
                HStack(spacing: 8) {
                    ForEach(OnboardingStep.allCases, id: \.self) { s in
                        Circle()
                            .fill(s.rawValue <= step.rawValue ? Color.white.opacity(0.8) : Color.white.opacity(0.15))
                            .frame(width: 7, height: 7)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
                    }
                }
                .padding(.bottom, 32)

                // Step content
                Group {
                    switch step {
                    case .aiProvider:
                        OnboardingAIStep(onNext: { withAnimation { step = .pcConnection } }, onSkip: { withAnimation { step = .pcConnection } })
                    case .pcConnection:
                        OnboardingPCStep(onBack: { withAnimation { step = .aiProvider } }, onNext: { withAnimation { step = .completion } }, onSkip: { withAnimation { step = .completion } })
                    case .completion:
                        OnboardingCompletion(onDone: {
                            UserDefaults.standard.set(true, forKey: "onboarding_completed")
                            withAnimation(.easeInOut(duration: 0.4)) { isCompleted = true }
                        })
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.97)).animation(.spring(response: 0.5, dampingFraction: 0.85)),
                    removal: .opacity.animation(.easeIn(duration: 0.2))
                ))

                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Step 1: AI Provider

struct OnboardingAIStep: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    @State private var apiKey = ""
    @State private var selectedProvider = "OpenRouter"
    @State private var showKey = false
    @State private var testing = false
    @State private var testResult: String?
    @State private var isSuccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.white)
                Text("Connect your AI")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
                Text("Choose a provider and enter your API key to enable AI features. You can change this later in Connections.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.45))
                    .lineLimit(3)
            }

            VStack(spacing: 16) {
                // Provider picker
                HStack(spacing: 8) {
                    ForEach(["OpenRouter", "Hugging Face"], id: \.self) { provider in
                        Button(action: { selectedProvider = provider; apiKey = ""; testResult = nil }) {
                            Text(provider)
                                .font(.system(size: 13, weight: selectedProvider == provider ? .medium : .regular))
                                .foregroundColor(selectedProvider == provider ? .white : Color(white: 0.4))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(selectedProvider == provider ? Color.white.opacity(0.1) : Color.white.opacity(0.03))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }

                // API key
                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.45))
                    HStack {
                        if showKey {
                            TextField("Enter your API key", text: $apiKey)
                                .font(.system(size: 14))
                                .textFieldStyle(.plain)
                        } else {
                            SecureField("Enter your API key", text: $apiKey)
                                .font(.system(size: 14))
                                .textFieldStyle(.plain)
                        }
                        Button(action: { showKey.toggle() }) {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.4))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(isSuccess ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1)
                            .animation(.easeInOut(duration: 0.3), value: isSuccess)
                    )
                }

                // Test / status
                if testing {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white).scaleEffect(0.7)
                        Text("Testing connection…")
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.5))
                    }
                }
                if let result = testResult {
                    HStack(spacing: 6) {
                        Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isSuccess ? .green : .red)
                        Text(result)
                            .font(.system(size: 13))
                            .foregroundColor(isSuccess ? .green : .red)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }

            // Actions
            HStack(spacing: 12) {
                Button(action: testConnection) {
                    Text("Test Connection")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(apiKey.isEmpty ? Color.gray.opacity(0.2) : Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(apiKey.isEmpty || testing)

                Button(action: { saveAndContinue() }) {
                    Text("Continue")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(apiKey.isEmpty ? Color.gray.opacity(0.2) : Color.white.opacity(0.15))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(apiKey.isEmpty)
            }

            Button("Skip for now") { onSkip() }
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.35))
                .buttonStyle(.plain)
        }
        .frame(maxWidth: 420)
    }

    private func testConnection() {
        testing = true
        testResult = nil
        isSuccess = false

        // Save key first
        saveKey()

        Task {
            let result: ProviderTestResult
            if selectedProvider == "OpenRouter" {
                result = await OpenRouterProvider().testConnection()
            } else {
                result = await HuggingFaceProvider().testConnection()
            }
            await MainActor.run {
                testing = false
                isSuccess = result.success
                testResult = result.success ? "Connected! \(result.modelsDiscovered) models available." : result.message
            }
        }
    }

    private func saveKey() {
        if selectedProvider == "OpenRouter" {
            _ = KeychainService.save(.openRouterAPIKey, value: apiKey)
        } else {
            _ = KeychainService.save(.huggingFaceToken, value: apiKey)
        }
    }

    private func saveAndContinue() {
        saveKey()
        onNext()
    }
}

// MARK: - Step 2: PC Connection

struct OnboardingPCStep: View {
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void
    @State private var host = ""
    @State private var username = ""
    @State private var password = ""
    @State private var port = "22"
    @State private var testing = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "pc")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.white)
                Text("Connect your PC?")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
                Text("Optionally connect your computer via SSH to build, run, and preview projects on your PC directly from your iPad.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.45))
                    .lineLimit(3)
            }

            VStack(spacing: 14) {
                OnboardingField(title: "Host / IP", text: $host, placeholder: "192.168.1.100")
                OnboardingField(title: "Username", text: $username, placeholder: "Neth")
                HStack(spacing: 12) {
                    OnboardingField(title: "Password", text: $password, placeholder: "••••••••", isSecure: true)
                    OnboardingField(title: "Port", text: $port, placeholder: "22")
                }
            }

            if let error = error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .transition(.opacity)
            }

            // Actions
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Text("Back")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: connect) {
                    HStack {
                        if testing { ProgressView().tint(.white).scaleEffect(0.7) }
                        Text(testing ? "Connecting…" : "Set up PC")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(host.isEmpty ? Color.gray.opacity(0.2) : Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(host.isEmpty || testing)
            }

            Button("Skip for now") { onSkip() }
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.35))
                .buttonStyle(.plain)
        }
        .frame(maxWidth: 420)
    }

    private func connect() {
        testing = true
        error = nil
        let machine = RemotePC(name: host, host: host, port: Int(port) ?? 22, username: username, authMethod: .password)
        RemotePCStore.shared.addMachine(machine)
        RemotePCStore.shared.savePassword(password, for: machine)
        Task {
            let result = await RemotePCStore.shared.connect(to: machine)
            await MainActor.run {
                testing = false
                if result.success {
                    onNext()
                } else {
                    error = result.message
                    RemotePCStore.shared.removeMachine(machine)
                }
            }
        }
    }
}

// MARK: - Step 3: Completion

struct OnboardingCompletion: View {
    let onDone: () -> Void
    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
                .scaleEffect(showCheckmark ? 1.0 : 0.3)
                .opacity(showCheckmark ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showCheckmark)

            Text("You're all set.")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .opacity(showCheckmark ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.4).delay(0.3), value: showCheckmark)

            Text("Start building with AI-powered coding on your iPad.")
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.45))
                .opacity(showCheckmark ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.4).delay(0.5), value: showCheckmark)

            Spacer()

            Button(action: onDone) {
                Text("Go to Home")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .opacity(showCheckmark ? 1.0 : 0.0)
            .animation(.easeIn(duration: 0.4).delay(0.7), value: showCheckmark)
        }
        .frame(maxWidth: 380)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showCheckmark = true
            }
        }
    }
}

// MARK: - Reusable Onboarding Field

struct OnboardingField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.45))
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(.system(size: 14))
                        .textFieldStyle(.plain)
                } else {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 14))
                        .textFieldStyle(.plain)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(7)
        }
    }
}
