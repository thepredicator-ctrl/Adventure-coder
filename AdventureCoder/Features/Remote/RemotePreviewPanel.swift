import SwiftUI
import WebKit

/// Remote preview viewer: loads the live preview URL from the remote PC in a WKWebView.
public struct RemotePreviewPanel: View {
    @StateObject private var previewService = RemotePreviewService.shared
    @StateObject private var store = RemotePCStore.shared
    @State private var device: PreviewDevice = .desktop
    @State private var reloadToken = UUID()
    @State private var showURLInput = false
    @State private var manualURL: String = ""

    public enum PreviewDevice: String, CaseIterable, Hashable {
        case desktop = "Desktop"
        case tablet = "iPad"
        case phone = "iPhone"

        var size: CGSize {
            switch self {
            case .desktop: return CGSize(width: 1280, height: 800)
            case .tablet: return CGSize(width: 820, height: 1180)
            case .phone: return CGSize(width: 393, height: 852)
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: MonoSpace.sm) {
                Picker("", selection: $device) {
                    ForEach(PreviewDevice.allCases, id: \.self) { d in
                        Text(d.rawValue).tag(d)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                if let preview = previewService.activePreview {
                    Text(preview.url)
                        .font(MonoType.caption)
                        .foregroundColor(MonoColor.tertiaryText)
                        .lineLimit(1)
                }

                Button(action: { reloadToken = UUID() }) {
                    Image(systemName: MonoIcon.refresh)
                        .foregroundColor(MonoColor.tertiaryText)
                }
                .buttonStyle(.plain)

                Button(action: { showURLInput = true }) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(MonoColor.tertiaryText)
                }
                .buttonStyle(.plain)

                if previewService.activePreview != nil {
                    Button(action: { Task { await previewService.stopPreview() } }) {
                        Image(systemName: MonoIcon.stop)
                            .foregroundColor(MonoColor.error)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, MonoSpace.md)
            .padding(.vertical, MonoSpace.sm)
            .background(MonoColor.panel)

            if previewService.isStarting {
                HStack {
                    ProgressView()
                    Text("Starting preview server…")
                        .font(MonoType.body)
                        .foregroundColor(MonoColor.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let preview = previewService.activePreview,
                      let url = URL(string: preview.url) {
                WKWebViewWrapper(url: url, size: device.size, reloadToken: reloadToken)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !store.isConnected {
                EmptyState(
                    title: "Not connected",
                    message: "Connect to a remote PC to preview projects.",
                    systemImage: MonoIcon.eye
                )
            } else {
                EmptyState(
                    title: "No preview running",
                    message: "Ask the AI to build a project, or start a preview from the terminal with: npm run dev -- --host 0.0.0.0",
                    systemImage: MonoIcon.eye
                )
            }

            // Server log
            if !previewService.startLog.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(previewService.startLog.joined(separator: ""))
                        .font(MonoType.codeSmall)
                        .foregroundColor(MonoColor.tertiaryText)
                        .padding(.horizontal, MonoSpace.md)
                }
                .frame(height: 28)
                .background(MonoColor.panel)
            }
        }
        .background(MonoColor.canvas)
        .alert("Enter Preview URL", isPresented: $showURLInput) {
            TextField("http://192.168.1.100:5173", text: $manualURL)
            Button("Load") {
                if let url = URL(string: manualURL) {
                    previewService.activePreview = PreviewServer(
                        port: url.port ?? 0,
                        url: manualURL,
                        host: url.host ?? "",
                        projectPath: ""
                    )
                    reloadToken = UUID()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

/// WKWebView wrapper for rendering the remote preview.
struct WKWebViewWrapper: UIViewRepresentable {
    let url: URL
    let size: CGSize
    let reloadToken: UUID

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.frame.size = size
        // Reload when reloadToken changes
        if uiView.url?.absoluteString != url.absoluteString {
            uiView.load(URLRequest(url: url))
        } else {
            uiView.reload()
        }
    }
}
