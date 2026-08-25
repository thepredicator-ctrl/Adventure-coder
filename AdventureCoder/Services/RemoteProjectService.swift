import Foundation

/// Manages remote projects: creates directories, initializes templates, detects project info.
public final class RemoteProjectService {
    public static let shared = RemoteProjectService()
    private init() {}

    private let ssh = SSHService.shared

    /// Create a new project on the remote PC.
    public func createProject(name: String, template: ProjectTemplate, in workspace: String) async throws -> String {
        let safeName = name.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        let projectPath = (workspace as NSString).appendingPathComponent(safeName)

        // Create project directory
        try await ssh.createDirectory(projectPath)

        // Install template files
        try await installTemplate(template, at: projectPath, name: safeName)

        return projectPath
    }

    /// List all projects in the workspace.
    public func listProjects(in workspace: String) async throws -> [RemoteProject] {
        let entries = try await ssh.listFiles(workspace)
        return entries
            .filter { $0.isDirectory }
            .map { entry in
                RemoteProject(name: entry.name, path: entry.path, modifiedAt: entry.modifiedAt)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Get project info (file count, git status, etc.)
    public func getProjectInfo(_ path: String) async throws -> RemoteProjectInfo {
        let entries = try await ssh.listFiles(path)
        let fileCount = entries.count

        // Check if it's a git repo
        let gitResult = try? await ssh.execute("cd '\(path.replacingOccurrences(of: "'", with: "'\\''"))' && git rev-parse --is-inside-work-tree 2>/dev/null || echo 'false'")
        let isGitRepo = gitResult?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "true"

        // Get current branch
        var branch = ""
        if isGitRepo {
            let branchResult = try? await ssh.execute("cd '\(path.replacingOccurrences(of: "'", with: "'\\''"))' && git branch --show-current 2>/dev/null")
            branch = branchResult?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        // Check for running preview server
        let hasPackageJson = entries.contains { $0.name == "package.json" }
        let hasCargoToml = entries.contains { $0.name == "Cargo.toml" }
        let hasSwiftPackage = entries.contains { $0.name == "Package.swift" }

        return RemoteProjectInfo(
            path: path,
            fileCount: fileCount,
            isGitRepo: isGitRepo,
            branch: branch,
            hasPackageJson: hasPackageJson,
            hasCargoToml: hasCargoToml,
            hasSwiftPackage: hasSwiftPackage
        )
    }

    /// Detect the project template from the files present.
    public func detectTemplate(at path: String) async -> ProjectTemplate {
        guard let entries = try? await ssh.listFiles(path) else { return .empty }
        let fileNames = Set(entries.map { $0.name.lowercased() })

        if fileNames.contains("package.json") {
            // Check for React/Vite
            if let packageContent = try? await ssh.readFile((path as NSString).appendingPathComponent("package.json")) {
                if packageContent.contains("\"react\"") { return .react }
                return .javascript
            }
            return .javascript
        }
        if fileNames.contains("cargo.toml") { return .rust }
        if fileNames.contains("package.swift") { return .swiftUI }
        if fileNames.contains("index.html") { return .html }
        if fileNames.contains("main.py") || fileNames.contains("requirements.txt") { return .python }
        if fileNames.contains("app.js") || fileNames.contains("index.js") { return .javascript }
        return .empty
    }

    // MARK: - Template installation

    private func installTemplate(_ template: ProjectTemplate, at path: String, name: String) async throws {
        let files = templateFiles(for: template, name: name)
        for (relativePath, content) in files {
            let fullPath = (path as NSString).appendingPathComponent(relativePath)
            // Create parent directory if needed
            let parent = (fullPath as NSString).deletingLastPathComponent
            try await ssh.createDirectory(parent)
            try await ssh.writeFile(fullPath, content: content)
        }
    }

    private func templateFiles(for template: ProjectTemplate, name: String) -> [(String, String)] {
        switch template {
        case .empty:
            return [("README.md", "# \(name)\n\nCreated with Adventure Coder.\n")]
        case .react:
            return [
                ("index.html", """
                <!doctype html>
                <html lang="en">
                  <head>
                    <meta charset="UTF-8" />
                    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
                    <title>\(name)</title>
                  </head>
                  <body>
                    <div id="root"></div>
                    <script type="module" src="/src/main.tsx"></script>
                  </body>
                </html>
                """),
                ("package.json", """
                {
                  "name": "\(name.lowercased())",
                  "version": "0.0.0",
                  "type": "module",
                  "scripts": {
                    "dev": "vite --host 0.0.0.0",
                    "build": "vite build",
                    "preview": "vite preview --host 0.0.0.0"
                  },
                  "dependencies": {
                    "react": "^18.3.1",
                    "react-dom": "^18.3.1"
                  },
                  "devDependencies": {
                    "@types/react": "^18.3.3",
                    "@types/react-dom": "^18.3.0",
                    "@vitejs/plugin-react": "^4.3.1",
                    "typescript": "^5.4.5",
                    "vite": "^5.3.1"
                  }
                }
                """),
                ("vite.config.ts", """
                import { defineConfig } from 'vite'
                import react from '@vitejs/plugin-react'

                export default defineConfig({
                  plugins: [react()],
                  server: { host: '0.0.0.0', port: 5173 }
                })
                """),
                ("tsconfig.json", """
                {
                  "compilerOptions": {
                    "target": "ES2020",
                    "useDefineForClassFields": true,
                    "lib": ["ES2020", "DOM", "DOM.Iterable"],
                    "module": "ESNext",
                    "skipLibCheck": true,
                    "moduleResolution": "bundler",
                    "jsx": "react-jsx",
                    "strict": true
                  },
                  "include": ["src"]
                }
                """),
                ("src/main.tsx", """
                import React from 'react'
                import ReactDOM from 'react-dom/client'
                import App from './App'
                import './styles.css'

                ReactDOM.createRoot(document.getElementById('root')!).render(<App />)
                """),
                ("src/App.tsx", """
                export default function App() {
                  return (
                    <main style={{ fontFamily: 'system-ui', padding: 24, color: '#111' }}>
                      <h1>\(name)</h1>
                      <p>Built with Adventure Coder on a remote PC.</p>
                    </main>
                  )
                }
                """),
                ("src/styles.css", """
                :root { color-scheme: light; }
                body { margin: 0; font-family: system-ui, sans-serif; }
                """)
            ]
        case .web, .html:
            return [
                ("index.html", """
                <!doctype html>
                <html lang="en">
                  <head>
                    <meta charset="UTF-8" />
                    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
                    <title>\(name)</title>
                    <link rel="stylesheet" href="styles.css" />
                  </head>
                  <body>
                    <main>
                      <h1>\(name)</h1>
                      <p>Built with Adventure Coder on a remote PC.</p>
                    </main>
                    <script src="script.js"></script>
                  </body>
                </html>
                """),
                ("styles.css", """
                :root { color-scheme: light; --fg: #111; --bg: #fff; }
                body { margin: 0; font-family: system-ui; color: var(--fg); background: var(--bg); }
                main { max-width: 720px; margin: 0 auto; padding: 48px 24px; }
                """),
                ("script.js", "console.log('\(name) ready');")
            ]
        case .javascript:
            return [
                ("package.json", """
                {"name":"\(name.lowercased())","version":"1.0.0","type":"module","main":"index.js","scripts":{"start":"node index.js"}}
                """),
                ("index.js", "console.log('\(name) ready');")
            ]
        case .python:
            return [
                ("requirements.txt", ""),
                ("main.py", """
                def main():
                    print("\(name) ready")

                if __name__ == "__main__":
                    main()
                """)
            ]
        case .rust:
            return [
                ("Cargo.toml", """
                [package]
                name = "\(name.lowercased())"
                version = "0.1.0"
                edition = "2021"

                [dependencies]
                """),
                ("src/main.rs", """
                fn main() {
                    println!("\(name ready");
                }
                """)
            ]
        case .swiftUI, .iosApp:
            return [
                ("README.md", "# \(name)\n\nSwiftUI project. Use GitHub Actions for iOS builds."),
                ("Package.swift", """
                // swift-tools-version: 5.9
                import PackageDescription

                let package = Package(
                    name: "\(name)",
                    platforms: [.iOS(.v17)],
                    products: [.library(name: "\(name)", targets: ["\(name)"])],
                    targets: [.target(name: "\(name)", path: "Sources")]
                )
                """),
                ("Sources/\(name)/\(name)App.swift", """
                import SwiftUI

                @main
                struct \(name.pascalCase)App: App {
                    var body: some Scene {
                        WindowGroup {
                            ContentView()
                        }
                    }
                }

                struct ContentView: View {
                    var body: some View {
                        VStack {
                            Text("\(name)")
                                .font(.title)
                            Text("Built with Adventure Coder")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                """)
            ]
        }
    }
}

// MARK: - Models

public struct RemoteProject: Identifiable, Hashable {
    public var id: String { path }
    public var name: String
    public var path: String
    public var modifiedAt: Date
}

public struct RemoteProjectInfo: Hashable {
    public var path: String
    public var fileCount: Int
    public var isGitRepo: Bool
    public var branch: String
    public var hasPackageJson: Bool
    public var hasCargoToml: Bool
    public var hasSwiftPackage: Bool
}

private extension String {
    var pascalCase: String {
        let parts = split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        return parts.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined()
    }
}
