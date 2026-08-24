import Foundation

/// Live preview service. Renders HTML/CSS/JS projects in a WKWebView by serving
/// the project's index.html with relative resources resolved.
public final class PreviewService {
    public static let shared = PreviewService()
    private init() {}

    public func summary(project: Project, device: String) -> String {
        switch project.template {
        case .swiftUI, .iosApp:
            return "SwiftUI preview: not yet supported on-device for sandboxed apps. Trigger a GitHub Actions build to render screenshots."
        case .react, .web, .html, .javascript:
            return "Web preview ready on device \(device). Load it in the Preview pane."
        case .python, .rust, .empty:
            return "No preview available for this template."
        }
    }

    public func canRenderWebPreview(project: Project) -> Bool {
        switch project.template {
        case .react, .web, .html, .javascript: return true
        default: return false
        }
    }

    /// Returns the URL of the index.html to load, or nil if no preview is available.
    public func indexURL(for project: Project) -> URL? {
        let candidates = ["index.html", "public/index.html", "dist/index.html"]
        for candidate in candidates {
            let path = (project.rootPath as NSString).appendingPathComponent(candidate)
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    public enum Device: String, CaseIterable, Identifiable {
        case iphone15 = "iPhone 15"
        case iphone15Pro = "iPhone 15 Pro"
        case iphoneSE = "iPhone SE"
        case ipadMini = "iPad mini"
        case ipadAir = "iPad Air 11\""
        case ipadPro11 = "iPad Pro 11\""
        case ipadPro13 = "iPad Pro 13\""
        case desktop = "Desktop"

        public var id: String { rawValue }

        public var viewportSize: CGSize {
            switch self {
            case .iphone15, .iphone15Pro: return CGSize(width: 393, height: 852)
            case .iphoneSE: return CGSize(width: 375, height: 667)
            case .ipadMini: return CGSize(width: 744, height: 1133)
            case .ipadAir, .ipadPro11: return CGSize(width: 820, height: 1180)
            case .ipadPro13: return CGSize(width: 1024, height: 1366)
            case .desktop: return CGSize(width: 1280, height: 800)
            }
        }
    }
}
