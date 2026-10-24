import SwiftUI
import AppKit
import ServiceManagement

struct LoginLaunchSettings: View {
    @State private var status = SMAppService.mainApp.status
    @State private var changing = false
    @State private var errorMessage: String?

    private var isRegistered: Bool {
        status == .enabled || status == .requiresApproval
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("ログイン時に自動起動", isOn: Binding(
                get: { isRegistered },
                set: { enabled in
                    Task { await setEnabled(enabled) }
                }
            ))
            .disabled(changing)

            if status == .requiresApproval {
                Text("自動起動するには、システム設定で許可してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("ログイン項目の設定を開く") {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { status = SMAppService.mainApp.status }
        .task {
            // Reflect changes made outside this app in System Settings.
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification) {
                status = SMAppService.mainApp.status
            }
        }
    }

    @MainActor
    private func setEnabled(_ enabled: Bool) async {
        guard !changing else { return }
        changing = true
        errorMessage = nil
        defer {
            status = SMAppService.mainApp.status
            changing = false
        }
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled && service.status != .requiresApproval {
                    try service.register()
                }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try await service.unregister()
            }
        } catch {
            errorMessage = "自動起動の設定を変更できませんでした：\(error.localizedDescription)"
        }
    }
}
