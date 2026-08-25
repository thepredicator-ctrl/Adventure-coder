import Foundation
import Combine

/// Manages code snippets that can be inserted into the editor.
public final class SnippetManager: ObservableObject {
    public static let shared = SnippetManager()

    @Published public var snippets: [Snippet] = []

    private let defaults = UserDefaults.standard
    private let storageKey = "code_snippets"

    public struct Snippet: Identifiable, Codable, Hashable {
        public var id: UUID
        public var title: String
        public var language: String
        public var content: String
        public var shortcut: String?
        public var category: String
        public var createdAt: Date

        public init(id: UUID = UUID(), title: String, language: String, content: String, shortcut: String? = nil, category: String = "Custom", createdAt: Date = Date()) {
            self.id = id
            self.title = title
            self.language = language
            self.content = content
            self.shortcut = shortcut
            self.category = category
            self.createdAt = createdAt
        }
    }

    private init() {
        load()
        if snippets.isEmpty {
            installDefaultSnippets()
        }
    }

    // MARK: - CRUD

    public func add(_ snippet: Snippet) {
        snippets.append(snippet)
        save()
    }

    public func remove(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        save()
    }

    public func update(_ snippet: Snippet) {
        if let idx = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[idx] = snippet
            save()
        }
    }

    public func search(_ query: String) -> [Snippet] {
        if query.isEmpty { return snippets }
        return snippets.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.content.localizedCaseInsensitiveContains(query) ||
            $0.language.localizedCaseInsensitiveContains(query)
        }
    }

    public func snippets(forLanguage language: String) -> [Snippet] {
        snippets.filter { $0.language.lowercased() == language.lowercased() }
    }

    public func snippets(inCategory category: String) -> [Snippet] {
        snippets.filter { $0.category == category }
    }

    public var categories: [String] {
        Array(Set(snippets.map { $0.category })).sorted()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(snippets) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = decoded
        }
    }

    // MARK: - Default snippets

    private func installDefaultSnippets() {
        let defaults: [Snippet] = [
            // Swift
            Snippet(title: "SwiftUI View", language: "swift", content: """
            struct ViewName: View {
                var body: some View {
                    VStack {
                        Text("Hello")
                    }
                }
            }
            """, category: "SwiftUI"),
            Snippet(title: "Swift State", language: "swift", content: """
            @State private var value: String = ""
            """, category: "SwiftUI"),
            Snippet(title: "Swift Binding", language: "swift", content: """
            @Binding var value: String
            """, category: "SwiftUI"),
            Snippet(title: "Swift Observable", language: "swift", content: """
            @Observable
            final class ViewModel {
                var data: [String] = []
            }
            """, category: "SwiftUI"),
            Snippet(title: "Swift ForEach", language: "swift", content: """
            ForEach(items, id: \\.self) { item in
                Text(item)
            }
            """, category: "SwiftUI"),
            Snippet(title: "Swift List", language: "swift", content: """
            List(items) { item in
                Text(item.name)
            }
            """, category: "SwiftUI"),
            Snippet(title: "Swift NavigationStack", language: "swift", content: """
            NavigationStack {
                ContentView()
                    .navigationTitle("Title")
            }
            """, category: "SwiftUI"),
            Snippet(title: "Swift Async Function", language: "swift", content: """
            func fetchData() async throws -> Data {
                // Implementation
            }
            """, category: "Swift"),
            Snippet(title: "Swift Result Type", language: "swift", content: """
            func process() -> Result<String, Error> {
                .success("result")
            }
            """, category: "Swift"),
            Snippet(title: "Swift Guard Let", language: "swift", content: """
            guard let value = optionalValue else { return }
            """, category: "Swift"),
            Snippet(title: "Swift Enum with Associated Values", language: "swift", content: """
            enum Result<T> {
                case success(T)
                case failure(Error)
            }
            """, category: "Swift"),
            Snippet(title: "Swift Protocol", language: "swift", content: """
            protocol MyProtocol {
                func requiredMethod()
                var requiredProperty: String { get }
            }
            """, category: "Swift"),
            Snippet(title: "Swift Extension", language: "swift", content: """
            extension String {
                var trimmed: String {
                    trimmingCharacters(in: .whitespaces)
                }
            }
            """, category: "Swift"),
            // TypeScript
            Snippet(title: "React Component", language: "typescript", content: """
            interface Props {
              title: string
            }

            export function Component({ title }: Props) {
              return <div>{title}</div>
            }
            """, category: "React"),
            Snippet(title: "React Hook useState", language: "typescript", content: """
            const [state, setState] = useState<T>(initialValue)
            """, category: "React"),
            Snippet(title: "React Hook useEffect", language: "typescript", content: """
            useEffect(() => {
              // effect
              return () => {
                // cleanup
              }
            }, [dependencies])
            """, category: "React"),
            Snippet(title: "TypeScript Interface", language: "typescript", content: """
            interface User {
              id: string
              name: string
              email: string
            }
            """, category: "TypeScript"),
            Snippet(title: "TypeScript Type", language: "typescript", content: """
            type Status = 'idle' | 'loading' | 'success' | 'error'
            """, category: "TypeScript"),
            Snippet(title: "TypeScript Generic Function", language: "typescript", content: """
            function identity<T>(arg: T): T {
              return arg
            }
            """, category: "TypeScript"),
            // Python
            Snippet(title: "Python Function", language: "python", content: """
            def function_name(param: str) -> str:
                \"\"\"Docstring.\"\"\"
                return param
            """, category: "Python"),
            Snippet(title: "Python Class", language: "python", content: """
            class ClassName:
                def __init__(self, param: str):
                    self.param = param

                def method(self) -> str:
                    return self.param
            """, category: "Python"),
            Snippet(title: "Python Dataclass", language: "python", content: """
            from dataclasses import dataclass

            @dataclass
            class User:
                name: str
                email: str
            """, category: "Python"),
            Snippet(title: "Python Async", language: "python", content: """
            async def fetch_data() -> dict:
                async with session.get(url) as response:
                    return await response.json()
            """, category: "Python"),
            // Rust
            Snippet(title: "Rust Struct", language: "rust", content: """
            struct StructName {
                field: String,
            }

            impl StructName {
                fn new(field: String) -> Self {
                    Self { field }
                }
            }
            """, category: "Rust"),
            Snippet(title: "Rust Enum", language: "rust", content: """
            enum Result<T, E> {
                Ok(T),
                Err(E),
            }
            """, category: "Rust"),
            Snippet(title: "Rust Match", language: "rust", content: """
            match value {
                Some(x) => println!("{}", x),
                None => println!("none"),
            }
            """, category: "Rust"),
            // Go
            Snippet(title: "Go Function", language: "go", content: """
            func functionName(param string) (string, error) {
                return param, nil
            }
            """, category: "Go"),
            Snippet(title: "Go Struct", language: "go", content: """
            type StructName struct {
                Field string
            }
            """, category: "Go"),
            Snippet(title: "Go Interface", language: "go", content: """
            type InterfaceName interface {
                Method() error
            }
            """, category: "Go"),
            // HTML/CSS
            Snippet(title: "HTML5 Template", language: "html", content: """
            <!doctype html>
            <html lang="en">
              <head>
                <meta charset="UTF-8" />
                <meta name="viewport" content="width=device-width, initial-scale=1.0" />
                <title>Page Title</title>
              </head>
              <body>
                <main>
                </main>
              </body>
            </html>
            """, category: "HTML"),
            Snippet(title: "CSS Flexbox", language: "css", content: """
            .container {
              display: flex;
              justify-content: center;
              align-items: center;
              gap: 1rem;
            }
            """, category: "CSS"),
            Snippet(title: "CSS Grid", language: "css", content: """
            .grid {
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
              gap: 1rem;
            }
            """, category: "CSS"),
            Snippet(title: "CSS Custom Properties", language: "css", content: """
            :root {
              --primary: #007aff;
              --secondary: #5856d6;
              --success: #34c759;
              --error: #ff3b30;
            }
            """, category: "CSS"),
            // SQL
            Snippet(title: "SQL SELECT", language: "sql", content: """
            SELECT column1, column2
            FROM table_name
            WHERE condition
            ORDER BY column1 DESC;
            """, category: "SQL"),
            Snippet(title: "SQL INSERT", language: "sql", content: """
            INSERT INTO table_name (column1, column2)
            VALUES (value1, value2);
            """, category: "SQL"),
            Snippet(title: "SQL JOIN", language: "sql", content: """
            SELECT a.column, b.column
            FROM table_a a
            INNER JOIN table_b b ON a.id = b.a_id;
            """, category: "SQL"),
            // Shell
            Snippet(title: "Shell Script Header", language: "shell", content: """
            #!/bin/bash
            set -euo pipefail
            """, category: "Shell"),
            Snippet(title: "Shell If Statement", language: "shell", content: """
            if [ "$var" = "value" ]; then
                echo "match"
            fi
            """, category: "Shell"),
        ]
        snippets = defaults
        save()
    }
}

// MARK: - Search Indexer

/// Indexes project files for fast symbol and content search.
public final class SearchIndexer {
    public static let shared = SearchIndexer()
    private init() {}

    public struct IndexedSymbol: Hashable {
        public let name: String
        public let kind: String
        public let file: String
        public let line: Int
        public let language: String
    }

    public struct IndexedFile: Hashable {
        public let path: String
        public let name: String
        public let language: String
        public let size: Int
        public let modifiedAt: Date
    }

    private var symbolIndex: [IndexedSymbol] = []
    private var fileIndex: [IndexedFile] = []
    private var contentIndex: [String: String] = [:]  // path -> content (for small files)

    /// Index a project directory.
    public func indexProject(at path: String) {
        symbolIndex.removeAll()
        fileIndex.removeAll()
        contentIndex.removeAll()

        let walker = IndexWalker()
        walker.walk(path) { filePath, content in
            let name = (filePath as NSString).lastPathComponent
            let ext = (name as NSString).pathExtension.lowercased()
            let language = Language.forExtension(ext)
            let size = content.count

            fileIndex.append(IndexedFile(
                path: filePath,
                name: name,
                language: language.displayName,
                size: size,
                modifiedAt: Date()
            ))

            // Index symbols for Swift files
            if language == .swift {
                let symbols = SymbolParser.parse(content: content, fileName: name)
                for sym in symbols {
                    symbolIndex.append(IndexedSymbol(
                        name: sym.name,
                        kind: sym.kind.rawValue,
                        file: filePath,
                        line: sym.line,
                        language: "Swift"
                    ))
                }
            }

            // Cache content for files under 50KB
            if size < 50_000 {
                contentIndex[filePath] = content
            }
        }
    }

    /// Search for symbols by name.
    public func searchSymbols(_ query: String) -> [IndexedSymbol] {
        if query.isEmpty { return [] }
        return symbolIndex.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// Search for files by name.
    public func searchFiles(_ query: String) -> [IndexedFile] {
        if query.isEmpty { return [] }
        return fileIndex.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// Search file contents.
    public func searchContent(_ query: String) -> [(file: String, line: Int, snippet: String)] {
        if query.isEmpty { return [] }
        var results: [(String, Int, String)] = []
        for (path, content) in contentIndex {
            let lines = content.components(separatedBy: "\n")
            for (idx, line) in lines.enumerated() {
                if line.localizedCaseInsensitiveContains(query) {
                    results.append((path, idx + 1, line.trimmingCharacters(in: .whitespaces)))
                    if results.count >= 100 { return results }
                }
            }
        }
        return results
    }

    /// Get index statistics.
    public var stats: (files: Int, symbols: Int, indexedContentMB: Double) {
        let totalSize = contentIndex.values.reduce(0) { $0 + $1.count }
        return (fileIndex.count, symbolIndex.count, Double(totalSize) / 1_048_576)
    }
}

private final class IndexWalker {
    private let fm = FileManager.default

    func walk(_ dir: String, callback: (String, String) -> Void) {
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return }
        for entry in entries {
            if entry.hasPrefix(".") || entry == "node_modules" || entry == "DerivedData" || entry == "build" || entry == ".build" { continue }
            let full = (dir as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            if isDir.boolValue {
                walk(full, callback: callback)
            } else {
                if let content = try? String(contentsOfFile: full, encoding: .utf8) {
                    callback(full, content)
                }
            }
        }
    }
}

// MARK: - Bookmark Manager

/// Manages bookmarks to lines in files.
public final class BookmarkManager: ObservableObject {
    public static let shared = BookmarkManager()

    @Published public var bookmarks: [Bookmark] = []

    private let defaults = UserDefaults.standard
    private let storageKey = "bookmarks"

    public struct Bookmark: Identifiable, Codable, Hashable {
        public var id: UUID
        public var filePath: String
        public var line: Int
        public var label: String
        public var createdAt: Date

        public init(id: UUID = UUID(), filePath: String, line: Int, label: String = "", createdAt: Date = Date()) {
            self.id = id
            self.filePath = filePath
            self.line = line
            self.label = label
            self.createdAt = createdAt
        }
    }

    private init() {
        load()
    }

    public func toggle(filePath: String, line: Int) {
        if let idx = bookmarks.firstIndex(where: { $0.filePath == filePath && $0.line == line }) {
            bookmarks.remove(at: idx)
        } else {
            bookmarks.append(Bookmark(filePath: filePath, line: line))
        }
        save()
    }

    public func isBookmarked(filePath: String, line: Int) -> Bool {
        bookmarks.contains { $0.filePath == filePath && $0.line == line }
    }

    public func bookmarks(forFile filePath: String) -> [Bookmark] {
        bookmarks.filter { $0.filePath == filePath }.sorted { $0.line < $1.line }
    }

    public func remove(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
    }

    public func clearAll() {
        bookmarks.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) {
            bookmarks = decoded
        }
    }
}

// MARK: - Recent Files Manager

/// Tracks recently opened files.
public final class RecentFilesManager: ObservableObject {
    public static let shared = RecentFilesManager()

    @Published public var recentFiles: [RecentFile] = []

    private let defaults = UserDefaults.standard
    private let storageKey = "recent_files"
    private let maxFiles = 20

    public struct RecentFile: Identifiable, Codable, Hashable {
        public var id: String { path }
        public var path: String
        public var name: String
        public var project: String
        public var openedAt: Date

        public init(path: String, name: String, project: String, openedAt: Date = Date()) {
            self.path = path
            self.name = name
            self.project = project
            self.openedAt = openedAt
        }
    }

    private init() {
        load()
    }

    public func recordOpen(path: String, name: String, project: String) {
        // Remove if already exists
        recentFiles.removeAll { $0.path == path }
        // Add to front
        recentFiles.insert(RecentFile(path: path, name: name, project: project), at: 0)
        // Trim
        if recentFiles.count > maxFiles {
            recentFiles = Array(recentFiles.prefix(maxFiles))
        }
        save()
    }

    public func clear() {
        recentFiles.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(recentFiles) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([RecentFile].self, from: data) {
            recentFiles = decoded
        }
    }
}

// MARK: - Code Completion Engine

/// Provides code completion suggestions based on simple heuristics.
public final class CodeCompletionEngine {
    public static let shared = CodeCompletionEngine()
    private init() {}

    public struct Completion: Identifiable, Hashable {
        public let id = UUID()
        public let text: String
        public let kind: CompletionKind
        public let detail: String?
    }

    public enum CompletionKind: String {
        case keyword, function, type, variable, snippet, property

        public var icon: String {
            switch self {
            case .keyword: return "k.square"
            case .function: return "f.square"
            case .type: return "t.square"
            case .variable: return "v.square"
            case .snippet: return "s.square"
            case .property: return "p.square"
            }
        }
    }

    /// Get completions for a partial word.
    public func completions(for partial: String, language: Language, fileContent: String? = nil) -> [Completion] {
        if partial.isEmpty { return [] }
        var results: [Completion] = []

        // Language keywords
        let keywords = keywordsFor(language: language)
        for keyword in keywords where keyword.hasPrefix(partial) {
            results.append(Completion(text: keyword, kind: .keyword, detail: nil))
        }

        // Snippets
        let snippets = SnippetManager.shared.snippets(forLanguage: language.rawValue)
        for snippet in snippets where snippet.title.lowercased().contains(partial.lowercased()) {
            results.append(Completion(text: snippet.title, kind: .snippet, detail: snippet.content))
        }

        // Symbols from file content
        if let content = fileContent {
            let symbols = SymbolParser.parse(content: content, fileName: "")
            for symbol in symbols where symbol.name.hasPrefix(partial) {
                let kind: CompletionKind = symbol.kind == .func ? .function : (symbol.kind == .var_ ? .variable : .type)
                results.append(Completion(text: symbol.name, kind: kind, detail: "Line \(symbol.line)"))
            }
        }

        return Array(results.prefix(20))
    }

    private func keywordsFor(language: Language) -> [String] {
        switch language {
        case .swift:
            return ["func", "let", "var", "if", "else", "guard", "for", "while", "switch", "case", "return", "struct", "class", "enum", "protocol", "extension", "import", "init", "deinit", "self", "super", "nil", "true", "false", "async", "await", "throws", "throw", "try", "catch", "do", "defer", "where", "in", "as", "is", "public", "private", "internal", "fileprivate", "static", "final", "lazy", "weak", "unowned", "override", "mutating", "nonmutating", "inout", "subscript", "typealias", "associatedtype", "some", "any", "actor", "distributed"]
        case .javascript, .typescript, .jsx, .tsx:
            return ["const", "let", "var", "function", "return", "if", "else", "for", "while", "do", "switch", "case", "break", "continue", "class", "extends", "implements", "interface", "type", "enum", "namespace", "import", "export", "from", "default", "async", "await", "new", "delete", "typeof", "instanceof", "in", "of", "this", "super", "null", "undefined", "true", "false", "void", "throw", "try", "catch", "finally", "yield", "static", "public", "private", "protected", "readonly", "abstract", "get", "set", "as", "satisfies"]
        case .python:
            return ["def", "class", "import", "from", "as", "return", "if", "elif", "else", "for", "while", "in", "is", "not", "and", "or", "with", "try", "except", "finally", "raise", "yield", "lambda", "pass", "break", "continue", "global", "nonlocal", "assert", "del", "async", "await", "True", "False", "None", "self"]
        case .rust:
            return ["fn", "let", "mut", "const", "static", "if", "else", "match", "for", "while", "loop", "return", "break", "continue", "struct", "enum", "trait", "impl", "pub", "use", "mod", "self", "Self", "super", "crate", "as", "in", "where", "async", "await", "move", "ref", "dyn", "unsafe", "extern", "Some", "None", "Ok", "Err", "Result", "Option"]
        case .go:
            return ["package", "import", "func", "var", "const", "type", "struct", "interface", "if", "else", "for", "range", "switch", "case", "default", "return", "go", "defer", "select", "chan", "map", "make", "new", "nil", "true", "false", "break", "continue"]
        case .java, .kotlin:
            return ["public", "private", "protected", "class", "interface", "enum", "extends", "implements", "package", "import", "static", "final", "void", "int", "long", "short", "float", "double", "boolean", "char", "if", "else", "for", "while", "switch", "case", "break", "continue", "return", "new", "try", "catch", "finally", "throw", "throws", "this", "super", "fun", "val", "var", "when", "object", "companion", "data", "sealed", "suspend", "override"]
        case .c, .cpp, .csharp:
            return ["int", "long", "short", "float", "double", "char", "void", "if", "else", "for", "while", "switch", "case", "break", "continue", "return", "struct", "class", "public", "private", "protected", "static", "const", "void", "new", "delete", "this", "namespace", "using", "template", "typename", "auto", "constexpr", "nullptr"]
        case .sql:
            return ["SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "TABLE", "DROP", "ALTER", "ADD", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "NOT", "NULL", "DEFAULT", "UNIQUE", "INDEX", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "GROUP", "BY", "ORDER", "HAVING", "LIMIT", "OFFSET", "AS", "AND", "OR", "IN", "LIKE", "BETWEEN"]
        case .shell:
            return ["if", "then", "fi", "for", "in", "do", "done", "while", "case", "esac", "function", "return", "exit", "echo", "export", "local", "readonly", "set", "unset", "source", "alias"]
        case .ruby, .php:
            return ["def", "end", "if", "elsif", "else", "unless", "while", "until", "for", "do", "break", "next", "redo", "retry", "return", "yield", "class", "module", "require", "require_relative", "include", "extend", "attr_accessor", "attr_reader", "attr_writer", "public", "private", "protected"]
        default:
            return []
        }
    }
}
