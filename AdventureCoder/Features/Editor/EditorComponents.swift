import SwiftUI

/// Find & replace bar shown above the editor.
struct FindReplaceView: View {
    @Binding var findQuery: String
    @Binding var replaceQuery: String
    let onReplace: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: MonoSpace.sm) {
            Image(systemName: MonoIcon.search)
                .foregroundColor(MonoColor.tertiaryText)
            TextField("Find", text: $findQuery)
                .font(MonoType.body)
                .textFieldStyle(.plain)
            Divider().frame(height: 14)
            TextField("Replace", text: $replaceQuery)
                .font(MonoType.body)
                .textFieldStyle(.plain)
            Button("Replace All", action: onReplace)
                .font(MonoType.caption.weight(.medium))
                .foregroundColor(MonoColor.primaryText)
            Button(action: onClose) {
                Image(systemName: MonoIcon.close)
                    .foregroundColor(MonoColor.tertiaryText)
            }
        }
        .padding(.horizontal, MonoSpace.md)
        .padding(.vertical, MonoSpace.sm)
        .background(MonoColor.panel)
    }
}

/// Status bar at the bottom of the editor showing line/column, language, and diagnostics.
struct EditorStatusBar: View {
    let node: FileNode
    let diagnostics: [SwiftSyntaxDiagnostic]

    var body: some View {
        HStack(spacing: MonoSpace.md) {
            if !diagnostics.isEmpty {
                let errors = diagnostics.filter { $0.severity == .error }
                let warnings = diagnostics.filter { $0.severity == .warning }
                if !errors.isEmpty {
                    Label("\(errors.count)", systemImage: MonoIcon.error)
                        .font(MonoType.caption)
                        .foregroundColor(MonoColor.error)
                }
                if !warnings.isEmpty {
                    Label("\(warnings.count)", systemImage: MonoIcon.warning)
                        .font(MonoType.caption)
                        .foregroundColor(MonoColor.warning)
                }
            }
            Spacer()
            Text(node.language.displayName)
                .font(MonoType.caption)
                .foregroundColor(MonoColor.tertiaryText)
            Text("UTF-8")
                .font(MonoType.caption)
                .foregroundColor(MonoColor.tertiaryText)
            Text("LF")
                .font(MonoType.caption)
                .foregroundColor(MonoColor.tertiaryText)
        }
        .padding(.horizontal, MonoSpace.md)
        .frame(height: MonoSpace.statusBarHeight)
        .background(MonoColor.panel)
    }
}
