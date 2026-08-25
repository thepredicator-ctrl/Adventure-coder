import SwiftUI

/// The iPad / Mac-class workspace: sidebar | editor | AI | agents, with a bottom panel.
public struct WorkspaceView: View {
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @StateObject private var modelStore = CachedModelStore.shared

    public init() {}

    public var body: some View {
        ZStack {
            HStack(spacing: 0) {
                if !workspace.sidebarCollapsed {
                    SidebarView()
                        .frame(width: workspace.sidebarWidth)
                    ResizeBar { delta in
                        workspace.sidebarWidth = max(180, min(420, workspace.sidebarWidth + delta))
                    }
                }
                EditorPaneView()
                if !workspace.chatCollapsed {
                    ResizeBar { delta in
                        workspace.chatWidth = max(280, min(560, workspace.chatWidth - delta))
                    }
                    AIChatView()
                        .frame(width: workspace.chatWidth)
                }
            }
            VStack(spacing: 0) {
                Spacer()
                if !workspace.terminalCollapsed {
                    BottomPanelView()
                        .frame(height: workspace.terminalHeight)
                    ResizeBar(vertical: true) { delta in
                        workspace.terminalHeight = max(140, min(560, workspace.terminalHeight - delta))
                    }
                }
            }

            if workspace.showCommandPalette {
                CommandPaletteView()
            }
            if workspace.showGlobalSearch {
                GlobalSearchView()
            }
        }
        .background(MonoColor.canvas)
        .preferredColorScheme(settings.colorScheme)
        .task {
            await modelStore.refresh()
            if workspace.currentProject == nil, let first = ProjectStore.shared.projects.first {
                workspace.openProject(first)
            }
        }
    }
}

/// A draggable resize bar between panels.
public struct ResizeBar: View {
    let vertical: Bool
    let onChange: (CGFloat) -> Void

    public init(vertical: Bool = false, onChange: @escaping (CGFloat) -> Void) {
        self.vertical = vertical
        self.onChange = onChange
    }

    @State private var dragging: CGFloat = 0

    public var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: vertical ? nil : 4, height: vertical ? 4 : nil)
            .background(MonoColor.hairline)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let delta = vertical ? value.translation.height : value.translation.width
                        if abs(delta - dragging) > 0 {
                            onChange(delta - dragging)
                            dragging = delta
                        }
                    }
                    .onEnded { _ in dragging = 0 }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.current = vertical ? .resizeUpDown : .resizeLeftRight
                } else {
                    NSCursor.current = .arrow
                }
            }
    }
}

/// Fallback to NSCursor on iOS (no-op) to keep the code portable.
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#else
class NSCursor {
    static var current: NSCursor = NSCursor()
    static var arrow: NSCursor = NSCursor()
    static var resizeLeftRight: NSCursor = NSCursor()
    static var resizeUpDown: NSCursor = NSCursor()
}
#endif
