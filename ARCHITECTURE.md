# Architecture

This document describes the high-level architecture of Adventure Coder.

## Layered overview

```
┌──────────────────────────────────────────────────────────────┐
│                          UI layer                              │
│  SwiftUI views (Workspace, Sidebar, Editor, Chat, Terminal,   │
│  Preview, Diff, Builds, Settings, Projects, Agents,           │
│  CommandPalette, GlobalSearch)                                 │
├──────────────────────────────────────────────────────────────┤
│                  Adaptive navigation                           │
│  AdaptiveLayout → WorkspaceView (iPad) / iPhoneLayout          │
├──────────────────────────────────────────────────────────────┤
│                    State / orchestration                       │
│  WorkspaceState  ·  AgentOrchestrator  ·  ContextManager       │
├──────────────────────────────────────────────────────────────┤
│                          Services                              │
│  KeychainService · FileSystem · GitService · GitHubService     │
│  BuildService · PreviewService · TerminalEngine · Logger       │
│  SecretDetector · SettingsStore · ProjectStore                 │
│  TemplateInstaller                                             │
├──────────────────────────────────────────────────────────────┤
│                    Providers + Tools + Agents                  │
│  AIProvider · OpenRouter · HuggingFace · ModelRanker · Router  │
│  ToolRegistry · 28 concrete tools                              │
│  AgentRegistry · 70 specialized agents                         │
├──────────────────────────────────────────────────────────────┤
│                          Models                                │
│  Project · FileNode · Conversation · ChatMessage · AIModel     │
│  AgentDefinition · ToolDefinition · FileDiff · BuildRun        │
├──────────────────────────────────────────────────────────────┤
│                       Design system                            │
│  MonoColor · MonoType · MonoSpace · MonoComponents · MonoIcon  │
└──────────────────────────────────────────────────────────────┘
```

## Key flows

### User → AI → Code → Build

1. The user types a request in the AI chat.
2. `AgentOrchestrator.runRequest` is invoked.
3. The orchestrator calls `ModelRouter.route(forTaskDescription:)` to pick a model preference (e.g. `.codingFree`, `.planningFree`).
4. `ModelRouter.resolve(preference:)` returns the resolved `(AIModel, AIProvider)` pair, honoring the user's free-only / paid-allowed settings.
5. The orchestrator runs the **Project Planner** agent to produce a plan.
6. It picks a **coding agent** based on the project's primary language (SwiftUI Coder for Swift, TypeScript Coder for React, etc.).
7. The coding agent produces a response that includes fenced code blocks with `path=` annotations or `EDIT path=… FIND: … REPLACE: …` blocks.
8. `EditExtractor` parses the response and extracts structured edits.
9. Each edit is applied via `FileSystem`, and a real `FileDiff` is generated using the LCS-based `DiffAlgorithm`.
10. The **Build Agent** runs `BuildService.build`, which for Swift projects runs `SwiftSyntaxChecker` and for web projects reports npm-build unavailability.
11. If the build fails and auto-repair is enabled, the **Build Error Agent** is invoked with the error logs and applies fixes.
12. The orchestrator posts a summary back to the conversation, including the list of diffs.

### Streaming chat (simple Q&A)

When the user asks a question that doesn't look like a build request (no "build/create/fix" keywords), `AgentOrchestrator.streamSimpleChat` is used. It calls `provider.streamChat` and forwards deltas to the UI in real time.

### Free-model discovery

1. `CachedModelStore.refresh()` iterates over `ProviderRegistry.providers`.
2. For each configured provider, it calls `provider.discoverModels()`.
3. OpenRouter models come from `/api/v1/models` and include pricing fields; Hugging Face models come from `/api/models?filter=text-generation-inference`.
4. Models are decorated with `codingScore`, `toolUseScore`, `reliabilityScore` (heuristics in `ScoreEstimator`).
5. `ModelRanker.availableModels(from:)` filters based on `freeModelsOnly` / `allowPaidModels`.
6. `ModelRanker.pick(for:from:)` selects the best model for each preference slot.

### Git operations

Adventure Coder implements a small, file-system-backed "mini-git" inside the project's `.adventure/git/` directory:

- HEAD pointer in `HEAD`
- Branch refs in `refs/<branch>`
- Object store in `objects/<hash>`
- Snapshot of the last commit in `snapshot.json`
- Commit log in `log.json`

This is **not** a complete reimplementation of Git. It supports the operations the app actually needs (init, status, diff, commit, branches, checkout, history) without shelling out to a `git` binary that isn't available on iOS. When the user pushes, the contents API of GitHub is used to upload each file to the remote repo, so the resulting GitHub repository is a standard Git repo.

### Unsigned IPA build

The workflow at `.github/workflows/build-unsigned-ipa.yml` is the source of truth for the build process. The in-app `WorkflowGeneratorSheet` writes the same YAML into the project's `.github/workflows/` directory, so when the user pushes the project to their own GitHub repo, GitHub Actions builds the unsigned IPA.

The workflow:
1. Checks out the repo on `macos-14`.
2. Installs XcodeGen via Homebrew.
3. Generates the Xcode project from `project.yml`.
4. Builds with `xcodebuild -configuration Release -sdk iphoneos CODE_SIGNING_ALLOWED=NO …`.
5. Locates the built `.app` in DerivedData.
6. Creates a `Payload/` directory, copies the `.app` into it, and zips it as `AdventureCoder-unsigned.ipa`.
7. Uploads the IPA as a GitHub Actions artifact with 30-day retention.

The app surfaces the workflow run status in the Builds panel via `GitHubService.listWorkflowRuns`.

### Sandbox limitations (honestly disclosed)

- **No `git` binary on iOS** → Adventure Coder ships its own file-system-backed mini-git for local operations and uses the GitHub REST API for remote sync.
- **No `xcodebuild` on iOS** → local builds use `SwiftSyntaxChecker` (heuristic, not a full compiler). Full builds run via GitHub Actions on macOS.
- **No `npm`/`node` on iOS** → web previews render via `WKWebView` reading the project's `index.html` directly. Full builds run via GitHub Actions.
- **No shell process spawning on iOS** → `TerminalEngine` implements a fixed whitelist of in-process commands. Anything outside the whitelist is denied with a clear message.
- **No native SwiftUI preview rendering on device for sandboxed apps** → the Preview pane shows a clear "use GitHub Actions" message for native iOS projects and a live `WKWebView` for web projects.

The app never pretends a capability works when it doesn't. Every limitation is disclosed in the UI.

## Adding a new agent

1. Pick the appropriate file under `AdventureCoder/Agents/Definitions/`.
2. Add a new `static let` with a unique `agentId` (e.g. `"coding.kotlin"`).
3. Append it to the `all` array.
4. The agent is now discoverable via `AgentRegistry.shared` and visible in the Agents list, command palette, and global search.

## Adding a new tool

1. Add a `ToolDefinition` entry to `ToolCatalog.all` in `Models/ToolDefinition.swift`.
2. Create a new `struct` conforming to `Tool` under `AdventureCoder/Tools/`.
3. Register an instance in `ToolRegistry.shared`.
4. Reference the tool name in any agent's `toolPermissions` array.

## Adding a new AI provider

1. Create a new type conforming to `AIProvider` under `AdventureCoder/Providers/`.
2. Add it to `ProviderRegistry.providers`.
3. Add a new `KeychainService.Key` case if the provider requires a key.
4. The model discovery, free-model ranking, and model router automatically pick it up.

## Tests

14 test files (15 test classes) exercise every major subsystem:

- `KeychainServiceTests`
- `ProviderTests`
- `ModelRankerTests`
- `AgentTests`
- `ToolTests`
- `DiffTests`
- `FileSystemTests`
- `SecretDetectorTests`
- `GitServiceTests`
- `ProjectStoreTests`
- `TerminalEngineTests`
- `LogAnalyzerTests`
- `EditExtractorTests`
- `SwiftSyntaxCheckerTests`
- `TemplateInstallerTests`

The GitHub Actions workflow attempts to run them on an iPad Simulator after the IPA build step.
