import SwiftUI

/// Right-side AI assistant panel.
public struct AIChatView: View {
    @StateObject private var workspace = WorkspaceState.shared
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @StateObject private var modelStore = CachedModelStore.shared
    @State private var draft: String = ""
    @FocusState private var inputFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
            HairlineDivider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonoSpace.md) {
                        if let conv = workspace.currentConversation {
                            ForEach(conv.messages) { msg in
                                ChatMessageView(message: msg).id(msg.id)
                            }
                        }
                        if orchestrator.isRunning {
                            AgentActivityView()
                                .padding(.horizontal, MonoSpace.md)
                        }
                    }
                    .padding(.vertical, MonoSpace.md)
                }
                .onChange(of: workspace.currentConversation?.messages.count) { _ in
                    if let last = workspace.currentConversation?.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            HairlineDivider()
            ChatInputView(draft: $draft, focused: $inputFocused, onSend: send)
        }
        .background(MonoColor.panel)
    }

    private var header: some View {
        HStack(spacing: MonoSpace.sm) {
            Image(systemName: MonoIcon.sparkles)
                .foregroundColor(MonoColor.primaryText)
            Text("AI Assistant")
                .font(MonoType.title2)
            Spacer()
            ModelPickerButton()
            Button(action: { workspace.chatCollapsed = true }) {
                Image(systemName: MonoIcon.close)
                    .foregroundColor(MonoColor.tertiaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MonoSpace.md)
        .padding(.vertical, MonoSpace.sm)
    }

    private func send() {
        guard let conv = workspace.currentConversation, !draft.isEmpty else { return }
        let userMsg = ChatMessage(role: .user, content: draft)
        ProjectStore.shared.appendMessage(userMsg, to: conv)
        let request = draft
        draft = ""
        Task {
            var mutableConv = conv
            mutableConv.messages.append(userMsg)
            let updated: Conversation
            if looksLikeBuild(request) {
                updated = await orchestrator.runRequest(request, project: workspace.currentProject!, conversation: mutableConv)
            } else {
                updated = await orchestrator.streamSimpleChat(request, project: workspace.currentProject!, conversation: mutableConv) { _ in }
            }
            workspace.currentConversation = updated
        }
    }

    private func looksLikeBuild(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let triggers = ["build", "create", "make", "implement", "add", "fix", "refactor", "generate", "scaffold", "wire up"]
        return triggers.contains { lowered.contains($0) } && lowered.count > 4
    }
}

struct ModelPickerButton: View {
    @StateObject private var modelStore = CachedModelStore.shared
    @State private var showPicker = false

    var body: some View {
        Button(action: { showPicker.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: MonoIcon.model)
                    .font(.system(size: 10))
                Text(currentModelName)
                    .font(MonoType.caption)
                    .foregroundColor(MonoColor.secondaryText)
                Image(systemName: MonoIcon.chevronDown)
                    .font(.system(size: 8))
                    .foregroundColor(MonoColor.tertiaryText)
            }
            .padding(.horizontal, MonoSpace.sm)
            .padding(.vertical, MonoSpace.xs + 1)
            .background(MonoColor.inset)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker) {
            ModelPickerPopover()
                .frame(width: 320, height: 420)
        }
    }

    private var currentModelName: String {
        if let id = SettingsStore.shared.primaryModelId, let model = modelStore.find(modelId: id) {
            return model.displayName
        }
        if let first = modelStore.freeModels.first {
            return first.displayName
        }
        return "No model"
    }
}

struct ModelPickerPopover: View {
    @StateObject private var modelStore = CachedModelStore.shared
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Models")
                    .font(MonoType.headline)
                Spacer()
                if modelStore.isRefreshing {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Button(action: { Task { await modelStore.refresh() } }) {
                        Image(systemName: MonoIcon.refresh)
                            .foregroundColor(MonoColor.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, MonoSpace.md)
            .padding(.vertical, MonoSpace.sm)
            HairlineDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: MonoSpace.xs) {
                    SectionHeader("Free Models")
                    ForEach(modelStore.freeModels) { model in
                        modelRow(model)
                    }
                    if settings.allowPaidModels {
                        SectionHeader("Paid Models")
                        ForEach(modelStore.paidModels) { model in
                            modelRow(model)
                        }
                    }
                }
            }
        }
        .background(MonoColor.panel)
    }

    private func modelRow(_ model: AIModel) -> some View {
        let isSelected = settings.primaryModelId == model.modelId
        return Button(action: {
            settings.primaryModelId = model.modelId
            settings.codingModelId = settings.codingModelId ?? model.modelId
            settings.fastModelId = settings.fastModelId ?? model.modelId
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(MonoType.body)
                        .foregroundColor(MonoColor.primaryText)
                    HStack(spacing: MonoSpace.sm) {
                        Text(model.providerId)
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.tertiaryText)
                        Text("\(model.contextLength / 1000)K ctx")
                            .font(MonoType.caption)
                            .foregroundColor(MonoColor.tertiaryText)
                        if model.supportsToolCalls {
                            Text("tools")
                                .font(MonoType.caption2)
                                .foregroundColor(MonoColor.tertiaryText)
                        }
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: MonoIcon.check)
                        .foregroundColor(MonoColor.active)
                }
            }
            .padding(.horizontal, MonoSpace.md)
            .padding(.vertical, MonoSpace.sm)
            .background(isSelected ? MonoColor.cloud : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
