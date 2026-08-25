import SwiftUI

/// Renders a single chat message, including code blocks and diffs.
public struct ChatMessageView: View {
    public let message: ChatMessage

    public var body: some View {
        HStack(alignment: .top, spacing: MonoSpace.sm) {
            if message.role == .user {
                Spacer(minLength: 40)
            }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: MonoSpace.xs) {
                if message.role != .user {
                    HStack(spacing: 6) {
                        Image(systemName: MonoIcon.sparkles)
                            .font(.system(size: 11))
                            .foregroundColor(MonoColor.tertiaryText)
                        Text(message.modelId ?? "Assistant")
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                }
                content
                    .padding(.horizontal, MonoSpace.md)
                    .padding(.vertical, MonoSpace.sm)
                    .background(message.role == .user ? MonoColor.cloud : MonoColor.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadiusLg))
                if !message.diffs.isEmpty {
                    VStack(spacing: MonoSpace.xs) {
                        ForEach(message.diffs) { diff in
                            DiffSummaryRow(diff: diff)
                        }
                    }
                }
            }
            if message.role != .user {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, MonoSpace.md)
    }

    @ViewBuilder
    private var content: some View {
        if message.streaming && message.content.isEmpty {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(MonoColor.tertiaryText)
                        .frame(width: 4, height: 4)
                        .opacity(0.6)
                }
            }
            .padding(.vertical, 2)
        } else {
            // Parse out fenced code blocks
            let segments = parseSegments(message.content)
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: MonoSpace.xs) {
                ForEach(segments.indices, id: \.self) { idx in
                    let seg = segments[idx]
                    switch seg {
                    case .text(let text):
                        Text(text)
                            .font(MonoType.body)
                            .foregroundColor(MonoColor.primaryText)
                            .multilineTextAlignment(.leading)
                    case .code(let lang, let code):
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text(lang)
                                    .font(MonoType.caption2)
                                    .foregroundColor(MonoColor.tertiaryText)
                                Spacer()
                                Button(action: { UIPasteboard.general.string = code }) {
                                    Image(systemName: MonoIcon.copy)
                                        .font(.system(size: 9))
                                        .foregroundColor(MonoColor.tertiaryText)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, MonoSpace.sm)
                            .padding(.vertical, MonoSpace.xs)
                            .background(MonoColor.paper)
                            Text(code)
                                .font(MonoType.codeBody)
                                .foregroundColor(MonoColor.Code.plain)
                                .textSelection(.enabled)
                                .padding(MonoSpace.sm)
                                .background(MonoColor.paper)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: MonoSpace.cornerRadius)
                                .stroke(MonoColor.hairline, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))
                    }
                }
            }
        }
    }

    private enum Segment {
        case text(String)
        case code(String, String)
    }

    private func parseSegments(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        let pattern = #"```([a-zA-Z0-9]*)\n([\s\S]*?)```"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [.text(text)]
        }
        let ns = text as NSString
        var lastEnd = 0
        regex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match = match, match.numberOfRanges >= 3 else { return }
            if match.range.location > lastEnd {
                let before = ns.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(.text(before))
                }
            }
            let lang = ns.substring(with: match.range(at: 1)).isEmpty ? "text" : ns.substring(with: match.range(at: 1))
            let code = ns.substring(with: match.range(at: 2))
            segments.append(.code(lang, code))
            lastEnd = match.range.location + match.range.length
        }
        if lastEnd < ns.length {
            let after = ns.substring(from: lastEnd)
            if !after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(.text(after))
            }
        }
        return segments.isEmpty ? [.text(text)] : segments
    }
}

struct DiffSummaryRow: View {
    let diff: FileDiff
    var body: some View {
        HStack {
            Image(systemName: MonoIcon.diff)
                .foregroundColor(MonoColor.secondaryText)
            Text(diff.filePath)
                .font(MonoType.caption)
                .foregroundColor(MonoColor.primaryText)
            Spacer()
            Text(diff.summary)
                .font(MonoType.caption2)
                .foregroundColor(MonoColor.tertiaryText)
        }
        .padding(.horizontal, MonoSpace.sm)
        .padding(.vertical, MonoSpace.xs)
        .background(MonoColor.inset)
        .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadiusSm))
    }
}
