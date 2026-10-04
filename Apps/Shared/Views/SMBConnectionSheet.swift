import SwiftUI

/// Ephemeral form input. The password is handed to the app store and never persisted by the view.
struct SMBConnectionDraft: Sendable {
    var name = ""
    var host = ""
    var share = ""
    var username = ""
    var password = ""
    var port = "445"
    var directory = ""
    var domain = ""
    var requireEncryption = false

    var isValid: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !share.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && portNumber != nil
    }

    var portNumber: UInt16? {
        guard let value = UInt16(port), value > 0 else { return nil }
        return value
    }
}

struct SMBConnectionSheet: View {
    let onConnect: @MainActor (SMBConnectionDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = SMBConnectionDraft()
    @State private var isConnecting = false
    @State private var isAdvancedExpanded = false
    @State private var errorMessage: String?
    @State private var connectionTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    plainField("名称（可选）", text: $draft.name, identifier: "smb.name")
                    plainField("服务器", text: $draft.host, identifier: "smb.host")
                    plainField("共享名称", text: $draft.share, identifier: "smb.share")
                } header: {
                    Text("NAS 片源")
                } footer: {
                    Text("服务器填写 IP 地址或主机名，例如 nas.local；共享名称填写 NAS 上的共享文件夹名称。")
                }
                .disabled(isConnecting)

                Section {
                    plainField("用户名", text: $draft.username, identifier: "smb.username")
                    SecureField("密码", text: $draft.password)
                        .accessibilityIdentifier("smb.password")
                } header: {
                    Text("登录")
                } footer: {
                    Text("支持访客访问的共享可留空。密码仅保存在系统钥匙串。")
                }
                .disabled(isConnecting)

                Section {
                    DisclosureGroup(isExpanded: $isAdvancedExpanded) {
                        plainField("端口", text: $draft.port, identifier: "smb.port")
                        plainField("起始目录（可选）", text: $draft.directory, identifier: "smb.directory")
                        plainField("域（可选）", text: $draft.domain, identifier: "smb.domain")
                        Toggle("要求 SMB 3 加密", isOn: $draft.requireEncryption)
                            .accessibilityIdentifier("smb.encryption")
                        Text("仅在 NAS 要求加密时启用。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if draft.portNumber == nil {
                            Text("端口应为 1 到 65535 的数字。")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    } label: {
                        Text("高级选项")
                            .accessibilityIdentifier("smb.advanced")
                        #if os(macOS)
                            .contentShape(Rectangle())
                            .onTapGesture { isAdvancedExpanded.toggle() }
                        #endif
                    }
                }
                .disabled(isConnecting)

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("smb.error")
                    }
                }

                if isConnecting {
                    Section {
                        ProgressView("正在连接 NAS…")
                            .accessibilityIdentifier("smb.connecting")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("连接 SMB")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        connectionTask?.cancel()
                        dismiss()
                    }
                    .accessibilityIdentifier("smb.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("连接", action: connect)
                        .disabled(!draft.isValid || isConnecting)
                        .accessibilityIdentifier("smb.connect")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, idealWidth: 480, minHeight: isAdvancedExpanded ? 650 : 470)
        #endif
        .onDisappear {
            connectionTask?.cancel()
            draft.password = ""
        }
    }

    @ViewBuilder
    private func plainField(_ title: String, text: Binding<String>, identifier: String) -> some View {
        TextField(title, text: text)
            .accessibilityIdentifier(identifier)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            #endif
    }

    private func connect() {
        guard draft.isValid, !isConnecting else { return }
        errorMessage = nil
        isConnecting = true
        connectionTask = Task { @MainActor in
            do {
                try await onConnect(draft)
                guard !Task.isCancelled else { return }
                draft.password = ""
                isConnecting = false
                dismiss()
            } catch is CancellationError {
                isConnecting = false
            } catch {
                guard !Task.isCancelled else { return }
                isConnecting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
