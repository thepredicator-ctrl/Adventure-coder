import SwiftUI

/// Polished model selector with provider grouping, free badges, search, and animations.
public struct ModelSelectorView: View {
    @StateObject private var modelStore = CachedModelStore.shared
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var chatService = AIChatService.shared
    @State private var searchQuery = ""
    @State private var isLoading = false
    @Binding var isPresented: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Select Model")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Choose the AI model for your requests")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.4))
                }
                Spacer()
                Button(action: { withAnimation(AppAnimation.standard) { isPresented = false } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.4))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.3))
                TextField("Search models…", text: $searchQuery)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.04))
            .cornerRadius(7)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Refresh button
            HStack {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.6)
                    Text("Loading models…")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.4))
                } else {
                    Button(action: refreshModels) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                            Text("Refresh")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(Color(white: 0.4))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("\(filteredModels.count) models")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.3))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Model list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    // Group by provider
                    ForEach(Array(groupedModels.keys.sorted()), id: \.self) { providerId in
                        let providerName = providerId == "openrouter" ? "OpenRouter" : "Hugging Face"
                        let models = groupedModels[providerId] ?? []

                        Section {
                            ForEach(models) { model in
                                ModelRow(
                                    model: model,
                                    isSelected: isSelected(model),
                                    onSelect: {
                                        selectModel(model)
                                        withAnimation(AppAnimation.standard) { isPresented = false }
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95)).animation(AppAnimation.smooth),
                                    removal: .opacity
                                ))
                            }
                        } header: {
                            HStack {
                                Text(providerName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(0.5)
                                    .foregroundColor(Color(white: 0.35))
                                Spacer()
                                Text("\(models.count)")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(white: 0.25))
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                        }
                    }

                    if filteredModels.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "cpu.slots")
                                .font(.system(size: 32))
                                .foregroundColor(Color(white: 0.1))
                            Text(searchQuery.isEmpty ? "No models available" : "No models match '\(searchQuery)'")
                                .font(.system(size: 14))
                                .foregroundColor(Color(white: 0.3))
                            if !searchQuery.isEmpty {
                                Button("Clear search") { searchQuery = "" }
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.5))
                            } else {
                                Text("Add an API key in Connections to discover models")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.25))
                            }
                        }
                        .padding(.top, 40)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color.black.opacity(0.98))
        .task {
            if modelStore.models.isEmpty {
                await refreshModelsAsync()
            }
        }
    }

    // MARK: - Computed

    private var filteredModels: [AIModel] {
        let models = modelStore.models
        if searchQuery.isEmpty { return models }
        return models.filter { $0.displayName.localizedCaseInsensitiveContains(searchQuery) }
    }

    private var groupedModels: [String: [AIModel]] {
        Dictionary(grouping: filteredModels, by: { $0.providerId })
    }

    private func isSelected(_ model: AIModel) -> Bool {
        settings.primaryModelId == model.modelId
    }

    private func selectModel(_ model: AIModel) {
        chatService.selectModel(providerId: model.providerId, modelId: model.modelId)
    }

    // MARK: - Actions

    private func refreshModels() {
        Task { await refreshModelsAsync() }
    }

    private func refreshModelsAsync() async {
        isLoading = true
        await modelStore.refresh()
        isLoading = false
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: AIModel
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.green : Color.white.opacity(0.1), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    if isSelected {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // Model info
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.displayName)
                        .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if model.isFree {
                            Text("FREE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(3)
                        }
                        if model.supportsToolCalls {
                            Text("tools")
                                .font(.system(size: 9))
                                .foregroundColor(Color(white: 0.4))
                        }
                        if model.contextLength > 0 {
                            Text(String(model.contextLength / 1000) + "K ctx")
                                .font(.system(size: 9))
                                .foregroundColor(Color(white: 0.35))
                        }
                    }
                }

                Spacer()

                if isSelected {
                    PulsingDot(color: .green, size: 6)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.green.opacity(0.05) : (isHovered ? Color.white.opacity(0.03) : Color.clear))
            )
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { isHovered = $0 }
        .animation(AppAnimation.fast, value: isHovered)
        .animation(AppAnimation.smooth, value: isSelected)
    }
}

// MARK: - Compact Model Picker Button

/// Compact model picker button for use in headers.
public struct ModelPickerButton: View {
    @State private var showSelector = false
    @StateObject private var chatService = AIChatService.shared

    public init() {}

    public var body: some View {
        Button(action: { withAnimation(AppAnimation.standard) { showSelector = true } }) {
            HStack(spacing: 6) {
                PulsingDot(color: .green, size: 5)
                Text(chatService.selectedModelDisplayName)
                    .font(.system(size: 12))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundColor(Color(white: 0.55))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)
        }
        .buttonStyle(PressableButtonStyle())
        .smoothModal(isPresented: $showSelector) {
            VStack {
                if showSelector {
                    ModelSelectorView(isPresented: $showSelector)
                        .frame(maxWidth: 420, maxHeight: 520)
                        .background(Color.black.opacity(0.98))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(40)
                }
            }
        }
    }
}
