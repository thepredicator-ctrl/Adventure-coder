import SwiftUI
import UIKit

/// The center editor pane: tabs + code editor + status bar.
public struct EditorPaneView: View {
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var settings = SettingsStore.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            EditorTabBar()
            HairlineDivider()
            if let active = workspace.activeFile {
                CodeEditorView(node: active)
            } else {
                EmptyState(
                    title: "No file open",
                    message: "Select a file from the sidebar or create a new one to start editing.",
                    systemImage: MonoIcon.doc
                )
            }
        }
        .background(MonoColor.canvas)
    }
}

struct EditorTabBar: View {
    @StateObject private var workspace = WorkspaceState.shared

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(workspace.openFiles, id: \.relativePath) { node in
                    let isActive = workspace.activeFile?.relativePath == node.relativePath
                    HStack(spacing: MonoSpace.xs) {
                        Image(systemName: node.fileIcon)
                            .font(.system(size: 10))
                            .foregroundColor(MonoColor.tertiaryText)
                        Text(node.name)
                            .font(MonoType.caption.weight(isActive ? .semibold : .regular))
                            .foregroundColor(isActive ? MonoColor.primaryText : MonoColor.secondaryText)
                        Button(action: { workspace.closeFile(node) }) {
                            Image(systemName: MonoIcon.close)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(MonoColor.tertiaryText)
                        }
                        .buttonStyle(.plain)
                        .opacity(isActive ? 1 : 0.5)
                    }
                    .padding(.horizontal, MonoSpace.md)
                    .frame(height: MonoSpace.tabBarHeight)
                    .background(isActive ? MonoColor.canvas : MonoColor.panel)
                    .overlay(alignment: .top) {
                        if isActive {
                            Rectangle().fill(MonoColor.nearBlack).frame(height: 2)
                        }
                    }
                    .onTapGesture { workspace.activeFile = node }
                    Rectangle().fill(MonoColor.hairline).frame(width: 1)
                }
            }
        }
        .frame(height: MonoSpace.tabBarHeight)
        .background(MonoColor.panel)
    }
}

/// SwiftUI wrapper around a UITextView-based code editor.
public struct CodeEditorView: View {
    let node: FileNode
    @StateObject private var settings = SettingsStore.shared
    @State private var content: String = ""
    @State private var showFindReplace = false
    @State private var findQuery = ""
    @State private var replaceQuery = ""
    @State private var diagnostics: [SwiftSyntaxDiagnostic] = []

    public var body: some View {
        VStack(spacing: 0) {
            if showFindReplace {
                FindReplaceView(findQuery: $findQuery, replaceQuery: $replaceQuery, onReplace: replaceAll, onClose: { showFindReplace = false })
                HairlineDivider()
            }
            CodeEditorRepresentable(
                content: $content,
                language: node.language,
                settings: settings,
                onChange: handleEdit
            )
            .background(MonoColor.canvas)
            EditorStatusBar(node: node, diagnostics: diagnostics)
            HairlineDivider()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showFindReplace.toggle() }) { Image(systemName: MonoIcon.search) }
                    .help("Find & Replace (⌘F)")
                Button(action: save) { Image(systemName: "arrow.down.to.line") }
                    .help("Save (⌘S)")
            }
        }
        .keyboardShortcut("f", modifiers: .command)
        .onAppear(perform: load)
        .onChange(of: node.relativePath) { _ in load() }
    }

    private func load() {
        content = (try? FileSystem.shared.read(node.absolutePath)) ?? ""
        recomputeDiagnostics()
    }

    private func handleEdit(_ newContent: String) {
        content = newContent
        recomputeDiagnostics()
    }

    private func recomputeDiagnostics() {
        if node.language == .swift {
            diagnostics = SwiftSyntaxChecker.check(content: content, path: node.name)
        } else {
            diagnostics = []
        }
    }

    private func save() {
        try? FileSystem.shared.write(node.absolutePath, content: content)
    }

    private func replaceAll() {
        content = content.replacingOccurrences(of: findQuery, with: replaceQuery)
        recomputeDiagnostics()
    }
}

/// UITextView-backed editor with monospace font, line numbers, and basic syntax highlighting.
struct CodeEditorRepresentable: UIViewRepresentable {
    @Binding var content: String
    let language: Language
    let settings: SettingsStore
    let onChange: (String) -> Void

    func makeUIView(context: Context) -> CodeTextView {
        let tv = CodeTextView()
        tv.delegate = context.coordinator
        tv.font = MonoType.uiCodeFont(CGFloat(settings.editorFontSize))
        tv.backgroundColor = .systemBackground
        tv.textColor = .label
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.smartQuotesType = .no
        tv.smartDashesType = .no
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.adjustsFontForContentSizeCategory = false
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        tv.text = content
        tv.language = language
        tv.lineNumbersVisible = settings.editorShowLineNumbers
        tv.tabSize = settings.editorTabSize
        tv.wordWrap = settings.editorWordWrap
        tv.applyHighlight()
        return tv
    }

    func updateUIView(_ uiView: CodeTextView, context: Context) {
        if uiView.text != content {
            uiView.text = content
            uiView.applyHighlight()
        }
        uiView.font = MonoType.uiCodeFont(CGFloat(settings.editorFontSize))
        uiView.lineNumbersVisible = settings.editorShowLineNumbers
        uiView.tabSize = settings.editorTabSize
        uiView.wordWrap = settings.editorWordWrap
        uiView.language = language
        uiView.applyHighlight()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: CodeEditorRepresentable
        init(_ parent: CodeEditorRepresentable) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            let text = textView.text ?? ""
            parent.content = text
            parent.onChange(text)
            (textView as? CodeTextView)?.applyHighlight()
        }
    }
}

/// Custom UITextView that renders line numbers in a left gutter and applies
/// lightweight syntax highlighting via NSAttributedString.
final class CodeTextView: UITextView {
    var lineNumbersVisible: Bool = true {
        didSet { setNeedsLayout(); setNeedsDisplay() }
    }
    var tabSize: Int = 4 {
        didSet { applyHighlight() }
    }
    var wordWrap: Bool = false {
        didSet {
            textContainer.lineBreakMode = wordWrap ? .byWordWrapping : .byClipping
            textContainer.widthTracksTextView = wordWrap
            textContainer.size = CGSize(width: wordWrap ? bounds.width : 100_000, height: bounds.height)
        }
    }
    var language: Language = .plain {
        didSet { applyHighlight() }
    }
    private let gutterWidth: CGFloat = 44
    private var lineNumberLayer = CALayer()
    private var lineNumberTextLayer = CATextLayer()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isEditable = true
        isSelectable = true
        showsVerticalScrollIndicator = true
        showsHorizontalScrollIndicator = true
        alwaysBounceVertical = true
        contentInset = UIEdgeInsets(top: 0, left: lineNumbersVisible ? gutterWidth : 0, bottom: 0, right: 0)
        textContainer.lineFragmentPadding = 8
        backgroundColor = .systemBackground

        lineNumberLayer.frame = CGRect(x: 0, y: 0, width: gutterWidth, height: bounds.height)
        lineNumberLayer.backgroundColor = UIColor.secondarySystemBackground.cgColor
        layer.addSublayer(lineNumberLayer)

        lineNumberTextLayer.frame = CGRect(x: 0, y: 8, width: gutterWidth - 8, height: bounds.height)
        lineNumberTextLayer.fontSize = 10
        lineNumberTextLayer.foregroundColor = UIColor.tertiaryLabel.cgColor
        lineNumberTextLayer.alignmentMode = .right
        lineNumberTextLayer.contentsScale = UIScreen.main.scale
        lineNumberLayer.addSublayer(lineNumberTextLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        lineNumberLayer.frame = CGRect(x: 0, y: 0, width: gutterWidth, height: bounds.height)
        lineNumberLayer.isHidden = !lineNumbersVisible
        contentInset.left = lineNumbersVisible ? gutterWidth : 0
        updateLineNumbers()
    }

    func applyHighlight() {
        guard let attributed = attributedText else { return }
        let mutable = NSMutableAttributedString(attributedString: attributed)
        mutable.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: mutable.length))
        mutable.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: mutable.length))
        let font = self.font ?? MonoType.uiCodeFont(13)
        mutable.addAttribute(.font, value: font, range: NSRange(location: 0, length: mutable.length))
        SyntaxHighlighter.highlight(mutable, language: language, font: font)
        let selected = selectedRange
        attributedText = mutable
        selectedRange = selected
    }

    private func updateLineNumbers() {
        guard lineNumbersVisible else {
            lineNumberTextLayer.string = ""
            return
        }
        let lineCount = (text as NSString).components(separatedBy: "\n").count
        let numbers = (1...lineCount).map { String($0) }.joined(separator: "\n")
        lineNumberTextLayer.string = numbers
        let verticalOffset = -contentOffset.y + 8
        lineNumberTextLayer.frame = CGRect(x: 0, y: verticalOffset, width: gutterWidth - 8, height: bounds.height)
    }
}

extension CodeTextView {
    // Observe our own scroll via layoutSubviews; no override needed.
}
