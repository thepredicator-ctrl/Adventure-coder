import Foundation

/// A coding project managed by Adventure Coder.
public struct Project: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var rootPath: String            // absolute path inside the app sandbox
    public var template: ProjectTemplate
    public var createdAt: Date
    public var updatedAt: Date
    public var lastOpenedAt: Date?
    public var defaultBranch: String
    public var gitRemoteURL: String?
    public var githubRepo: String?         // "owner/name"
    public var primaryLanguage: String
    public var icon: String                // SF Symbol name
    public var pinned: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        rootPath: String,
        template: ProjectTemplate,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastOpenedAt: Date? = nil,
        defaultBranch: String = "main",
        gitRemoteURL: String? = nil,
        githubRepo: String? = nil,
        primaryLanguage: String = "Swift",
        icon: String = MonoIcon.stack,
        pinned: Bool = false
    ) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.template = template
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
        self.defaultBranch = defaultBranch
        self.gitRemoteURL = gitRemoteURL
        self.githubRepo = githubRepo
        self.primaryLanguage = primaryLanguage
        self.icon = icon
        self.pinned = pinned
    }
}

public enum ProjectTemplate: String, Codable, CaseIterable, Identifiable {
    case empty
    case swiftUI
    case iosApp
    case react
    case web
    case html
    case javascript
    case python
    case rust

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .empty: return "Empty Project"
        case .swiftUI: return "SwiftUI App"
        case .iosApp: return "iOS App"
        case .react: return "React App"
        case .web: return "Web App"
        case .html: return "HTML"
        case .javascript: return "JavaScript"
        case .python: return "Python"
        case .rust: return "Rust"
        }
    }

    public var description: String {
        switch self {
        case .empty: return "A blank workspace. Add files as you go."
        case .swiftUI: return "A SwiftUI app skeleton with App and ContentView."
        case .iosApp: return "A UIKit-based iOS app skeleton."
        case .react: return "A Vite-style React + TypeScript skeleton."
        case .web: return "An HTML/CSS/JS starter with a dev server entry."
        case .html: return "A single index.html page with linked CSS and JS."
        case .javascript: return "A Node.js script with package.json."
        case .python: return "A Python project with main.py and requirements.txt."
        case .rust: return "A Rust project with Cargo.toml and src/main.rs."
        }
    }

    public var icon: String {
        switch self {
        case .empty: return MonoIcon.doc
        case .swiftUI: return "swift"
        case .iosApp: return MonoIcon.phone
        case .react: return "atom"
        case .web: return MonoIcon.globe
        case .html: return MonoIcon.docText
        case .javascript: return "curlybraces"
        case .python: return "tortoise"
        case .rust: return "gear"
        }
    }

    public var primaryLanguage: String {
        switch self {
        case .empty, .swiftUI, .iosApp: return "Swift"
        case .react: return "TypeScript"
        case .web, .html, .javascript: return "JavaScript"
        case .python: return "Python"
        case .rust: return "Rust"
        }
    }

    public var fileExtension: String {
        switch self {
        case .swiftUI, .iosApp: return "swift"
        case .react: return "tsx"
        case .web, .html: return "html"
        case .javascript: return "js"
        case .python: return "py"
        case .rust: return "rs"
        case .empty: return "txt"
        }
    }
}
