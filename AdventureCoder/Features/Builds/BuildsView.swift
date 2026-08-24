import SwiftUI

/// Builds panel: shows GitHub Actions workflow runs for the current project.
public struct BuildsView: View {
    @StateObject private var workspace = WorkspaceState.shared
    @State private var runs: [BuildRun] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showGenerateWorkflow = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                SectionHeader("Builds")
                Spacer()
                if isLoading { ProgressView().scaleEffect(0.7) }
                Button(action: refresh) {
                    Image(systemName: MonoIcon.refresh)
                        .foregroundColor(MonoColor.tertiaryText)
                        .padding(.horizontal, MonoSpace.sm)
                }
                .buttonStyle(.plain)
                Button(action: { showGenerateWorkflow = true }) {
                    Label("Generate Workflow", systemImage: MonoIcon.bolt)
                        .font(MonoType.caption)
                        .foregroundColor(MonoColor.primaryText)
                }
                .buttonStyle(.bordered)
                .padding(.trailing, MonoSpace.md)
            }
            HairlineDivider()
            if let error = error {
                Text(error)
                    .font(MonoType.footnote)
                    .foregroundColor(MonoColor.error)
                    .padding()
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if runs.isEmpty && !isLoading {
                        Text("No builds yet. Generate the unsigned-IPA workflow and push to GitHub to trigger a build.")
                            .font(MonoType.footnote)
                            .foregroundColor(MonoColor.tertiaryText)
                            .padding()
                    }
                    ForEach(runs) { run in
                        BuildRow(run: run)
                        HairlineDivider()
                    }
                }
            }
        }
        .background(MonoColor.canvas)
        .sheet(isPresented: $showGenerateWorkflow) {
            WorkflowGeneratorSheet(isPresented: $showGenerateWorkflow)
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        guard let project = workspace.currentProject, let repo = project.githubRepo,
              let token = KeychainService.load(.githubToken) else {
            error = nil
            runs = []
            return
        }
        isLoading = true
        error = nil
        Task {
            do {
                let result = try await GitHubService.shared.listWorkflowRuns(repo: repo, token: token)
                await MainActor.run {
                    runs = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct BuildRow: View {
    let run: BuildRun

    var body: some View {
        HStack(spacing: MonoSpace.md) {
            Image(systemName: conclusionIcon)
                .foregroundColor(conclusionColor)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: MonoSpace.xs) {
                    Text("#\(run.number)")
                        .font(MonoType.body.weight(.semibold))
                        .foregroundColor(MonoColor.primaryText)
                    Text(run.branch)
                        .font(MonoType.caption)
                        .foregroundColor(MonoColor.tertiaryText)
                    if run.isUnsigned {
                        Text("Unsigned IPA")
                            .font(MonoType.caption2)
                            .padding(.horizontal, MonoSpace.xs)
                            .padding(.vertical, 1)
                            .background(MonoColor.cloud)
                            .clipShape(Capsule())
                            .foregroundColor(MonoColor.secondaryText)
                    }
                }
                Text(run.commitMessage)
                    .font(MonoType.caption)
                    .foregroundColor(MonoColor.secondaryText)
                    .lineLimit(1)
                HStack(spacing: MonoSpace.sm) {
                    Text(run.shortSha)
                        .font(MonoType.caption2)
                        .foregroundColor(MonoColor.tertiaryText)
                    Text(run.durationText)
                        .font(MonoType.caption2)
                        .foregroundColor(MonoColor.tertiaryText)
                    Text(run.startedAt.formatted(.relative(presentation: .named)))
                        .font(MonoType.caption2)
                        .foregroundColor(MonoColor.tertiaryText)
                }
            }
            Spacer()
            if let url = run.logsURL, let urlObj = URL(string: url) {
                Link(destination: urlObj) {
                    Image(systemName: MonoIcon.external)
                        .foregroundColor(MonoColor.tertiaryText)
                }
            }
        }
        .padding(.horizontal, MonoSpace.md)
        .padding(.vertical, MonoSpace.md)
    }

    private var conclusionIcon: String {
        switch run.conclusion {
        case .success: return MonoIcon.check
        case .failure: return MonoIcon.error
        case .cancelled: return MonoIcon.close
        case .timedOut: return MonoIcon.clock
        case .actionRequired: return MonoIcon.warning
        case .neutral: return MonoIcon.info
        case nil:
            switch run.status {
            case .inProgress: return MonoIcon.play
            case .queued: return MonoIcon.clock
            default: return MonoIcon.circle
            }
        }
    }

    private var conclusionColor: Color {
        switch run.conclusion {
        case .success: return MonoColor.success
        case .failure: return MonoColor.error
        case .cancelled, .timedOut, .actionRequired: return MonoColor.warning
        case .neutral: return MonoColor.tertiaryText
        case nil:
            switch run.status {
            case .inProgress: return MonoColor.warning
            case .queued, .pending, .waiting: return MonoColor.tertiaryText
            case .completed: return MonoColor.success
            }
        }
    }
}

struct WorkflowGeneratorSheet: View {
    @Binding var isPresented: Bool
    @State private var generated = false

    var body: some View {
        VStack(spacing: MonoSpace.md) {
            HStack {
                Text("Generate Unsigned IPA Workflow")
                    .font(MonoType.title2)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: MonoIcon.close)
                }
            }
            .padding()

            Text("This creates a real GitHub Actions workflow file at `.github/workflows/build-unsigned-ipa.yml` that:")
                .font(MonoType.body)
                .foregroundColor(MonoColor.secondaryText)
            VStack(alignment: .leading, spacing: MonoSpace.xs) {
                Label("Checks out the repository", systemImage: MonoIcon.check)
                Label("Sets up a macOS runner", systemImage: MonoIcon.check)
                Label("Installs XcodeGen and generates the Xcode project", systemImage: MonoIcon.check)
                Label("Builds without code signing (CODE_SIGNING_ALLOWED=NO)", systemImage: MonoIcon.check)
                Label("Packages an unsigned .ipa in a Payload directory", systemImage: MonoIcon.check)
                Label("Uploads the .ipa as a GitHub Actions artifact", systemImage: MonoIcon.check)
            }
            .font(MonoType.body)
            .foregroundColor(MonoColor.primaryText)
            .padding()

            if generated {
                StatusPill(.success, text: "Workflow generated. Commit and push to trigger a build.")
            }
            Spacer()
            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Generate") {
                    generate()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 560, height: 480)
        .background(MonoColor.canvas)
    }

    private func generate() {
        guard let project = WorkspaceState.shared.currentProject else { return }
        let workflowDir = (project.rootPath as NSString).appendingPathComponent(".github/workflows")
        try? FileManager.default.createDirectory(atPath: workflowDir, withIntermediateDirectories: true)
        let workflowPath = (workflowDir as NSString).appendingPathComponent("build-unsigned-ipa.yml")
        try? IPAWorkflowGenerator.workflowYAML.write(toFile: workflowPath, atomically: true, encoding: .utf8)
        generated = true
    }
}

/// Generator for the unsigned IPA build workflow YAML.
public enum IPAWorkflowGenerator {
    public static let workflowYAML: String = """
    name: Build Unsigned IPA

    on:
      push:
        branches: [main, master]
      pull_request:
        branches: [main, master]
      workflow_dispatch:

    jobs:
      build:
        name: Build Unsigned IPA
        runs-on: macos-14

        steps:
          - name: Checkout
            uses: actions/checkout@v4

          - name: Select Xcode
            run: sudo xcode-select -s /Applications/Xcode_15.4.app/Contents/Developer || true

          - name: Show Xcode version
            run: xcodebuild -version

          - name: Install XcodeGen
            run: brew install xcodegen

          - name: Generate Xcode project
            run: xcodegen generate

          - name: Resolve Swift package dependencies
            run: xcodebuild -resolvePackageDependencies -project AdventureCoder.xcodeproj -scheme AdventureCoder || true

          - name: Build (unsigned)
            run: |
              xcodebuild \\
                -project AdventureCoder.xcodeproj \\
                -scheme AdventureCoder \\
                -configuration Release \\
                -sdk iphoneos \\
                -destination 'generic/platform=iOS' \\
                CODE_SIGNING_ALLOWED=NO \\
                CODE_SIGNING_REQUIRED=NO \\
                CODE_SIGN_IDENTITY="" \\
                DEVELOPMENT_TEAM="" \\
                build

          - name: Locate built .app
            id: app
            run: |
              APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "AdventureCoder.app" -type d | head -n 1)
              echo "app_path=$APP_PATH" >> $GITHUB_OUTPUT
              echo "Found app at: $APP_PATH"

          - name: Package unsigned IPA
            run: |
              mkdir -p Payload
              cp -R "${{ steps.app.outputs.app_path }}" Payload/
              zip -r AdventureCoder-unsigned.ipa Payload
              ls -la AdventureCoder-unsigned.ipa

          - name: Upload IPA artifact
            uses: actions/upload-artifact@v4
            with:
              name: AdventureCoder-unsigned-ipa
              path: AdventureCoder-unsigned.ipa
              retention-days: 30

          - name: Summary
            run: |
              echo "## Unsigned IPA Build" >> $GITHUB_STEP_SUMMARY
              echo "" >> $GITHUB_STEP_SUMMARY
              echo "Built and packaged an **unsigned** IPA." >> $GITHUB_STEP_SUMMARY
              echo "" >> $GITHUB_STEP_SUMMARY
              echo "To install on a device, use a signing service or sideload with a tool like AltStore or Sideloadly." >> $GITHUB_STEP_SUMMARY
              echo "Adventure Coder never claims this build is signed." >> $GITHUB_STEP_SUMMARY
    """
}
