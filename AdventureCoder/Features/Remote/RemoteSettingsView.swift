import SwiftUI

/// Settings view for configuring remote PCs.
public struct RemoteSettingsView: View {
    @StateObject private var store = RemotePCStore.shared
    @State private var showAddMachine = false
    @State private var editingMachine: RemotePC?

    public init() {}

    public var body: some View {
        Form {
            Section("Remote Machines") {
                ForEach(store.machines) { machine in
                    Button(action: { editingMachine = machine }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: MonoSpace.xs) {
                                    if store.activeMachineId == machine.id && store.isConnected {
                                        Circle().fill(MonoColor.success).frame(width: 6, height: 6)
                                    } else if store.activeMachineId == machine.id {
                                        Circle().fill(MonoColor.warning).frame(width: 6, height: 6)
                                    } else {
                                        Circle().fill(MonoColor.tertiaryText).frame(width: 6, height: 6)
                                    }
                                    Text(machine.name)
                                        .font(MonoType.body)
                                        .foregroundColor(MonoColor.primaryText)
                                }
                                Text("\(machine.username)@\(machine.host):\(machine.port)")
                                    .font(MonoType.caption)
                                    .foregroundColor(MonoColor.tertiaryText)
                            }
                            Spacer()
                            Image(systemName: MonoIcon.chevronRight)
                                .foregroundColor(MonoColor.tertiaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Button(action: { showAddMachine = true }) {
                    Label("Add Remote PC", systemImage: MonoIcon.plus)
                }
            }

            if let machine = store.activeMachine {
                Section("Active Machine: \(machine.name)") {
                    if store.isConnecting {
                        HStack {
                            ProgressView()
                            Text("Connecting...")
                                .font(MonoType.body)
                                .foregroundColor(MonoColor.secondaryText)
                        }
                    } else if store.isConnected {
                        Button(action: { Task { await store.disconnect() } }) {
                            Label("Disconnect", systemImage: "xmark.circle.fill")
                                .foregroundColor(MonoColor.error)
                        }
                    } else {
                        Button(action: { Task { _ = await store.connect(to: machine) } }) {
                            Label("Connect", systemImage: "link")
                        }
                        Button(action: { Task { _ = await store.testConnection(to: machine) } }) {
                            Label("Test Connection", systemImage: "checkmark.circle")
                        }
                    }

                    if let error = store.connectionError {
                        Text(error)
                            .font(MonoType.footnote)
                            .foregroundColor(MonoColor.error)
                    }
                }
            }

            Section("Security") {
                NavigationLink("Host Key Management") {
                    HostKeyManagementView()
                }
            }
        }
        .navigationTitle("Remote PC")
        .sheet(isPresented: $showAddMachine) {
            RemoteMachineEditView(machine: nil, isPresented: $showAddMachine)
        }
        .sheet(item: $editingMachine) { machine in
            RemoteMachineEditView(machine: machine, isPresented: .constant(true))
        }
    }
}

struct RemoteMachineEditView: View {
    let machine: RemotePC?
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var authMethod: RemotePC.AuthMethod = .password
    @State private var password: String = ""
    @State private var privateKey: String = ""
    @State private var workspacePath: String = ""
    @State private var testResult: String = ""
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Machine") {
                    TextField("Display name (e.g. Gaming PC)", text: $name)
                    TextField("Host (e.g. 192.168.1.100)", text: $host)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    TextField("Username", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Authentication") {
                    Picker("Method", selection: $authMethod) {
                        ForEach(RemotePC.AuthMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }

                    if authMethod == .password {
                        SecureField("Password", text: $password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        TextEditor(text: $privateKey)
                            .font(MonoType.codeSmall)
                            .frame(minHeight: 120)
                            .overlay(
                                Group {
                                    if privateKey.isEmpty {
                                        Text("Paste your private key here (OpenSSH format)")
                                            .font(MonoType.caption)
                                            .foregroundColor(MonoColor.tertiaryText)
                                            .padding(.horizontal, MonoSpace.sm)
                                            .padding(.top, MonoSpace.sm)
                                            .allowsHitTesting(false)
                                    }
                                }
                            )
                    }
                }

                Section("Workspace") {
                    TextField("Workspace path (e.g. C:\\Users\\Neth\\coder)", text: $workspacePath)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if machine != nil {
                    Section("Stored Credentials") {
                        let masked = RemotePCStore.shared.maskedCredentials(for: machine!)
                        Text(masked)
                            .font(MonoType.codeBody)
                            .foregroundColor(MonoColor.secondaryText)
                    }
                }

                Section {
                    Button(action: testConnection) {
                        HStack {
                            if isTesting { ProgressView() }
                            Label("Test Connection", systemImage: "checkmark.circle")
                        }
                    }
                    .disabled(isTesting || host.isEmpty || username.isEmpty)

                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(MonoType.footnote)
                            .foregroundColor(testResult.starts(with: "Connected") ? MonoColor.success : MonoColor.error)
                    }
                }

                if machine != nil {
                    Section("Danger Zone") {
                        Button(role: .destructive) {
                            RemotePCStore.shared.deleteCredentialsFor(machine: machine!)
                            testResult = "Credentials deleted."
                        } label: {
                            Label("Delete Stored Credentials", systemImage: "trash")
                        }
                        Button(role: .destructive) {
                            RemotePCStore.shared.removeMachine(machine!)
                            isPresented = false
                        } label: {
                            Label("Remove Machine", systemImage: "minus.circle")
                        }
                    }
                }
            }
            .navigationTitle(machine == nil ? "Add Remote PC" : "Edit Remote PC")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || host.isEmpty || username.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let machine = machine else { return }
        name = machine.name
        host = machine.host
        port = String(machine.port)
        username = machine.username
        authMethod = machine.authMethod
        workspacePath = machine.workspacePath
    }

    private func save() {
        var machine = machine ?? RemotePC(name: name, host: host, port: Int(port) ?? 22, username: username, authMethod: authMethod, workspacePath: workspacePath)
        machine.name = name
        machine.host = host
        machine.port = Int(port) ?? 22
        machine.username = username
        machine.authMethod = authMethod
        machine.workspacePath = workspacePath

        if !password.isEmpty && authMethod == .password {
            RemotePCStore.shared.savePassword(password, for: machine)
        }
        if !privateKey.isEmpty && authMethod == .privateKey {
            RemotePCStore.shared.savePrivateKey(privateKey, for: machine)
        }

        if self.machine == nil {
            RemotePCStore.shared.addMachine(machine)
        } else {
            RemotePCStore.shared.updateMachine(machine)
        }
        isPresented = false
    }

    private func testConnection() {
        guard !host.isEmpty, !username.isEmpty else { return }
        isTesting = true
        testResult = ""

        var machine = machine ?? RemotePC(name: name, host: host, port: Int(port) ?? 22, username: username, authMethod: authMethod, workspacePath: workspacePath)
        machine.name = name
        machine.host = host
        machine.port = Int(port) ?? 22
        machine.username = username
        machine.authMethod = authMethod
        machine.workspacePath = workspacePath

        // Temporarily save credentials for testing
        if !password.isEmpty && authMethod == .password {
            RemotePCStore.shared.savePassword(password, for: machine)
        }
        if !privateKey.isEmpty && authMethod == .privateKey {
            RemotePCStore.shared.savePrivateKey(privateKey, for: machine)
        }

        Task {
            let result = await RemotePCStore.shared.testConnection(to: machine)
            await MainActor.run {
                isTesting = false
                if result.success {
                    var parts: [String] = ["Connected"]
                    parts.append("Latency: \(result.latencyMs) ms")
                    if let env = result.environment {
                        parts.append("OS: \(env.os.displayName) \(env.osVersion)")
                        parts.append("Workspace: \(env.workspacePath)")
                    }
                    testResult = parts.joined(separator: "\n")
                } else {
                    testResult = result.message
                }
            }
        }
    }
}

struct HostKeyManagementView: View {
    @State private var hostKeys: [String: String] = [:]

    var body: some View {
        List {
            if hostKeys.isEmpty {
                Text("No host keys stored. Keys are saved automatically on first connection.")
                    .font(MonoType.footnote)
                    .foregroundColor(MonoColor.tertiaryText)
            }
            ForEach(Array(hostKeys.keys.sorted()), id: \.self) { host in
                VStack(alignment: .leading, spacing: 2) {
                    Text(host)
                        .font(MonoType.body)
                    Text(hostKeys[host] ?? "")
                        .font(MonoType.codeSmall)
                        .foregroundColor(MonoColor.tertiaryText)
                        .lineLimit(1)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let host = Array(hostKeys.keys.sorted())[index]
                    RemoteHostKeyStore.shared.remove(host: host)
                    hostKeys.removeValue(forKey: host)
                }
            }
        }
        .navigationTitle("Host Keys")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear All", role: .destructive) {
                    RemoteHostKeyStore.shared.clearAll()
                    hostKeys = [:]
                }
            }
        }
        .onAppear {
            // Load host keys from defaults directly
            if let data = UserDefaults.standard.data(forKey: "ssh_host_keys"),
               let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
                hostKeys = decoded
            }
        }
    }
}
