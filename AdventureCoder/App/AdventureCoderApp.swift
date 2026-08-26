import SwiftUI
import UIKit

/// App entry point.
@main
struct AdventureCoderApp: App {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var workspace = WorkspaceState.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(workspace)
                .preferredColorScheme(settings.colorScheme)
                .onCommandShortcut()
        }
    }
}

/// AppDelegate for keyboard shortcut handling and scene support.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

/// Scene delegate enabling multi-window support (Stage Manager, external displays).
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: RootView())
        window.makeKeyAndVisible()
        self.window = window

        // Support external displays
        if let displaySession = connectionOptions.userActivities.first(where: { $0.activityType == "com.adventurecoder.app.preview" }) {
            // Optionally render a preview-only view on the external display
            _ = displaySession
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // Handle deep links (adventurecoder://project/<id>)
        for context in URLContexts {
            _ = context.url
        }
    }
}

/// Root view: shows the adaptive layout plus global overlays.
struct RootView: View {
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var modelStore = CachedModelStore.shared

    var body: some View {
        ZStack {
            if ProjectStore.shared.projects.isEmpty && workspace.currentProject == nil {
                OnboardingView()
            } else {
                AdaptiveLayout()
            }
            if workspace.showCommandPalette {
                CommandPaletteView()
            }
            if workspace.showGlobalSearch {
                GlobalSearchView()
            }
        }
        .background(MonoColor.canvas.ignoresSafeArea())
        .task {
            await modelStore.refresh()
            if workspace.currentProject == nil, let first = ProjectStore.shared.projects.first {
                workspace.openProject(first)
            }
        }
    }
}

/// First-launch onboarding: quick start to create or open a project.
struct OnboardingView: View {
    @State private var showNew = false

    var body: some View {
        VStack(spacing: MonoSpace.xl) {
            VStack(spacing: MonoSpace.sm) {
                Image(systemName: MonoIcon.sparkles)
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(MonoColor.primaryText)
                Text("Adventure Coder")
                    .font(MonoType.largeTitle)
                Text("A minimalist AI coding workspace for iPhone and iPad, powered by 155+ specialized agents.")
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, MonoSpace.xl)
            }
            VStack(spacing: MonoSpace.sm) {
                MonoComponents.PrimaryButton("Create a new project") { showNew = true }
                Text("Or add an OpenRouter / Hugging Face API key in Settings to enable AI features.")
                    .font(MonoType.caption)
                    .foregroundColor(MonoColor.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, MonoSpace.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MonoColor.canvas.ignoresSafeArea())
        .sheet(isPresented: $showNew) {
            NewProjectView()
        }
    }
}

private extension View {
    /// Wires up ⌘K for the command palette and ⌘F for global search.
    func onCommandShortcut() -> some View {
        self
            .keyboardShortcut("k", modifiers: .command)
            .background(
                Button(action: { WorkspaceState.shared.showCommandPalette = true }) {
                    Color.clear
                }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
            )
            .background(
                Button(action: { WorkspaceState.shared.showGlobalSearch = true }) {
                    Color.clear
                }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
            )
    }
}
