import SwiftUI

/// Diff viewer with accept / reject / revert.
public struct DiffView: View {
    let diff: FileDiff
    @State private var status: FileDiff.Status

    public init(diff: FileDiff) {
        self.diff = diff
        self._status = State(initialValue: diff.status)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(diff.filePath)
                        .font(MonoType.headline)
                        .foregroundColor(MonoColor.primaryText)
                    Text("by \(diff.agentName) · \(diff.summary)")
                        .font(MonoType.caption)
                        .foregroundColor(MonoColor.tertiaryText)
                }
                Spacer()
                StatusPill(pillStatus, text: status.label)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(diff.hunks) { hunk in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(hunk.header)
                                .font(MonoType.codeSmall)
                                .foregroundColor(MonoColor.tertiaryText)
                                .padding(.horizontal, MonoSpace.sm)
                                .padding(.vertical, MonoSpace.xs)
                            ForEach(hunk.lines) { line in
                                HStack(spacing: 0) {
                                    Text("\(line.oldLineNumber.map { "\($0)" } ?? "")")
                                        .frame(width: 32, alignment: .trailing)
                                        .font(MonoType.lineNumber)
                                        .foregroundColor(MonoColor.quaternaryText)
                                    Text("\(line.newLineNumber.map { "\($0)" } ?? "")")
                                        .frame(width: 32, alignment: .trailing)
                                        .font(MonoType.lineNumber)
                                        .foregroundColor(MonoColor.quaternaryText)
                                    Text(line.kind.prefix)
                                        .frame(width: 16, alignment: .center)
                                        .font(MonoType.codeSmall)
                                        .foregroundColor(lineColor(for: line.kind))
                                    Text(line.content)
                                        .font(MonoType.codeSmall)
                                        .foregroundColor(lineContentColor(for: line.kind))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .background(lineBackground(for: line.kind))
                            }
                        }
                    }
                }
                .padding(.vertical, MonoSpace.sm)
            }
            HStack(spacing: MonoSpace.sm) {
                if status == .pending {
                    Button("Accept") {
                        status = .accepted
                        applyModified()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Reject") {
                        status = .rejected
                        revertToOriginal()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Revert") {
                        status = .reverted
                        revertToOriginal()
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
        }
        .padding(MonoSpace.md)
        .background(MonoColor.canvas)
    }

    private var pillStatus: StatusPill.Kind {
        switch status {
        case .pending: return .working
        case .accepted: return .success
        case .rejected: return .error
        case .reverted: return .idle
        }
    }

    private func lineColor(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .added: return MonoColor.success
        case .removed: return MonoColor.error
        case .context: return MonoColor.tertiaryText
        }
    }

    private func lineContentColor(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .added: return MonoColor.primaryText
        case .removed: return MonoColor.secondaryText
        case .context: return MonoColor.primaryText
        }
    }

    private func lineBackground(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .added: return MonoColor.successBg.opacity(0.4)
        case .removed: return MonoColor.errorBg.opacity(0.4)
        case .context: return Color.clear
        }
    }

    private func applyModified() {
        guard let project = WorkspaceState.shared.currentProject else { return }
        let abs = FileSystem.shared.join(project.rootPath, diff.filePath)
        try? FileSystem.shared.write(abs, content: diff.modifiedContent)
    }

    private func revertToOriginal() {
        guard let project = WorkspaceState.shared.currentProject else { return }
        let abs = FileSystem.shared.join(project.rootPath, diff.filePath)
        try? FileSystem.shared.write(abs, content: diff.originalContent)
    }
}
