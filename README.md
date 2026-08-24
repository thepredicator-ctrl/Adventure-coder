# Adventure Coder

A minimalist, monochrome, native iOS + iPadOS AI coding IDE with a 70-agent orchestration system that gives even small, free AI models powerful tools — web search, documentation lookup, GitHub, terminal, code analysis, builds, previews, and automated debugging.

> Built specifically for iPhone and iPad. The iPad is a first-class citizen with a desktop-class workspace (sidebar / editor / AI / terminal), and the iPhone uses a focused tabbed layout.

---

## Highlights

- **Strict monochrome design system** — black / white / grays only, with color reserved for state (success / warning / error / active).
- **iPad-first workspace** — resizable sidebar, editor, AI chat, and bottom panel. Supports Stage Manager, Split View, external keyboards, trackpad, and Apple Pencil.
- **iPhone layout** — Projects / Code / AI / Preview / Builds / Settings tabs.
- **AI providers** — OpenRouter and Hugging Face, with a provider abstraction for adding more.
- **Free models by default** — `Free models only` is ON, `Allow paid models` is OFF. The ranker picks the best free model for each task.
- **70 specialized agents** — planning, coding, code understanding, debugging, research, development tools, product/UI, and deployment.
- **Real tool system** — `read_file`, `write_file`, `edit_file`, `search_files`, `git_*`, `github_*`, `web_search`, `fetch_url`, `search_documentation`, `run_command`, `build_project`, `run_tests`, `analyze_logs`, `generate_diff`, `preview_project`.
- **Sandboxed terminal** — real, working whitelisted commands (ls, cat, grep, find, tree, head, tail, wc, echo, env, …) running inside the iOS sandbox.
- **Live preview** — `WKWebView` rendering for HTML / CSS / JS / React projects; clear "use GitHub Actions" message for native iOS previews.
- **Diff system** — every AI modification produces a real, accept/reject/revert-able unified diff.
- **Git + GitHub** — init, status, diff, commit, branches, checkout, history, push, pull, workflow status, unsigned-IPA workflow generation.
- **Keychain security** — API keys never leave the device except to their provider over HTTPS.
- **Secret detection** — warns before writing or committing content that looks like an API key, token, or private key.
- **Command palette (⌘K)** — files, build, tests, terminal, git, preview, model switch, agent switch, settings.
- **Global search** — files, conversations, agents, and commands in one place.

---

## Project structure

```
adventure-coder/
├── project.yml                       # XcodeGen project spec
├── .github/workflows/
│   └── build-unsigned-ipa.yml        # macOS runner that builds & packages the unsigned IPA
├── AdventureCoder/
│   ├── App/
│   │   └── AdventureCoderApp.swift   # @main, AppDelegate, SceneDelegate, RootView
│   ├── Resources/
│   │   ├── Info.plist
│   │   ├── AdventureCoder.entitlements
│   │   └── Assets.xcassets/
│   ├── DesignSystem/                 # MonoColor, MonoType, MonoSpace, MonoComponents, MonoIcon
│   ├── Models/                       # Project, FileNode, Conversation, AIModel, Agent, Tool, Diff, Build
│   ├── Services/                     # Keychain, FileSystem, GitService, GitHubService, BuildService, PreviewService, TerminalEngine, Logger, SecretDetector, SettingsStore, ProjectStore, TemplateInstaller
│   ├── Providers/                    # AIProvider, OpenRouterProvider, HuggingFaceProvider, ProviderRegistry, ModelRanker, ModelRouter
│   ├── Tools/                        # Tool protocol + 28 concrete tools
│   ├── Agents/
│   │   ├── AgentRegistry.swift
│   │   ├── AgentOrchestrator.swift
│   │   ├── ContextManager.swift
│   │   └── Definitions/
│   │       ├── PlanningAgents.swift        (8 agents)
│   │       ├── CodingAgents.swift          (12 agents)
│   │       ├── UnderstandingAgents.swift   (10 agents)
│   │       ├── DebuggingAgents.swift       (8 agents)
│   │       ├── ResearchAgents.swift        (10 agents)
│   │       ├── DevToolAgents.swift         (8 agents)
│   │       ├── ProductAgents.swift         (8 agents)
│   │       └── DeploymentAgents.swift      (6 agents)
│   ├── Features/
│   │   ├── Workspace/                # WorkspaceView, SidebarView, FileExplorerView, BottomPanelView, WorkspaceState
│   │   ├── Editor/                   # CodeEditorView, SyntaxHighlighter, EditorComponents
│   │   ├── AIChat/                   # AIChatView, ChatMessageView, ChatInputView
│   │   ├── Terminal/                 # TerminalView
│   │   ├── Preview/                  # PreviewView (WKWebView-backed)
│   │   ├── Diff/                     # DiffView
│   │   ├── Builds/                   # BuildsView, WorkflowGeneratorSheet, IPAWorkflowGenerator
│   │   ├── Settings/                 # SettingsView (account/providers/models/agents/github/editor/appearance)
│   │   ├── Projects/                 # ProjectsListView, NewProjectView, AgentsListView
│   │   └── CommandPalette/          # CommandPaletteView, GlobalSearchView
│   ├── Navigation/                   # AdaptiveLayout, iPhoneLayout
│   └── Utilities/                    # (extensions)
└── AdventureCoderTests/              # 14 test files covering all major subsystems
```

---

## Building the app

Adventure Coder uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the `AdventureCoder.xcodeproj` is generated from `project.yml`. The GitHub Actions workflow does this automatically on every push.

### Local build

```bash
brew install xcodegen
cd adventure-coder
xcodegen generate
open AdventureCoder.xcodeproj
```

Then choose an iOS Simulator (iPad Pro 13" recommended) and run.

### Remote build (unsigned IPA)

The repository includes a GitHub Actions workflow at `.github/workflows/build-unsigned-ipa.yml` that:

1. Checks out the repository on a `macos-14` runner.
2. Installs XcodeGen and generates the Xcode project.
3. Resolves Swift Package dependencies.
4. Builds with `CODE_SIGNING_ALLOWED=NO` (no signing credentials required).
5. Locates the built `AdventureCoder.app` in DerivedData.
6. Packages it into an unsigned `AdventureCoder-unsigned.ipa` using a `Payload/` directory.
7. Uploads the IPA as a GitHub Actions artifact (30-day retention).
8. Optionally runs the test suite on the iPad Simulator.

To trigger a build, push to `main` or run the workflow manually from the Actions tab. The unsigned IPA can be sideloaded with tools like AltStore or Sideloadly.

> Adventure Coder never claims the build is signed. The IPA is explicitly named `AdventureCoder-unsigned.ipa` and labeled "Unsigned IPA" in the UI.

---

## Setting up AI providers

1. Open **Settings → AI Providers → OpenRouter**.
2. Paste your OpenRouter API key (get one at <https://openrouter.ai/keys>). It is stored in the iOS Keychain and only sent to OpenRouter over HTTPS.
3. Tap **Test** to verify the key and discover available models.
4. Repeat for Hugging Face if desired (token at <https://huggingface.co/settings/tokens>).

By default:
- **Free models only** is ON.
- **Allow paid models** is OFF.
- The first time you open the model picker, Adventure Coder fetches the catalog from your configured providers and ranks free models by coding ability, tool-use support, context length, and reliability.

---

## The 70-agent system

Each agent has:
- A specific role
- System instructions
- Tool permissions
- Input/output schemas
- Context requirements
- Handoff rules
- A default model preference

### Categories

| Category | Count | Examples |
|---|---|---|
| Planning | 8 | Project Planner, Requirements Analyst, Architecture Planner, Task Decomposer, Risk Analyzer |
| Coding | 12 | Swift Coder, SwiftUI Coder, TypeScript Coder, React Coder, Python Coder, Rust Coder |
| Code Understanding | 10 | Code Reviewer, Refactoring Agent, Static Analysis Agent, Security Analyzer, Architecture Reviewer |
| Debugging | 8 | Build Error Agent, Runtime Error Agent, Crash Analyzer, Test Failure Agent, Fix Verification Agent |
| Research | 10 | Web Search Agent, Documentation Search Agent, GitHub Search Agent, Image Search Agent, Project Explorer Agent |
| Development Tools | 8 | Terminal Agent, Git Agent, GitHub Agent, Build Agent, Test Agent, Package Manager Agent |
| Product / UI | 8 | UI Designer Agent, Accessibility Agent, iPad Optimization Agent, iPhone Optimization Agent, Preview Agent |
| Deployment | 6 | CI Agent, GitHub Actions Agent, iOS Build Agent, IPA Packaging Agent, Release Verification Agent |

**Total: 70 agents.**

### Orchestration flow

```
User
  ↓
Main AI (model router picks model based on task)
  ↓
Project Planner
  ↓
Task Decomposer
  ↓
Specialized agents (in parallel where allowed)
  ↓
Tools (file ops, search, web, git, github, terminal, build)
  ↓
Reviewer agents
  ↓
Main AI (summary)
  ↓
User
```

### Context management

Each agent receives only what it needs:
- The orchestrator passes the user request + a structural summary of the project.
- The `ContextManager` walks the file tree, scores relevance, and attaches only the relevant snippets.
- Conversation history is summarized to fit within small free-model context windows.

---

## Tool catalog

28 tools are implemented and registered in `ToolRegistry`:

- **File**: `read_file`, `write_file`, `edit_file`, `delete_file`, `list_files`, `generate_diff`
- **Search**: `search_files`, `search_project`
- **Web**: `web_search`, `fetch_url`, `search_documentation`, `search_images`
- **Git**: `git_status`, `git_diff`, `git_commit`, `git_push`, `git_pull`, `git_branches`, `git_checkout`, `git_history`
- **GitHub**: `github_search`, `github_repos`, `github_actions_status`
- **Terminal**: `run_command`
- **Build/Test**: `build_project`, `run_tests`, `analyze_logs`, `preview_project`

Destructive operations (`write_file`, `delete_file`, `git_commit`, `git_push`, `run_command`) require explicit user confirmation.

---

## Security

- **Keychain storage** for all API keys and tokens (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
- **HTTPS only** for all provider and GitHub API calls.
- **Secret detection** before writing files or committing — refuses to commit content that looks like an API key, token, JWT, or private key.
- **Sandboxed terminal** — only a whitelist of safe, in-process commands is allowed.
- **Masked display** — saved keys are shown as `sk-or-v1-••••••••3f7a`, never in full.
- **No third-party analytics** — the app talks only to OpenRouter, Hugging Face, GitHub, and DuckDuckGo (for web search).

---

## Tests

14 test files covering:

- `KeychainServiceTests` — save / load / delete / overwrite / masked display.
- `ProviderTests` — registry, keychain keys, fallback models, score estimator.
- `ModelRankerTests` — free-only filter, paid-allowed, picking per preference, composite score.
- `AgentTests` — ≥70 agents, unique IDs, non-empty instructions, all categories present.
- `ToolTests` — all 28 tools registered, file read/write/list, generate_diff.
- `DiffTests` — identical content, added/removed lines, unified format.
- `FileSystemTests` — write/read/list/search/delete/rename/duplicate/relative path.
- `SecretDetectorTests` — GitHub PAT, OpenAI key, AWS key, private key, hardcoded password, no false positives.
- `GitServiceTests` — init, status, commit, history, branches, diff.
- `ProjectStoreTests` — create/delete, template files (SwiftUI, HTML, React, Python, Rust), conversations.
- `TerminalEngineTests` — allowed/disallowed commands, echo, pwd, cat.
- `LogAnalyzerTests` — error detection, hint generation, empty logs.
- `EditExtractorTests` — extract create/replace blocks from LLM responses.
- `SwiftSyntaxCheckerTests` — balanced/unbalanced braces, strings, comments.
- `TemplateInstallerTests` — every template installs the expected files.

Run tests locally:

```bash
xcodegen generate
xcodebuild test \
  -project AdventureCoder.xcodeproj \
  -scheme AdventureCoder \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)'
```

---

## Keyboard shortcuts (iPad with external keyboard)

| Shortcut | Action |
|---|---|
| ⌘K | Command palette |
| ⌘F | Global search |
| ⌘N | New project |
| ⌘S | Save current file |
| ⌘B | Run build |

---

## Design language

- **Backgrounds**: `#FFFFFF`, `#F9F9FB`, `#F3F3F6`
- **Text**: `#111111`, `#37373C`, `#6B6B72`, `#9C9CA3`
- **Borders**: `#E5E5EA`, `#D1D1D6`
- **State colors** (used only to communicate state):
  - Success: muted green
  - Warning: muted amber
  - Error: muted red
  - Active: muted blue (for selection only)
- **Typography**: Apple system font for UI, SF Mono for code.
- **No neon, no gradients, no excessive cards.** Whitespace and hairline borders carry the design.

---

## License

MIT — see `LICENSE`.
