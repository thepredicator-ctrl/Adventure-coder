import SwiftUI

/// Conflict resolution view for files that changed both locally and remotely.
public struct ConflictResolutionView: View {
    let localContent: String
    let remoteContent: String
    let filePath: String
    let onResolve: (Resolution) -> Void

    public enum Resolution {
        case keepLocal
        case keepRemote
        case merged(String)
    }

    @State private var mergedContent: String = ""
    @State private var showMergeEditor = false

    public init(localContent: String, remoteContent: String, filePath: String, onResolve: @escaping (Resolution) -> Void) {
        self.localContent = localContent
        self.remoteContent = remoteContent
        self.filePath = filePath
        self.onResolve = onResolve
    }

    public var body: some View {
        VStack(spacing: MonoSpace.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("File changed remotely")
                        .font(MonoType.title2)
                    Text(filePath)
                        .font(MonoType.caption)
                        .foregroundColor(MonoColor.tertiaryText)
                }
                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: MonoSpace.md) {
                    diffSection(title: "Local", content: localContent, color: MonoColor.primaryText)
                    diffSection(title: "Remote", content: remoteContent, color: MonoColor.active)
                }
            }

            HStack(spacing: MonoSpace.sm) {
                Button("Keep Local") { onResolve(.keepLocal) }
                    .buttonStyle(.bordered)
                Button("Keep Remote") { onResolve(.keepRemote) }
                    .buttonStyle(.bordered)
                Button("Compare") { showMergeEditor = true }
                    .buttonStyle(.bordered)
                Button("Merge") { onResolve(.merged(mergedContent.isEmpty ? remoteContent : mergedContent)) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(MonoSpace.md)
        .sheet(isPresented: $showMergeEditor) {
            MergeEditorView(localContent: localContent, remoteContent: remoteContent, mergedContent: $mergedContent)
        }
        .onAppear { mergedContent = remoteContent }
    }

    private func diffSection(title: String, content: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: MonoSpace.xs) {
            Text(title)
                .font(MonoType.headline)
                .foregroundColor(color)
            Text(content)
                .font(MonoType.codeSmall)
                .foregroundColor(MonoColor.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(MonoSpace.sm)
                .background(MonoColor.inset)
                .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))
        }
    }
}

struct MergeEditorView: View {
    let localContent: String
    let remoteContent: String
    @Binding var mergedContent: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Local")
                                .font(MonoType.caption)
                                .foregroundColor(MonoColor.tertiaryText)
                                .padding(.bottom, MonoSpace.sm)
                            Text(localContent)
                                .font(MonoType.codeSmall)
                                .foregroundColor(MonoColor.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(MonoSpace.md)
                    }
                    .background(MonoColor.canvas)
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Remote")
                                .font(MonoType.caption)
                                .foregroundColor(MonoColor.tertiaryText)
                                .padding(.bottom, MonoSpace.sm)
                            Text(remoteContent)
                                .font(MonoType.codeSmall)
                                .foregroundColor(MonoColor.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(MonoSpace.md)
                    }
                    .background(MonoColor.canvas)
                }
                Divider()
                TextEditor(text: $mergedContent)
                    .font(MonoType.codeBody)
                    .scrollContentBackground(.hidden)
                    .background(MonoColor.canvas)
            }
            .navigationTitle("Merge Editor")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
