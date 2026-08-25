import SwiftUI

/// Compact status indicator for the remote PC, shown in the sidebar.
public struct RemotePCStatusIndicator: View {
    @StateObject private var store = RemotePCStore.shared
    @State private var showDetails = false

    public init() {}

    public var body: some View {
        Button(action: { showDetails = true }) {
            HStack(spacing: MonoSpace.xs) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(statusText)
                    .font(MonoType.caption)
                    .foregroundColor(MonoColor.secondaryText)
            }
            .padding(.horizontal, MonoSpace.sm)
            .padding(.vertical, MonoSpace.xs)
            .background(MonoColor.inset)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetails) {
            RemotePCStatusView()
                .presentationDetents([.medium, .large])
        }
    }

    private var statusColor: Color {
        if store.isConnecting { return MonoColor.warning }
        if store.isConnected { return MonoColor.success }
        return MonoColor.tertiaryText
    }

    private var statusText: String {
        if store.isConnecting { return "Connecting…" }
        if store.isConnected, let machine = store.activeMachine {
            return "\(machine.name) PC"
        }
        return "No PC"
    }
}

/// Full status view with hardware metrics.
public struct RemotePCStatusView: View {
    @StateObject private var store = RemotePCStore.shared
    @State private var refreshTask: Task<Void, Never>?

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                if let machine = store.activeMachine {
                    Section("Connection") {
                        statusRow(label: "Status", value: store.isConnected ? "● Connected" : "○ Disconnected")
                        statusRow(label: "Host", value: machine.host)
                        statusRow(label: "User", value: machine.username)
                        statusRow(label: "Port", value: "\(machine.port)")
                        if let env = store.environment {
                            statusRow(label: "Latency", value: "\(Int(env.cpuUsage * 100))% CPU")
                            statusRow(label: "OS", value: "\(env.os.displayName) \(env.osVersion)")
                            statusRow(label: "Hostname", value: env.hostname)
                        }
                    }

                    if let env = store.environment {
                        Section("Hardware") {
                            metricRow(label: "CPU", value: env.cpuArchitecture, usage: env.cpuUsage)
                            metricRow(label: "RAM", value: String(format: "%.1f GB", env.ramTotalGB), usage: env.ramUsage)
                            metricRow(label: "Disk", value: String(format: "%.1f GB", env.diskTotalGB), usage: env.diskUsage)
                        }

                        Section("Workspace") {
                            Text(env.workspacePath)
                                .font(MonoType.codeBody)
                                .foregroundColor(MonoColor.secondaryText)
                                .textSelection(.enabled)
                        }
                    }

                    Section {
                        if store.isConnected {
                            Button(action: { Task { await store.disconnect() } }) {
                                Label("Disconnect", systemImage: "xmark.circle")
                                    .foregroundColor(MonoColor.error)
                            }
                        } else {
                            Button(action: { Task { _ = await store.connect(to: machine) } }) {
                                Label("Connect", systemImage: "link")
                            }
                        }
                        NavigationLink {
                            RemoteSettingsView()
                        } label: {
                            Label("Configure", systemImage: MonoIcon.settings)
                        }
                    }
                } else {
                    Section {
                        Text("No remote PC configured.")
                            .font(MonoType.body)
                            .foregroundColor(MonoColor.tertiaryText)
                        NavigationLink {
                            RemoteSettingsView()
                        } label: {
                            Label("Add a Remote PC", systemImage: MonoIcon.plus)
                        }
                    }
                }
            }
            .navigationTitle("Remote PC")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: refresh) {
                        Image(systemName: MonoIcon.refresh)
                    }
                }
            }
        }
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(MonoType.body)
                .foregroundColor(MonoColor.tertiaryText)
            Spacer()
            Text(value)
                .font(MonoType.body)
                .foregroundColor(MonoColor.primaryText)
        }
    }

    private func metricRow(label: String, value: String, usage: Double) -> some View {
        VStack(alignment: .leading, spacing: MonoSpace.xs) {
            HStack {
                Text(label)
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.tertiaryText)
                Spacer()
                Text(value)
                    .font(MonoType.body)
                    .foregroundColor(MonoColor.primaryText)
            }
            ProgressView(value: usage)
                .tint(usage > 0.8 ? MonoColor.error : (usage > 0.6 ? MonoColor.warning : MonoColor.success))
            Text("\(Int(usage * 100))%")
                .font(MonoType.caption)
                .foregroundColor(MonoColor.tertiaryText)
        }
    }

    private func refresh() {
        // Re-detect environment
        if store.isConnected, let machine = store.activeMachine {
            Task {
                _ = await store.connect(to: machine)
            }
        }
    }
}
