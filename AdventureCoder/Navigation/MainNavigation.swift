import SwiftUI

// MARK: - App Navigation

/// The main navigation enum for all top-level pages.
public enum AppNavPage: String, CaseIterable, Hashable {
    case home, ai, projects, code, preview, files, pcSSH, connections, settings

    public var title: String {
        switch self {
        case .home: return "Home"
        case .ai: return "AI"
        case .projects: return "Projects"
        case .code: return "Code"
        case .preview: return "Preview"
        case .files: return "Files"
        case .pcSSH: return "PC / SSH"
        case .connections: return "Connections"
        case .settings: return "Settings"
        }
    }

    public var icon: String {
        switch self {
        case .home: return "house"
        case .ai: return "sparkles"
        case .projects: return "folder"
        case .code: return "chevron.left.slash.chevron.right"
        case .preview: return "eye"
        case .files: return "doc"
        case .pcSSH: return "pc"
        case .connections: return "network"
        case .settings: return "gearshape"
        }
    }

    /// Whether this page requires an active project to be useful.
    public var requiresProject: Bool {
        switch self {
        case .code, .preview, .files: return true
        default: return false
        }
    }
}

// MARK: - Main Navigation Container

/// The primary navigation container — a clean sidebar with dedicated pages.
/// This replaces the old cramped multi-panel workspace.
public struct MainNavigation: View {
    @Environment(\.horizontalSizeClass) private var hSize
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var auth = AuthManager.shared
    @StateObject private var settings = SettingsStore.shared
    @State private var selectedPage: AppNavPage = .home
    @State private var showCommandPalette = false

    public init() {}

    public var body: some View {
        Group {
            if hSize == .regular {
                ipadLayout
            } else {
                iphoneLayout
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.25), value: selectedPage)
    }

    // MARK: - iPad Layout

    private var ipadLayout: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 0) {
                // App header
                HStack(spacing: 10) {
                    Image(systemName: "chevron.left.slash.chevron.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                    Text("Adventure Coder")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 16)

                // Navigation items
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(visiblePages, id: \.self) { page in
                            NavButton(
                                page: page,
                                isSelected: selectedPage == page,
                                isDisabled: page.requiresProject && workspace.currentProject == nil
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedPage = page
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 16)
                }

                Spacer()

                // Bottom: connection status
                ConnectionStatusFooter()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
            .frame(width: 240)
            .background(Color.black.opacity(0.95))

            Divider()
                .background(Color.white.opacity(0.06))

            // Content area
            VStack(spacing: 0) {
                // Top bar
                TopBar(
                    selectedPage: selectedPage,
                    onCommandPalette: { showCommandPalette = true }
                )

                Divider()
                    .background(Color.white.opacity(0.06))

                // Page content with transition
                pageContent
                    .id(selectedPage)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
            }
            .background(Color.black.opacity(0.85))
        }
        .overlay {
            if showCommandPalette {
                CommandPaletteOverlay(onClose: { showCommandPalette = false })
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCommandPalette)
    }

    // MARK: - iPhone Layout

    private var iphoneLayout: some View {
        VStack(spacing: 0) {
            // Top status bar
            IPhoneTopBar(selectedPage: $selectedPage)

            // Content
            pageContent
                .id(selectedPage)
                .transition(.opacity)

            // Bottom tab bar
            IPhoneTabBar(selectedPage: $selectedPage)
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .home:
            HomePage(onNavigate: { selectedPage = $0 })
        case .ai:
            AIChatPage()
        case .projects:
            ProjectsPage(onNavigate: { selectedPage = $0 })
        case .code:
            CodeWorkspacePage()
        case .preview:
            PreviewWorkspacePage()
        case .files:
            FilesWorkspacePage()
        case .pcSSH:
            PCSSHPage()
        case .connections:
            ConnectionsPage()
        case .settings:
            CompleteSettingsView()
        }
    }

    /// Pages visible in the sidebar — hides project-specific pages when no project is open.
    private var visiblePages: [AppNavPage] {
        AppNavPage.allCases
    }
}

// MARK: - Navigation Button

struct NavButton: View {
    let page: AppNavPage
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: page.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : Color(white: 0.45))
                    .frame(width: 20)
                Text(page.title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .white : (isDisabled ? Color(white: 0.25) : Color(white: 0.6)))
                Spacer()
                if page.requiresProject && isDisabled {
                    Image(systemName: "lock")
                        .font(.system(size: 9))
                        .foregroundColor(Color(white: 0.2))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.white.opacity(0.08) : (isHovered ? Color.white.opacity(0.03) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered && !isDisabled ? 1.0 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
    }
}

// MARK: - Connection Status Footer

struct ConnectionStatusFooter: View {
    @StateObject private var remoteStore = RemotePCStore.shared

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(remoteStore.isConnected ? Color.green : Color(white: 0.2))
                .frame(width: 7, height: 7)
            if let machine = remoteStore.activeMachine {
                Text(machine.name)
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.5))
            } else {
                Text("No PC connected")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.35))
            }
            Spacer()
        }
    }
}

// MARK: - Top Bar

struct TopBar: View {
    let selectedPage: AppNavPage
    let onCommandPalette: () -> Void
    @StateObject private var workspace = WorkspaceState.shared

    var body: some View {
        HStack(spacing: 12) {
            // Breadcrumb
            HStack(spacing: 6) {
                Text(selectedPage.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                if let project = workspace.currentProject {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(Color(white: 0.3))
                    Text(project.name)
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.5))
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 4) {
                TopBarIconButton(icon: "magnifyingglass") { onCommandPalette() }
                TopBarIconButton(icon: "plus") {}
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color.black.opacity(0.9))
    }
}

struct TopBarIconButton: View {
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(isHovered ? .white : Color(white: 0.45))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - iPhone Tab Bar

struct IPhoneTabBar: View {
    @Binding var selectedPage: AppNavPage

    private let tabs: [AppNavPage] = [.home, .ai, .projects, .code, .settings]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedPage = tab
                    }
                }) {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                        Text(tab.title)
                            .font(.system(size: 9))
                    }
                    .foregroundColor(selectedPage == tab ? .white : Color(white: 0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.black.opacity(0.95))
        .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5), alignment: .top)
    }
}

struct IPhoneTopBar: View {
    @Binding var selectedPage: AppNavPage
    @StateObject private var workspace = WorkspaceState.shared

    var body: some View {
        HStack {
            if let project = workspace.currentProject {
                Text(project.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Text("Adventure Coder")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            Spacer()
            Circle()
                .fill(RemotePCStore.shared.isConnected ? Color.green : Color(white: 0.2))
                .frame(width: 7, height: 7)
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(Color.black.opacity(0.95))
    }
}

// MARK: - Page Transition Modifier

struct PageTransition: ViewModifier {
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.98)).animation(.easeOut(duration: 0.25)),
                removal: .opacity.animation(.easeIn(duration: 0.15))
            ))
    }
}

extension View {
    func pageTransition() -> some View {
        modifier(PageTransition())
    }
}
