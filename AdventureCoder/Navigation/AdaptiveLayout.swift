import SwiftUI

/// Root view that adapts between iPad and iPhone layouts.
/// Uses the redesigned clean multi-panel workspace.
public struct AdaptiveLayout: View {
    @Environment(\.horizontalSizeClass) private var hSize
    @StateObject private var remoteStore = RemotePCStore.shared

    public init() {}

    public var body: some View {
        Group {
            if hSize == .regular {
                // iPad — full multi-panel workspace
                RedesignedWorkspace()
            } else {
                // iPhone — simplified tab layout
                RedesignediPhoneLayout()
            }
        }
    }
}

// MARK: - Redesigned iPhone Layout

/// Clean iPhone layout with bottom tab navigation.
public struct RedesignediPhoneLayout: View {
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var remoteStore = RemotePCStore.shared
    @State private var selectedTab: IPhoneTab = .projects

    public enum IPhoneTab: String, CaseIterable, Hashable {
        case projects, ai, code, preview, settings

        var title: String {
            switch self {
            case .projects: return "Projects"
            case .ai: return "AI"
            case .code: return "Code"
            case .preview: return "Preview"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .projects: return "folder"
            case .ai: return "sparkles"
            case .code: return "doc.text"
            case .preview: return "eye"
            case .settings: return "gearshape"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top status bar
            HStack(spacing: 8) {
                if let project = workspace.currentProject {
                    Text(project.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text(project.defaultBranch)
                        .font(.system(size: 11))
                        .foregroundColor(MonoColor.steel)
                }
                Spacer()
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(remoteStore.isConnected ? Color.green : MonoColor.steel)
                            .frame(width: 6, height: 6)
                        if let machine = remoteStore.activeMachine {
                            Text(machine.name)
                                .font(.system(size: 11))
                                .foregroundColor(MonoColor.steel)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(Color.black.opacity(0.9))

            // Tab content
            TabView(selection: $selectedTab) {
                ForEach(IPhoneTab.allCases, id: \.self) { tab in
                    NavigationStack {
                        iphoneTabContent(tab)
                    }
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
                }
            }
            .colorScheme(.dark)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func iphoneTabContent(_ tab: IPhoneTab) -> some View {
        switch tab {
        case .projects:
            ProjectsListView()
        case .ai:
            AIChatView()
        case .code:
            EditorPaneView()
        case .preview:
            PreviewView()
        case .settings:
            CompleteSettingsView()
        }
    }
}
