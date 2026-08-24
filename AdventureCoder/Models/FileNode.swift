import Foundation

/// A node in the in-app file tree.
public struct FileNode: Identifiable, Hashable, Codable {
    public var id: String { relativePath }
    public var name: String
    public var relativePath: String
    public var absolutePath: String
    public var isDirectory: Bool
    public var children: [FileNode]
    public var size: Int64
    public var modifiedAt: Date

    public init(
        name: String,
        relativePath: String,
        absolutePath: String,
        isDirectory: Bool,
        children: [FileNode] = [],
        size: Int64 = 0,
        modifiedAt: Date = Date()
    ) {
        self.name = name
        self.relativePath = relativePath
        self.absolutePath = absolutePath
        self.isDirectory = isDirectory
        self.children = children
        self.size = size
        self.modifiedAt = modifiedAt
    }

    public var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }

    /// Returns `children` if this is a directory, otherwise `nil`.
    /// Required by SwiftUI's `OutlineGroup` which expects an optional children keypath.
    public var optionalChildren: [FileNode]? {
        isDirectory ? children : nil
    }

    public var language: Language {
        Language.forExtension(fileExtension)
    }

    public var fileIcon: String {
        if isDirectory { return MonoIcon.folder }
        return language.icon
    }

    /// Sorting helper used by the file explorer.
    public static func sorted(_ nodes: [FileNode]) -> [FileNode] {
        nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

public enum Language: String, Codable, CaseIterable {
    case swift, objectiveC
    case typescript, javascript, jsx, tsx
    case html, css, scss
    case json, yaml, toml, plist, xml, markdown
    case python, ruby, php, go, rust, java, kotlin, c, cpp, csharp
    case shell, sql
    case plain

    public var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .objectiveC: return "Objective-C"
        case .typescript: return "TypeScript"
        case .javascript: return "JavaScript"
        case .jsx: return "JSX"
        case .tsx: return "TSX"
        case .html: return "HTML"
        case .css: return "CSS"
        case .scss: return "SCSS"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .toml: return "TOML"
        case .plist: return "Plist"
        case .xml: return "XML"
        case .markdown: return "Markdown"
        case .python: return "Python"
        case .ruby: return "Ruby"
        case .php: return "PHP"
        case .go: return "Go"
        case .rust: return "Rust"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .c: return "C"
        case .cpp: return "C++"
        case .csharp: return "C#"
        case .shell: return "Shell"
        case .sql: return "SQL"
        case .plain: return "Plain Text"
        }
    }

    public var icon: String {
        switch self {
        case .swift: return "swift"
        case .objectiveC: return MonoIcon.docText
        case .typescript, .tsx: return "curlybraces"
        case .javascript, .jsx: return "curlybraces"
        case .html: return MonoIcon.globe
        case .css, .scss: return MonoIcon.palette
        case .json: return "gearshape.2"
        case .yaml, .toml, .plist, .xml: return MonoIcon.docText
        case .markdown: return MonoIcon.docText
        case .python: return "tortoise"
        case .ruby: return "diamond"
        case .php: return "ellipsis.curlybraces"
        case .go: return "circle.hexagongrid"
        case .rust: return "gear"
        case .java, .kotlin: return "cup.and.saucer"
        case .c, .cpp, .csharp: return "curlybraces"
        case .shell: return MonoIcon.terminal
        case .sql: return "cylinder.split.1x2"
        case .plain: return MonoIcon.doc
        }
    }

    public static func forExtension(_ ext: String) -> Language {
        switch ext {
        case "swift": return .swift
        case "m", "mm": return .objectiveC
        case "ts": return .typescript
        case "tsx": return .tsx
        case "js": return .javascript
        case "jsx": return .jsx
        case "html", "htm": return .html
        case "css": return .css
        case "scss": return .scss
        case "json": return .json
        case "yaml", "yml": return .yaml
        case "toml": return .toml
        case "plist": return .plist
        case "xml": return .xml
        case "md", "markdown": return .markdown
        case "py": return .python
        case "rb": return .ruby
        case "php": return .php
        case "go": return .go
        case "rs": return .rust
        case "java": return .java
        case "kt", "kts": return .kotlin
        case "c", "h": return .c
        case "cpp", "cc", "cxx", "hpp": return .cpp
        case "cs": return .csharp
        case "sh", "bash", "zsh": return .shell
        case "sql": return .sql
        default: return .plain
        }
    }
}
