import SwiftUI

/// Right-side inspector panel showing contextual information about the current file,
/// selection, symbol, or project.
public struct InspectorPanel: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var selectedTab: InspectorTab = .outline

    enum InspectorTab: String, CaseIterable, Hashable {
        case outline, symbols, problems, git, dependencies, metrics

        var title: String {
            switch self {
            case .outline: return "Outline"
            case .symbols: return "Symbols"
            case .problems: return "Problems"
            case .git: return "Git"
            case .dependencies: return "Dependencies"
            case .metrics: return "Metrics"
            }
        }

        var icon: String {
            switch self {
            case .outline: return "list.bullet.indent"
            case .symbols: return "square.grid.2x2"
            case .problems: return "exclamationmark.triangle"
            case .git: return "arrow.triangle.branch"
            case .dependencies: return "shippingbox"
            case .metrics: return "chart.bar"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11))
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .foregroundColor(selectedTab == tab ? MonoColor.primaryText : MonoColor.tertiaryText)
                            .background(selectedTab == tab ? MonoColor.cloud : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(MonoColor.panel)
            HairlineDivider()

            // Content
            ScrollView {
                switch selectedTab {
                case .outline: OutlineInspector()
                case .symbols: SymbolsInspector()
                case .problems: ProblemsInspector()
                case .git: GitInspector()
                case .dependencies: DependenciesInspector()
                case .metrics: MetricsInspector()
                }
            }
        }
        .background(MonoColor.canvas)
    }
}

struct OutlineInspector: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var symbols: [SymbolInfo] = []

    var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.xxs) {
            if let file = workspace.activeFile {
                SectionHeader("Outline — \(file.name)")
                ForEach(symbols) { symbol in
                    HStack(spacing: MonoSpace.xs) {
                        Image(systemName: symbol.kind.icon)
                            .font(.system(size: 10))
                            .foregroundColor(symbolColor(symbol.kind))
                        Text(symbol.name)
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.primaryText)
                        Spacer()
                        Text("\(symbol.line)")
                            .font(MonoType.caption2)
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                    .padding(.horizontal, MonoSpace.md)
                    .padding(.vertical, MonoSpace.xxs)
                    .contentShape(Rectangle())
                }
            } else {
                Text("No file open")
                    .font(MonoType.footnote)
                    .foregroundColor(MonoColor.tertiaryText)
                    .padding()
            }
        }
        .padding(.vertical, MonoSpace.sm)
        .onAppear(perform: parseSymbols)
        .onChange(of: workspace.activeFile?.relativePath) { _ in parseSymbols() }
    }

    private func parseSymbols() {
        guard let file = workspace.activeFile,
              let content = try? FileSystem.shared.read(file.absolutePath) else {
            symbols = []
            return
        }
        symbols = SymbolParser.parse(content: content, fileName: file.name)
    }

    private func symbolColor(_ kind: SymbolKind) -> Color {
        switch kind {
        case .klass: return .purple
        case .struct_: return .blue
        case .enum_: return .orange
        case .protocol_: return .green
        case .function: return .red
        case .variable: return .gray
        case .extension_: return .teal
        }
    }
}

struct SymbolsInspector: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.sm) {
            SectionHeader("Symbols")
            HStack {
                Image(systemName: MonoIcon.search)
                    .foregroundColor(MonoColor.tertiaryText)
                TextField("Search symbols…", text: $query)
                    .font(MonoType.body)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, MonoSpace.md)
            .padding(.vertical, MonoSpace.xs)
            .background(MonoColor.inset)
            .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))

            // Symbol list would go here
            Text("Symbol search results")
                .font(MonoType.footnote)
                .foregroundColor(MonoColor.tertiaryText)
                .padding(.horizontal, MonoSpace.md)
        }
        .padding(.vertical, MonoSpace.sm)
    }
}

struct ProblemsInspector: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.sm) {
            SectionHeader("Problems")
            Text("No problems detected")
                .font(MonoType.footnote)
                .foregroundColor(MonoColor.tertiaryText)
                .padding(.horizontal, MonoSpace.md)
        }
        .padding(.vertical, MonoSpace.sm)
    }
}

struct GitInspector: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var status = ""

    var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.sm) {
            SectionHeader("Git Status")
            if let project = workspace.currentProject {
                if GitService.shared.isRepo(project) {
                    if case .success(let s) = GitService.shared.status(project: project) {
                        Text(s)
                            .font(MonoType.codeSmall)
                            .foregroundColor(MonoColor.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(MonoSpace.sm)
                            .background(MonoColor.inset)
                            .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))
                            .padding(.horizontal, MonoSpace.md)
                    }
                } else {
                    Text("Not a git repository")
                        .font(MonoType.footnote)
                        .foregroundColor(MonoColor.tertiaryText)
                        .padding(.horizontal, MonoSpace.md)
                }
            }
        }
        .padding(.vertical, MonoSpace.sm)
    }
}

struct DependenciesInspector: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.sm) {
            SectionHeader("Dependencies")
            Text("No dependencies found")
                .font(MonoType.footnote)
                .foregroundColor(MonoColor.tertiaryText)
                .padding(.horizontal, MonoSpace.md)
        }
        .padding(.vertical, MonoSpace.sm)
    }
}

struct MetricsInspector: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var metrics: CodeComplexityAnalyzer.FileMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.sm) {
            SectionHeader("File Metrics")
            if let file = workspace.activeFile,
               let content = try? FileSystem.shared.read(file.absolutePath) {
                let m = CodeComplexityAnalyzer.shared.analyzeSwift(content: content, fileName: file.name)
                VStack(alignment: .leading, spacing: MonoSpace.xs) {
                    metricRow("Lines", "\(m.totalLines)")
                    metricRow("Code Lines", "\(m.codeLines)")
                    metricRow("Comment Lines", "\(m.commentLines)")
                    metricRow("Functions", "\(m.functions.count)")
                    metricRow("MI", String(format: "%.1f", m.maintainabilityIndex))
                    metricRow("Grade", m.grade.rawValue.uppercased())
                }
                .padding(.horizontal, MonoSpace.md)
            } else {
                Text("No file open")
                    .font(MonoType.footnote)
                    .foregroundColor(MonoColor.tertiaryText)
                    .padding(.horizontal, MonoSpace.md)
            }
        }
        .padding(.vertical, MonoSpace.sm)
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(MonoType.caption)
                .foregroundColor(MonoColor.tertiaryText)
            Spacer()
            Text(value)
                .font(MonoType.caption.weight(.medium))
                .foregroundColor(MonoColor.primaryText)
        }
    }
}

// MARK: - Symbol parsing

public enum SymbolKind: String {
    case klass = "class"
    case struct_ = "struct"
    case enum_ = "enum"
    case protocol_ = "protocol"
    case function = "func"
    case variable = "var"
    case extension_ = "extension"

    public var icon: String {
        switch self {
        case .klass: return "c.square"
        case .struct_: return "s.square"
        case .enum_: return "e.square"
        case .protocol_: return "p.square"
        case .function: return "f.square"
        case .variable: return "v.square"
        case .extension_: return "plus.square"
        }
    }
}

public struct SymbolInfo: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let kind: SymbolKind
    public let line: Int
}

public enum SymbolParser {
    public static func parse(content: String, fileName: String) -> [SymbolInfo] {
        var symbols: [SymbolInfo] = []
        let lines = content.components(separatedBy: .newlines)

        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") { continue }

            // Detect class
            if let name = extractName(after: "class ", in: trimmed) {
                symbols.append(SymbolInfo(name: name, kind: .klass, line: idx + 1))
            }
            // Detect struct
            else if let name = extractName(after: "struct ", in: trimmed) {
                symbols.append(SymbolInfo(name: name, kind: .struct_, line: idx + 1))
            }
            // Detect enum
            else if let name = extractName(after: "enum ", in: trimmed) {
                symbols.append(SymbolInfo(name: name, kind: .enum_, line: idx + 1))
            }
            // Detect protocol
            else if let name = extractName(after: "protocol ", in: trimmed) {
                symbols.append(SymbolInfo(name: name, kind: .protocol_, line: idx + 1))
            }
            // Detect func
            else if let name = extractName(after: "func ", in: trimmed) {
                symbols.append(SymbolInfo(name: name, kind: .function, line: idx + 1))
            }
            // Detect extension
            else if let name = extractName(after: "extension ", in: trimmed) {
                symbols.append(SymbolInfo(name: name, kind: .extension_, line: idx + 1))
            }
            // Detect var/let
            else if let name = extractVarName(in: trimmed) {
                symbols.append(SymbolInfo(name: name, kind: .variable, line: idx + 1))
            }
        }
        return symbols
    }

    private static func extractName(after prefix: String, in line: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        let rest = String(line.dropFirst(prefix.count))
        let name = rest.split { $0.isWhitespace || $0 == "(" || $0 == ":" || $0 == "{" || $0 == "<" }.first.map { String($0) }
        return name
    }

    private static func extractVarName(in line: String) -> String? {
        let patterns = ["let ", "var "]
        for pattern in patterns {
            if line.hasPrefix(pattern) {
                let rest = String(line.dropFirst(pattern.count))
                let name = rest.split { $0.isWhitespace || $0 == ":" || $0 == "=" }.first.map { String($0) }
                return name
            }
        }
        return nil
    }
}
