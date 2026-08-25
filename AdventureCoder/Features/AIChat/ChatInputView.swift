import SwiftUI

/// Input bar at the bottom of the AI chat.
public struct ChatInputView: View {
    @Binding var draft: String
    var focused: FocusState<Bool>.Binding
    let onSend: () -> Void

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: MonoSpace.sm) {
                Button(action: {}) {
                    Image(systemName: MonoIcon.clip)
                        .foregroundColor(MonoColor.tertiaryText)
                        .padding(8)
                }
                .buttonStyle(.plain)
                TextEditor(text: $draft)
                    .font(MonoType.body)
                    .frame(minHeight: 28, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused(focused)
                Button(action: onSend) {
                    Image(systemName: MonoIcon.paperPlane)
                        .foregroundColor(MonoColor.primaryText)
                        .padding(10)
                        .background(MonoColor.nearBlack)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, MonoSpace.md)
            .padding(.vertical, MonoSpace.sm)
            .background(MonoColor.elevated)
            .overlay(
                RoundedRectangle(cornerRadius: MonoSpace.cornerRadiusLg)
                    .stroke(MonoColor.hairline, lineWidth: 1)
            )
            .padding(.horizontal, MonoSpace.md)
            .padding(.vertical, MonoSpace.sm)
        }
        .background(MonoColor.panel)
    }
}

/// Agent activity panel — shows what each agent is doing without exposing private reasoning.
public struct AgentActivityView: View {
    @StateObject private var orchestrator = AgentOrchestrator.shared

    public var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.xs) {
            HStack {
                Image(systemName: MonoIcon.bolt)
                    .foregroundColor(MonoColor.secondaryText)
                Text("Working on your request")
                    .font(MonoType.headline)
                    .foregroundColor(MonoColor.primaryText)
                Spacer()
                ProgressView()
                    .scaleEffect(0.7)
            }
            ForEach(orchestrator.activities) { activity in
                AgentActivityRow(activity: activity)
            }
        }
        .padding(MonoSpace.md)
        .background(MonoColor.inset)
        .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))
    }
}

struct AgentActivityRow: View {
    let activity: AgentActivity
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: MonoSpace.xxs) {
            HStack(spacing: MonoSpace.xs) {
                statusIcon
                Text(activity.agentName)
                    .font(MonoType.caption.weight(.medium))
                    .foregroundColor(MonoColor.primaryText)
                Text(activity.summary)
                    .font(MonoType.caption)
                    .foregroundColor(MonoColor.secondaryText)
                    .lineLimit(1)
                Spacer()
                if !activity.toolInvocations.isEmpty {
                    Button(action: { expanded.toggle() }) {
                        Image(systemName: expanded ? MonoIcon.chevronDown : MonoIcon.chevronRight)
                            .font(.system(size: 9))
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            if expanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(activity.toolInvocations) { inv in
                        HStack(spacing: MonoSpace.xs) {
                            Image(systemName: MonoIcon.bolt)
                                .font(.system(size: 9))
                                .foregroundColor(MonoColor.tertiaryText)
                            Text(inv.toolName)
                                .font(MonoType.caption2)
                                .foregroundColor(MonoColor.primaryText)
                            Text(inv.inputSummary)
                                .font(MonoType.caption2)
                                .foregroundColor(MonoColor.tertiaryText)
                                .lineLimit(1)
                            Spacer()
                            Text(inv.status.label)
                                .font(MonoType.caption2)
                                .foregroundColor(MonoColor.tertiaryText)
                        }
                    }
                    ForEach(activity.filesAffected, id: \.self) { f in
                        Text(f)
                            .font(MonoType.caption2)
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                }
                .padding(.leading, MonoSpace.md)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch activity.status {
        case .pending:
            Image(systemName: MonoIcon.circle).foregroundColor(MonoColor.tertiaryText)
        case .running:
            Image(systemName: MonoIcon.circleDot).foregroundColor(MonoColor.warning)
        case .completed:
            Image(systemName: MonoIcon.check).foregroundColor(MonoColor.success)
        case .failed:
            Image(systemName: MonoIcon.error).foregroundColor(MonoColor.error)
        case .skipped:
            Image(systemName: MonoIcon.circle).foregroundColor(MonoColor.tertiaryText)
        }
    }
}
