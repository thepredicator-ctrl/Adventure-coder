import SwiftUI
import Foundation

/// User account model.
public struct UserAccount: Codable, Hashable {
    public var id: UUID
    public var email: String
    public var displayName: String
    public var avatarURL: String?
    public var plan: Plan
    public var createdAt: Date
    public var lastSignInAt: Date?

    public enum Plan: String, Codable, CaseIterable {
        case free, pro, team

        public var displayName: String {
            switch self {
            case .free: return "Free"
            case .pro: return "Pro"
            case .team: return "Team"
            }
        }
    }

    public init(id: UUID = UUID(), email: String, displayName: String, avatarURL: String? = nil, plan: Plan = .free, createdAt: Date = Date(), lastSignInAt: Date? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.plan = plan
        self.createdAt = createdAt
        self.lastSignInAt = lastSignInAt
    }
}

/// Authentication manager that handles sign-in, sign-out, and session persistence.
@MainActor
public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()

    @Published public var currentUser: UserAccount?
    @Published public var isSignedIn: Bool = false
    @Published public var isAuthenticating: Bool = false
    @Published public var authError: String?

    private let defaults = UserDefaults.standard
    private let sessionKey = "auth.session"

    private init() {
        loadSession()
    }

    // MARK: - Sign In

    public func signIn(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            authError = "Please enter your email and password."
            return
        }
        guard email.contains("@") else {
            authError = "Please enter a valid email address."
            return
        }
        guard password.count >= 6 else {
            authError = "Password must be at least 6 characters."
            return
        }

        isAuthenticating = true
        authError = nil
        try? await Task.sleep(nanoseconds: 800_000_000)

        let displayName = email.split(separator: "@").first.map { String($0).capitalized } ?? "User"
        let user = UserAccount(email: email, displayName: displayName, plan: .free, lastSignInAt: Date())
        let token = "session_\(UUID().uuidString)"

        self.currentUser = user
        self.isSignedIn = true
        self.isAuthenticating = false
        self.saveSession(user: user, token: token)
    }

    public func signUp(email: String, password: String, displayName: String) async {
        guard !email.isEmpty, !password.isEmpty, !displayName.isEmpty else {
            authError = "Please fill in all fields."
            return
        }
        guard email.contains("@") else {
            authError = "Please enter a valid email address."
            return
        }
        guard password.count >= 6 else {
            authError = "Password must be at least 6 characters."
            return
        }

        isAuthenticating = true
        authError = nil
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let user = UserAccount(email: email, displayName: displayName, plan: .free, lastSignInAt: Date())
        let token = "session_\(UUID().uuidString)"

        self.currentUser = user
        self.isSignedIn = true
        self.isAuthenticating = false
        self.saveSession(user: user, token: token)
    }

    public func signOut() {
        currentUser = nil
        isSignedIn = false
        defaults.removeObject(forKey: sessionKey)
        KeychainService.delete("auth.token")
    }

    public func deleteAccount() {
        signOut()
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
        KeychainService.delete(.openRouterAPIKey)
        KeychainService.delete(.huggingFaceToken)
        KeychainService.delete(.githubToken)
    }

    public func updateDisplayName(_ name: String) {
        guard var user = currentUser else { return }
        user.displayName = name
        currentUser = user
        saveSession(user: user, token: KeychainService.load("auth.token") ?? "")
    }

    public func upgradeToPlan(_ plan: UserAccount.Plan) {
        guard var user = currentUser else { return }
        user.plan = plan
        currentUser = user
        saveSession(user: user, token: KeychainService.load("auth.token") ?? "")
    }

    private func saveSession(user: UserAccount, token: String) {
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: sessionKey)
        }
        KeychainService.save("auth.token", value: token)
    }

    private func loadSession() {
        if let data = defaults.data(forKey: sessionKey),
           let user = try? JSONDecoder().decode(UserAccount.self, from: data),
           KeychainService.has("auth.token") {
            currentUser = user
            isSignedIn = true
        }
    }
}

// MARK: - Sign In View

public struct SignInView: View {
    @StateObject private var auth = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case email, password, displayName
    }

    public init() {}

    public var body: some View {
        ZStack {
            SubtleCRTBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "chevron.left.slash.chevron.right")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.white)
                        Text("Adventure Coder")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                        Text(isSignUp ? "Create your account" : "Sign in to your workspace")
                            .font(.system(size: 14))
                            .foregroundColor(Color(white: 0.5))
                    }
                    .padding(.top, 20)

                    VStack(spacing: 16) {
                        if isSignUp {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Display Name")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.5))
                                TextField("Your Name", text: $displayName)
                                    .font(.system(size: 14))
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(focusedField == .displayName ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1))
                                    .focused($focusedField, equals: .displayName)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.5))
                            TextField("you@example.com", text: $email)
                                .font(.system(size: 14))
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(focusedField == .email ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1))
                                .focused($focusedField, equals: .email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.5))
                            HStack {
                                SecureField("••••••••", text: $password)
                                    .font(.system(size: 14))
                                    .textFieldStyle(.plain)
                                    .focused($focusedField, equals: .password)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(focusedField == .password ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1))
                        }
                    }
                    .frame(maxWidth: 380)

                    if let error = auth.authError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .frame(maxWidth: 380)
                    }

                    Button(action: signIn) {
                        HStack {
                            if auth.isAuthenticating {
                                ProgressView().tint(.white)
                            }
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSubmit ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit || auth.isAuthenticating)
                    .frame(maxWidth: 380)

                    Button(action: { isSignUp.toggle(); auth.authError = nil }) {
                        Text(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Sign up")
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.5))
                    }
                    .buttonStyle(.plain)

                    Divider().background(Color.white.opacity(0.05)).frame(maxWidth: 380)

                    Button(action: continueAsGuest) {
                        Text("Continue as Guest")
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.4))
                    }
                    .buttonStyle(.plain)

                    Text("Your credentials are stored securely in the iOS Keychain. Adventure Coder never sends your password to any server.")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.3))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)
                        .padding(.horizontal)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var canSubmit: Bool {
        if isSignUp { return !email.isEmpty && !password.isEmpty && !displayName.isEmpty }
        return !email.isEmpty && !password.isEmpty
    }

    private func signIn() {
        Task {
            if isSignUp {
                await auth.signUp(email: email, password: password, displayName: displayName)
            } else {
                await auth.signIn(email: email, password: password)
            }
        }
    }

    private func continueAsGuest() {
        let user = UserAccount(email: "guest@adventurecoder.app", displayName: "Guest", plan: .free)
        auth.currentUser = user
        auth.isSignedIn = true
        let token = "guest_\(UUID().uuidString)"
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "auth.session")
        }
        KeychainService.save("auth.token", value: token)
    }
}
