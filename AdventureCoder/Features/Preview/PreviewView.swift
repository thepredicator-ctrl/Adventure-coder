import SwiftUI
import WebKit

/// Live preview using WKWebView for web projects. For native (SwiftUI/iOS) projects,
/// shows a clear "use GitHub Actions" message.
public struct PreviewView: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var device: PreviewService.Device = .ipadAir
    @State private var reloadToken = UUID()

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: MonoSpace.sm) {
                Picker("", selection: $device) {
                    ForEach(PreviewService.Device.allCases) { d in
                        Text(d.rawValue).tag(d)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Spacer()
                Button(action: { reloadToken = UUID() }) {
                    Image(systemName: MonoIcon.refresh)
                        .foregroundColor(MonoColor.tertiaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, MonoSpace.md)
            .padding(.vertical, MonoSpace.sm)
            .background(MonoColor.panel)
            HairlineDivider()
            if let project = workspace.currentProject {
                if PreviewService.shared.canRenderWebPreview(project: project),
                   let url = PreviewService.shared.indexURL(for: project) {
                    WebPreviewWrapper(url: url, size: device.viewportSize, reloadToken: reloadToken)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyState(
                        title: "Preview not available",
                        message: "For native iOS projects, build and run via GitHub Actions. Web previews are available for HTML/JS/React projects.",
                        systemImage: MonoIcon.eye
                    )
                }
            } else {
                EmptyState(title: "No project selected", message: "Open a project to see its preview.", systemImage: MonoIcon.eye)
            }
        }
        .background(MonoColor.canvas)
    }
}

struct WebPreviewWrapper: UIViewRepresentable {
    let url: URL
    let size: CGSize
    let reloadToken: UUID

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.frame.size = size
        uiView.reload()
    }
}
