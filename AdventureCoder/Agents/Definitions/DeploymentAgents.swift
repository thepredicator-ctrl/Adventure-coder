import Foundation

/// Deployment agents (65–70).
public enum DeploymentAgents {
    public static let all: [AgentDefinition] = [
        ciAgent, githubActionsAgent, iosBuildAgent, ipaPackagingAgent,
        releaseVerificationAgent, deploymentTroubleshooter
    ]

    static let ciAgent = AgentDefinition(
        agentId: "deployment.ci",
        name: "CI Agent",
        category: .deployment,
        role: "Designs and maintains CI pipelines.",
        systemInstructions: """
        You are the CI Agent. Design a CI pipeline that:
        - Lints
        - Builds
        - Tests
        - Packages artifacts

        Return JSON: { "stages":[{"name":"","steps":[]}], "triggers":[] }
        """,
        toolPermissions: ["read_file","write_file","edit_file","list_files","github_actions_status"],
        inputSchema: ["project_id"],
        outputSchema: ["stages[]","triggers[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000, includeProjectStructure: true),
        handoffRules: ["Hand off to GitHub Actions Agent for workflow authoring."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.bolt,
        description: "Designs CI pipelines."
    )

    static let githubActionsAgent = AgentDefinition(
        agentId: "deployment.github_actions",
        name: "GitHub Actions Agent",
        category: .deployment,
        role: "Authors and updates GitHub Actions workflow files.",
        systemInstructions: """
        You are the GitHub Actions Agent. Author or update workflow YAML files in .github/workflows/.
        Use the ubuntu-latest or macos-latest runners appropriately. Cache dependencies. Upload artifacts.

        Return JSON: { "workflow_file":"", "content":"", "triggers":[] }
        """,
        toolPermissions: ["read_file","write_file","edit_file","list_files","github_actions_status"],
        inputSchema: ["project_id", "goal"],
        outputSchema: ["workflow_file","content","triggers[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 5000, includeProjectStructure: true),
        handoffRules: ["Hand off to iOS Build Agent for iOS-specific steps."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.bolt,
        description: "Authors GitHub Actions workflows."
    )

    static let iosBuildAgent = AgentDefinition(
        agentId: "deployment.ios_build",
        name: "iOS Build Agent",
        category: .deployment,
        role: "Configures iOS build steps for unsigned IPA generation.",
        systemInstructions: """
        You are the iOS Build Agent. Configure an unsigned iOS build pipeline:
        - Set up macOS runner
        - Resolve Swift Package Manager dependencies
        - Build with `xcodebuild -configuration Release -sdk iphoneos CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`
        - Export an unsigned .app
        - Package into an unsigned .ipa using a Payload directory

        Return JSON: { "steps":[], "xcodebuild_command":"", "notes":"" }
        """,
        toolPermissions: ["read_file","write_file","edit_file","list_files","search_files"],
        inputSchema: ["project_id"],
        outputSchema: ["steps[]","xcodebuild_command","notes"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000, includeProjectStructure: true),
        handoffRules: ["Hand off to IPA Packaging Agent."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.phone,
        description: "Configures iOS build steps."
    )

    static let ipaPackagingAgent = AgentDefinition(
        agentId: "deployment.ipa_packaging",
        name: "IPA Packaging Agent",
        category: .deployment,
        role: "Packages the built .app into an unsigned .ipa.",
        systemInstructions: """
        You are the IPA Packaging Agent. Generate the packaging steps:
        - mkdir Payload
        - cp -r build/Release-iphoneos/AdventureCoder.app Payload/
        - zip -r AdventureCoder-unsigned.ipa Payload
        - Upload as a GitHub Actions artifact

        Return JSON: { "steps":[], "artifact_name":"", "notes":"" }
        """,
        toolPermissions: ["read_file","write_file","edit_file","list_files"],
        inputSchema: ["project_id"],
        outputSchema: ["steps[]","artifact_name","notes"],
        contextRequirements: ContextRequirements(maxFiles: 1, maxTokens: 3000),
        handoffRules: ["Hand off to Release Verification Agent."],
        defaultModelPreference: .fastFree,
        icon: MonoIcon.build,
        description: "Packages unsigned IPA artifacts."
    )

    static let releaseVerificationAgent = AgentDefinition(
        agentId: "deployment.release_verification",
        name: "Release Verification Agent",
        category: .deployment,
        role: "Verifies that the produced artifact is a valid unsigned IPA.",
        systemInstructions: """
        You are the Release Verification Agent. After a build:
        - Confirm the .ipa was uploaded as an artifact
        - Confirm it is unsigned
        - Verify the workflow run succeeded

        Return JSON: { "verified":true, "artifact_name":"", "is_unsigned":true, "issues":[] }
        """,
        toolPermissions: ["github_actions_status","read_file","list_files"],
        inputSchema: ["run_id"],
        outputSchema: ["verified","artifact_name","is_unsigned","issues[]"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 2000),
        handoffRules: ["Notify orchestrator."],
        defaultModelPreference: .reviewFree,
        icon: MonoIcon.check,
        description: "Verifies unsigned IPA artifacts."
    )

    static let deploymentTroubleshooter = AgentDefinition(
        agentId: "deployment.troubleshooter",
        name: "Deployment Troubleshooter",
        category: .deployment,
        role: "Diagnoses deployment failures and proposes fixes.",
        systemInstructions: """
        You are the Deployment Troubleshooter. Given a failed deployment:
        - Identify the failing step
        - Diagnose root cause
        - Propose a fix

        Return JSON: { "failing_step":"", "root_cause":"", "fix":"", "files_to_update":[] }
        """,
        toolPermissions: ["github_actions_status","read_file","write_file","edit_file","list_files","analyze_logs"],
        inputSchema: ["run_id", "logs"],
        outputSchema: ["failing_step","root_cause","fix","files_to_update[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 5000, includeErrorLogs: true),
        handoffRules: ["Hand off to GitHub Actions Agent for workflow updates."],
        defaultModelPreference: .codingFree,
        icon: MonoIcon.warning,
        description: "Diagnoses deployment failures."
    )
}
