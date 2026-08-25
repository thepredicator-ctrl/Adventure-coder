import SwiftUI

/// Remote project dashboard: shows project status, preview URL, file count, git branch.
public struct RemoteDashboardView: View {
    @StateObject private var store = RemotePCStore.shared
    @StateObject private var previewService = RemotePreviewService.shared
    @StateObject private var workspace = WorkspaceState.shared
    @State private var projectInfo: RemoteProjectInfo?
    @State private var isLoading = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MonoSpace.lg) {
                if let project = workspace.currentRemoteProject {
                    // Project header
                    VStack(alignment: .leading, spacing: MonoSpace.sm) {
                        Text(project.name)
                            .font(MonoType.title)
                            .foregroundColor(MonoColor.primaryText)

                        statusRow(label: "Location", value: project.path)
                        statusRow(label: "Status", value: previewService.activePreview != nil ? "● Running" : "○ Idle")
                        if let preview = previewService.activePreview {
                            statusRow(label: "Preview", value: preview.url)
                        }
                        if let info = projectInfo {
                            statusRow(label: "Last Build", value: "—")
                            statusRow(label: "Files", value: "\(info.fileCount)")
                            statusRow(label: "Git", value: info.branch.isEmpty ? "Not a git repo" : info.branch)
                        }
                    }
                    .padding(MonoSpace.md)
                    .background(MonoColor.panel)
                    .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))

                    // Actions
                    HStack(spacing: MonoSpace.sm) {
                        if previewService.activePreview != nil {
                            MonoComponents.SecondaryButton("Stop Preview") {
                                Task { await previewService.stopPreview() }
                            }
                        } else {
                            MonoComponents.PrimaryButton("Start Preview") {
                                Task {
                                    await previewService.startPreview(
                                        projectPath: project.path,
                                        template: workspace.currentRemoteProjectTemplate ?? .web
                                    )
                                }
                            }
                        }
                    }

                    // Download options
                    VStack(alignment: .leading, spacing: MonoSpace.sm) {
                        SectionHeader("Source Code")
                        Button(action: downloadSource) {
                            Label("Download Source (ZIP)", systemImage: MonoIcon.download)
                                .font(MonoType.body)
                                .foregroundColor(MonoColor.primaryText)
                        }
                        .buttonStyle(.plain)
                        Button(action: downloadBuild) {
                            Label("Download Build Artifacts", systemImage: MonoIcon.build)
                                .font(MonoType.body)
                                .foregroundColor(MonoColor.primaryText)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(MonoSpace.md)
                    .background(MonoColor.panel)
                    .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))

                    // Upload
                    VStack(alignment: .leading, spacing: MonoSpace.sm) {
                        SectionHeader("Upload")
                        Button(action: uploadProject) {
                            Label("Upload Project (ZIP)", systemImage: MonoIcon.upload)
                                .font(MonoType.body)
                                .foregroundColor(MonoColor.primaryText)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(MonoSpace.md)
                    .background(MonoColor.panel)
                    .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))
                } else if store.isConnected {
                    EmptyState(
                        title: "No remote project selected",
                        message: "Create a new project or select one from the sidebar.",
                        systemImage: MonoIcon.folder
                    )
                } else {
                    EmptyState(
                        title: "Not connected",
                        message: "Connect to a remote PC to view the dashboard.",
                        systemImage: "pc"
                    )
                }
            }
            .padding(MonoSpace.md)
        }
        .background(MonoColor.canvas)
        .onAppear(perform: loadProjectInfo)
        .onChange(of: workspace.currentRemoteProject?.path) { _ in loadProjectInfo() }
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(MonoType.caption)
                .foregroundColor(MonoColor.tertiaryText)
            Spacer()
            Text(value)
                .font(MonoType.caption)
                .foregroundColor(MonoColor.primaryText)
                .lineLimit(1)
        }
    }

    private func loadProjectInfo() {
        guard let project = workspace.currentRemoteProject else {
            projectInfo = nil
            return
        }
        isLoading = true
        Task {
            do {
                projectInfo = try await RemoteProjectService.shared.getProjectInfo(project.path)
            } catch {
                projectInfo = nil
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func downloadSource() {
        guard let project = workspace.currentRemoteProject else { return }
        Task {
            do {
                let zipURL = try await RemoteDownloadService.shared.downloadProjectSource(at: project.path)
                _ = RemoteDownloadService.shared.saveToFilesApp(zipURL)
            } catch {
                // Show error
            }
        }
    }

    private func downloadBuild() {
        guard let project = workspace.currentRemoteProject else { return }
        Task {
            do {
                if let zipURL = try await RemoteDownloadService.shared.downloadBuildArtifacts(at: project.path, projectName: project.name) {
                    _ = RemoteDownloadService.shared.saveToFilesApp(zipURL)
                }
            } catch {
                // Show error
            }
        }
    }

    private func uploadProject() {
        // This would present a document picker
        // For now, the upload is accessible via the file importer
    }
}
