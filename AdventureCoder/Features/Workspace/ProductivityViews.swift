import SwiftUI

/// Snippet library view for browsing and inserting code snippets.
public struct SnippetLibraryView: View {
    @StateObject private var snippetManager = SnippetManager.shared
    @State private var query: String = ""
    @State private var selectedCategory: String?
    @State private var selectedLanguage: String?
    @State private var showingAddSheet = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: MonoIcon.search)
                        .foregroundColor(MonoColor.tertiaryText)
                    TextField("Search snippets…", text: $query)
                        .font(MonoType.body)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, MonoSpace.md)
                .padding(.vertical, MonoSpace.sm)
                .background(MonoColor.panel)
                HairlineDivider()

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MonoSpace.xs) {
                        FilterChip(text: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(snippetManager.categories, id: \.self) { category in
                            FilterChip(text: category, isSelected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal, MonoSpace.md)
                    .padding(.vertical, MonoSpace.sm)
                }
                .background(MonoColor.panel)

                // Snippet list
                List {
                    ForEach(filteredSnippets) { snippet in
                        SnippetRow(snippet: snippet)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            snippetManager.remove(filteredSnippets[index])
                        }
                    }
                }
            }
            .navigationTitle("Snippets (\(snippetManager.snippets.count))")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: MonoIcon.plus)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddSnippetView()
            }
        }
    }

    private var filteredSnippets: [SnippetManager.Snippet] {
        var result = snippetManager.snippets
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !query.isEmpty {
            result = snippetManager.search(query).filter { category in
                selectedCategory == nil || category.category == selectedCategory
            }
        }
        return result
    }
}

struct FilterChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(MonoType.caption.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? MonoColor.snow : MonoColor.secondaryText)
                .padding(.horizontal, MonoSpace.sm)
                .padding(.vertical, MonoSpace.xs)
                .background(isSelected ? MonoColor.nearBlack : MonoColor.inset)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SnippetRow: View {
    let snippet: SnippetManager.Snippet
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.xs) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(MonoColor.tertiaryText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.title)
                        .font(MonoType.body)
                        .foregroundColor(MonoColor.primaryText)
                    HStack(spacing: MonoSpace.xs) {
                        Text(snippet.language)
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.tertiaryText)
                        Text("·")
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.tertiaryText)
                        Text(snippet.category)
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.tertiaryText)
                        if let shortcut = snippet.shortcut {
                            Text("· \(shortcut)")
                                .font(MonoType.caption)
                                .foregroundColor(MonoColor.tertiaryText)
                        }
                    }
                }
                Spacer()
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? MonoIcon.chevronDown : MonoIcon.chevronRight)
                        .foregroundColor(MonoColor.tertiaryText)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                Text(snippet.content)
                    .font(MonoType.codeSmall)
                    .foregroundColor(MonoColor.Code.plain)
                    .padding(MonoSpace.sm)
                    .background(MonoColor.paper)
                    .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))
                    .contextMenu {
                        Button("Copy") {
                            UIPasteboard.general.string = snippet.content
                        }
                    }
            }
        }
        .padding(.vertical, MonoSpace.xs)
    }
}

struct AddSnippetView: View {
    @StateObject private var snippetManager = SnippetManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var language = "swift"
    @State private var category = "Custom"
    @State private var content = ""
    @State private var shortcut = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    Picker("Language", selection: $language) {
                        ForEach(Language.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang.rawValue)
                        }
                    }
                    TextField("Category", text: $category)
                    TextField("Shortcut (optional)", text: $shortcut)
                }
                Section("Content") {
                    TextEditor(text: $content)
                        .font(MonoType.codeBody)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("New Snippet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        snippetManager.add(SnippetManager.Snippet(
                            title: title,
                            language: language,
                            content: content,
                            shortcut: shortcut.isEmpty ? nil : shortcut,
                            category: category
                        ))
                        dismiss()
                    }
                    .disabled(title.isEmpty || content.isEmpty)
                }
            }
        }
    }
}

/// Code metrics dashboard view.
public struct CodeMetricsView: View {
    @State private var metrics: CodeMetricsCalculator.ProjectMetrics?
    @State private var complexityMetrics: [CodeComplexityAnalyzer.FileMetrics] = []
    @State private var isLoading = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MonoSpace.lg) {
                if let metrics = metrics {
                    // Overview cards
                    HStack(spacing: MonoSpace.md) {
                        MetricCard(title: "Files", value: "\(metrics.totalFiles)", icon: "doc")
                        MetricCard(title: "Lines", value: "\(metrics.totalLines)", icon: "text.alignleft")
                        MetricCard(title: "Functions", value: "\(metrics.totalFunctions)", icon: "f.square")
                    }

                    HStack(spacing: MonoSpace.md) {
                        MetricCard(title: "Classes", value: "\(metrics.totalClasses)", icon: "c.square")
                        MetricCard(title: "Structs", value: "\(metrics.totalStructs)", icon: "s.square")
                        MetricCard(title: "Protocols", value: "\(metrics.totalProtocols)", icon: "p.square")
                    }

                    // Comment density
                    VStack(alignment: .leading, spacing: MonoSpace.sm) {
                        Text("Comment Density")
                            .font(MonoType.headline)
                        ProgressView(value: metrics.commentDensity)
                            .tint(MonoColor.active)
                        Text("\(String(format: "%.1f%%", metrics.commentDensity * 100))")
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                    .padding(MonoSpace.md)
                    .background(MonoColor.panel)
                    .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))

                    // Languages
                    VStack(alignment: .leading, spacing: MonoSpace.sm) {
                        Text("Languages")
                            .font(MonoType.headline)
                        ForEach(metrics.languages.sorted(by: { $0.value > $1.value }), id: \.key) { lang, count in
                            HStack {
                                Text(lang)
                                    .font(MonoType.body)
                                Spacer()
                                Text("\(count) files")
                                    .font(MonoType.caption)
                                    .foregroundColor(MonoColor.tertiaryText)
                            }
                        }
                    }
                    .padding(MonoSpace.md)
                    .background(MonoColor.panel)
                    .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))

                    // File types
                    VStack(alignment: .leading, spacing: MonoSpace.sm) {
                        Text("File Types")
                            .font(MonoType.headline)
                        ForEach(metrics.byFileType.sorted(by: { $0.value > $1.value }), id: \.key) { type, count in
                            HStack {
                                Text(".\(type)")
                                    .font(MonoType.codeBody)
                                Spacer()
                                Text("\(count) files")
                                    .font(MonoType.caption)
                                    .foregroundColor(MonoColor.tertiaryText)
                            }
                        }
                    }
                    .padding(MonoSpace.md)
                    .background(MonoColor.panel)
                    .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))

                    // Complexity hotspots
                    if !complexityMetrics.isEmpty {
                        VStack(alignment: .leading, spacing: MonoSpace.sm) {
                            Text("Complexity Hotspots")
                                .font(MonoType.headline)
                            let hotspots = CodeComplexityAnalyzer.shared.findHotspots(in: complexityMetrics)
                            if hotspots.isEmpty {
                                Text("No hotspots found ✓")
                                    .font(MonoType.body)
                                    .foregroundColor(MonoColor.success)
                            } else {
                                ForEach(hotspots, id: \.line) { hs in
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(MonoColor.warning)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(hs.name) (\(hs.file):\(hs.line))")
                                                .font(MonoType.body)
                                            Text("Cyclomatic: \(hs.cyclomaticComplexity) | Cognitive: \(hs.cognitiveComplexity)")
                                                .font(MonoType.caption)
                                                .foregroundColor(MonoColor.tertiaryText)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(MonoSpace.md)
                        .background(MonoColor.panel)
                        .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))
                    }
                } else if isLoading {
                    ProgressView("Analyzing project…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyState(
                        title: "No metrics available",
                        message: "Open a project to see code metrics.",
                        systemImage: "chart.bar"
                    )
                }
            }
            .padding(MonoSpace.md)
        }
        .navigationTitle("Code Metrics")
        .onAppear(perform: loadMetrics)
    }

    private func loadMetrics() {
        guard let project = WorkspaceState.shared.currentProject else {
            metrics = nil
            return
        }
        isLoading = true
        Task.detached {
            let m = CodeMetricsCalculator.shared.calculate(for: project.rootPath)
            let c = CodeComplexityAnalyzer.shared.analyzeProject(at: project.rootPath)
            await MainActor.run {
                metrics = m
                complexityMetrics = c
                isLoading = false
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: MonoSpace.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(MonoColor.tertiaryText)
            Text(value)
                .font(MonoType.title)
                .foregroundColor(MonoColor.primaryText)
            Text(title)
                .font(MonoType.caption)
                .foregroundColor(MonoColor.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(MonoSpace.md)
        .background(MonoColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))
    }
}

/// Bookmarks view.
public struct BookmarksView: View {
    @StateObject private var bookmarkManager = BookmarkManager.shared

    public init() {}

    public var body: some View {
        List {
            if bookmarkManager.bookmarks.isEmpty {
                Text("No bookmarks yet. Tap the bookmark icon next to a line number to add one.")
                    .font(MonoType.footnote)
                    .foregroundColor(MonoColor.tertiaryText)
            }
            ForEach(bookmarkManager.bookmarks) { bookmark in
                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.label.isEmpty ? "Line \(bookmark.line)" : bookmark.label)
                        .font(MonoType.body)
                        .foregroundColor(MonoColor.primaryText)
                    Text("\(bookmark.filePath):\(bookmark.line)")
                        .font(MonoType.caption)
                        .foregroundColor(MonoColor.tertiaryText)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    bookmarkManager.remove(bookmarkManager.bookmarks[index])
                }
            }
        }
        .navigationTitle("Bookmarks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    bookmarkManager.clearAll()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }
}

/// Recent files view.
public struct RecentFilesView: View {
    @StateObject private var recentFilesManager = RecentFilesManager.shared

    public init() {}

    public var body: some View {
        List {
            if recentFilesManager.recentFiles.isEmpty {
                Text("No recent files.")
                    .font(MonoType.footnote)
                    .foregroundColor(MonoColor.tertiaryText)
            }
            ForEach(recentFilesManager.recentFiles) { file in
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(MonoType.body)
                        .foregroundColor(MonoColor.primaryText)
                    HStack {
                        Text(file.project)
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.tertiaryText)
                        Spacer()
                        Text(file.openedAt.formatted(.relative(presentation: .named)))
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                }
            }
        }
        .navigationTitle("Recent Files")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    recentFilesManager.clear()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }
}

/// Search results view for the search indexer.
public struct SearchResultsView: View {
    @StateObject private var indexer = SearchIndexer.shared
    @State private var query: String = ""
    @State private var searchMode: SearchMode = .files

    enum SearchMode: String, CaseIterable, Hashable {
        case files, symbols, content
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: MonoIcon.search)
                    .foregroundColor(MonoColor.tertiaryText)
                TextField("Search…", text: $query)
                    .font(MonoType.body)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, MonoSpace.md)
            .padding(.vertical, MonoSpace.sm)
            .background(MonoColor.panel)

            Picker("", selection: $searchMode) {
                ForEach(SearchMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, MonoSpace.md)
            .padding(.vertical, MonoSpace.sm)

            List {
                switch searchMode {
                case .files:
                    ForEach(indexer.searchFiles(query), id: \.path) { file in
                        HStack {
                            Image(systemName: MonoIcon.doc)
                                .foregroundColor(MonoColor.tertiaryText)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(MonoType.body)
                                Text(file.language)
                                    .font(MonoType.caption)
                                    .foregroundColor(MonoColor.tertiaryText)
                            }
                        }
                    }
                case .symbols:
                    ForEach(indexer.searchSymbols(query), id: \.name) { symbol in
                        HStack {
                            Image(systemName: "f.square")
                                .foregroundColor(MonoColor.tertiaryText)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(symbol.name)
                                    .font(MonoType.body)
                                Text("\(symbol.file):\(symbol.line)")
                                    .font(MonoType.caption)
                                    .foregroundColor(MonoColor.tertiaryText)
                            }
                        }
                    }
                case .content:
                    ForEach(indexer.searchContent(query), id: \.file) { result in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.file)
                                .font(MonoType.caption)
                                .foregroundColor(MonoColor.tertiaryText)
                            Text("Line \(result.line): \(result.snippet)")
                                .font(MonoType.body)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Search")
    }
}
