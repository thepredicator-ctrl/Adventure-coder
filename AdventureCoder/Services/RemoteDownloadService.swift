import Foundation
import UIKit

/// Downloads and uploads project source code as ZIP files.
public final class RemoteDownloadService {
    public static let shared = RemoteDownloadService()
    private init() {}

    private let ssh = SSHService.shared

    // MARK: - Download

    /// Create a ZIP of the project on the remote PC, then download it.
    public func downloadProjectSource(at remotePath: String) async throws -> URL {
        let projectName = (remotePath as NSString).lastPathComponent
        let tempDir = FileManager.default.temporaryDirectory
        let localZip = tempDir.appendingPathComponent("\(projectName).zip")

        // Create ZIP on remote PC
        let parent = (remotePath as NSString).deletingLastPathComponent
        let escapedParent = parent.replacingOccurrences(of: "'", with: "'\\''")
        let escapedName = projectName.replacingOccurrences(of: "'", with: "'\\''")

        // Try PowerShell Compress-Archive first, then zip command
        let psCommand = "powershell -Command \"Compress-Archive -Path '\(escapedParent)\\\(escapedName)' -DestinationPath '\(escapedParent)\\\(escapedName).zip' -Force\" 2>nul"
        let zipCommand = "cd '\(escapedParent)' && zip -r '\(escapedName).zip' '\(escapedName)' 2>/dev/null"

        _ = try await ssh.execute("\(psCommand) ; if [ ! -f '\(escapedParent)/\(escapedName).zip' ]; then \(zipCommand); fi")

        // Read the ZIP file content via base64
        let zipPath = (parent as NSString).appendingPathComponent("\(projectName).zip")
        let result = try await ssh.execute("base64 '\(zipPath.replacingOccurrences(of: "'", with: "'\\''"))' 2>/dev/null || powershell -Command \"[Convert]::ToBase64String([IO.File]::ReadAllBytes('\(zipPath.replacingOccurrences(of: "'", with: "'\\''"))'))\"")

        guard !result.stdout.isEmpty else {
            throw SSHService.SSHError.unknown("Failed to read ZIP file from remote PC")
        }

        // Clean up the base64 string (remove newlines)
        let cleaned = result.stdout.components(separatedBy: .newlines).joined()
        guard let zipData = Data(base64Encoded: cleaned) else {
            throw SSHService.SSHError.unknown("Failed to decode ZIP data")
        }

        try zipData.write(to: localZip)

        // Clean up remote ZIP
        _ = try? await ssh.execute("rm -f '\(zipPath.replacingOccurrences(of: "'", with: "'\\''"))' 2>/dev/null; powershell -Command \"Remove-Item '\(zipPath.replacingOccurrences(of: "'", with: "'\\''"))' -ErrorAction SilentlyContinue\" 2>nul")

        return localZip
    }

    /// Download specific files/folders as a ZIP.
    public func downloadSelectedFiles(_ paths: [String], projectName: String) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let localZip = tempDir.appendingPathComponent("\(projectName)-selection.zip")

        // Create a temp directory on remote, copy selected files, zip it
        let remoteTemp = "/tmp/adventure_coder_download_\(UUID().uuidString)"
        try await ssh.createDirectory(remoteTemp)

        for path in paths {
            let name = (path as NSString).lastPathComponent
            let dest = (remoteTemp as NSString).appendingPathComponent(name)
            try? await ssh.copyPath(from: path, to: dest)
        }

        // Zip the temp directory
        let escapedTemp = remoteTemp.replacingOccurrences(of: "'", with: "'\\''")
        let zipPath = "/tmp/\(projectName)-selection.zip"
        let escapedZip = zipPath.replacingOccurrences(of: "'", with: "'\\''")
        _ = try await ssh.execute("cd '\(escapedTemp)' && zip -r '\(escapedZip)' . 2>/dev/null || powershell -Command \"Compress-Archive -Path '\(escapedTemp)\\*' -DestinationPath '\(escapedZip)' -Force\"")

        // Read and save
        let result = try await ssh.execute("base64 '\(escapedZip)' 2>/dev/null || powershell -Command \"[Convert]::ToBase64String([IO.File]::ReadAllBytes('\(escapedZip)'))\"")
        let cleaned = result.stdout.components(separatedBy: .newlines).joined()
        guard let zipData = Data(base64Encoded: cleaned) else {
            throw SSHService.SSHError.unknown("Failed to decode ZIP data")
        }
        try zipData.write(to: localZip)

        // Cleanup
        _ = try? await ssh.deletePath(remoteTemp)
        _ = try? await ssh.deletePath(zipPath)

        return localZip
    }

    /// Download build artifacts (dist/, build/, target/, etc.)
    public func downloadBuildArtifacts(at projectPath: String, projectName: String) async throws -> URL? {
        let buildDirs = ["dist", "build", "target/release", "target/debug", ".next", "out"]
        for dir in buildDirs {
            let buildPath = (projectPath as NSString).appendingPathComponent(dir)
            let entries = try? await ssh.listFiles(buildPath)
            if let entries = entries, !entries.isEmpty {
                return try await downloadProjectSource(at: buildPath)
            }
        }
        return nil
    }

    // MARK: - Upload

    /// Upload a ZIP file to the remote PC and extract it.
    public func uploadProject(zipURL: URL, to workspace: String) async throws -> String {
        let projectName = zipURL.deletingPathExtension().lastPathComponent
        let projectPath = (workspace as NSString).appendingPathComponent(projectName)

        // Read the ZIP data
        let zipData = try Data(contentsOf: zipURL)
        let base64 = zipData.base64EncodedString()

        // Create project directory
        try await ssh.createDirectory(projectPath)

        // Upload the ZIP as base64 and decode on remote
        let remoteZipPath = (workspace as NSString).appendingPathComponent("\(projectName).zip")
        let escapedZip = remoteZipPath.replacingOccurrences(of: "'", with: "'\\''")
        let escapedProject = projectPath.replacingOccurrences(of: "'", with: "'\\''")

        // Write base64 to a temp file, then decode
        let escapedTemp = "/tmp/upload_\(UUID().uuidString).b64"
        // Split base64 into chunks to avoid command line length limits
        let chunkSize = 50000
        var offset = 0
        while offset < base64.count {
            let end = min(offset + chunkSize, base64.count)
            let chunk = String(base64[base64.index(base64.startIndex, offsetBy: offset)..<base64.index(base64.startIndex, offsetBy: end)])
            if offset == 0 {
                _ = try await ssh.execute("echo -n '\(chunk)' > '\(escapedTemp)' 2>/dev/null || powershell -Command \"Set-Content -Path '\(escapedTemp)' -Value '\(chunk)' -NoNewline\"")
            } else {
                _ = try await ssh.execute("echo -n '\(chunk)' >> '\(escapedTemp)' 2>/dev/null || powershell -Command \"Add-Content -Path '\(escapedTemp)' -Value '\(chunk)' -NoNewline\"")
            }
            offset = end
        }

        // Decode base64 to ZIP
        _ = try await ssh.execute("base64 -d '\(escapedTemp)' > '\(escapedZip)' 2>/dev/null || powershell -Command \"[IO.File]::WriteAllBytes('\(escapedZip)', [Convert]::FromBase64String([IO.File]::ReadAllText('\(escapedTemp)')))\"")

        // Extract ZIP
        _ = try await ssh.execute("cd '\(escapedProject)' && unzip -o '\(escapedZip)' 2>/dev/null || powershell -Command \"Expand-Archive -Path '\(escapedZip)' -DestinationPath '\(escapedProject)' -Force\"")

        // If the ZIP contained a top-level folder with the same name, flatten it
        let entries = try await ssh.listFiles(projectPath)
        if entries.count == 1 && entries[0].isDirectory && entries[0].name == projectName {
            let innerPath = entries[0].path
            // Move contents up
            let innerEntries = try await ssh.listFiles(innerPath)
            for entry in innerEntries {
                let dest = (projectPath as NSString).appendingPathComponent(entry.name)
                try? await ssh.movePath(from: entry.path, to: dest)
            }
            try? await ssh.deletePath(innerPath)
        }

        // Cleanup
        _ = try? await ssh.deletePath(remoteZipPath)
        _ = try? await ssh.deletePath(escapedTemp)

        return projectPath
    }

    /// Save a file to the iOS Files app (Downloads directory).
    public func saveToFilesApp(_ url: URL) -> URL? {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let downloadsDir = documentsDir.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let dest = downloadsDir.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: url, to: dest)
        return dest
    }
}
