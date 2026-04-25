import SwiftUI
import UIKit

@MainActor
@Observable
final class SettingsViewModel {
    var isConnected = false
    var account: RDAccount?
    var deviceCode: RDDeviceCode?
    var isPolling = false
    var errorMessage: String?
    private var pollTask: Task<Void, Never>?

    func refresh(using rd: any RealDebridService) async {
        isConnected = await rd.isAuthenticated()
        if isConnected {
            account = try? await rd.accountInfo()
        } else {
            account = nil
        }
    }

    func startConnect(using rd: any RealDebridService) async {
        errorMessage = nil
        do {
            let code = try await rd.beginDeviceCodeFlow()
            deviceCode = code
            pollTask?.cancel()
            pollTask = Task { [weak self] in
                guard let self else { return }
                self.isPolling = true
                do {
                    _ = try await rd.pollForToken(deviceCode: code.deviceCode, interval: TimeInterval(code.interval))
                    self.deviceCode = nil
                    await self.refresh(using: rd)
                } catch {
                    if !Task.isCancelled {
                        self.errorMessage = error.localizedDescription
                    }
                }
                self.isPolling = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelConnect() {
        pollTask?.cancel()
        pollTask = nil
        deviceCode = nil
        isPolling = false
    }

    func disconnect(using rd: any RealDebridService) async {
        try? await rd.disconnect()
        await refresh(using: rd)
    }
}

struct SettingsView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var vm = SettingsViewModel()

    var body: some View {
        Form {
            Section("Real-Debrid") {
                if let code = vm.deviceCode {
                    deviceCodeBlock(code)
                } else if vm.isConnected {
                    if let account = vm.account {
                        LabeledContent("Account", value: account.username)
                        if let exp = account.premiumExpiresAt {
                            LabeledContent("Premium until", value: exp.formatted(date: .abbreviated, time: .omitted))
                        }
                    } else {
                        Text("Connected").foregroundStyle(.green)
                    }
                    Button("Disconnect", role: .destructive) {
                        Task { await vm.disconnect(using: deps.realDebrid) }
                    }
                } else {
                    Text("Not connected").foregroundStyle(Theme.subtle)
                    Button("Connect Real-Debrid") {
                        Task { await vm.startConnect(using: deps.realDebrid) }
                    }
                }

                if let error = vm.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Playback") {
                Toggle("Subtitles on by default", isOn: .constant(true))
            }

            Section("About") {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Torrentio", value: "torrentio.strem.fun")
            }
        }
        .navigationTitle("Settings")
        .task {
            await vm.refresh(using: deps.realDebrid)
        }
    }

    private func deviceCodeBlock(_ code: RDDeviceCode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activate Vela")
                .font(.headline)
            Text("Open the link below, sign in if needed, and enter this code:")
                .font(.caption)
                .foregroundStyle(Theme.subtle)
            HStack {
                Text(code.userCode)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                Button {
                    UIPasteboard.general.string = code.userCode
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
            Link(destination: code.verificationURL) {
                Label(code.verificationURL.absoluteString, systemImage: "arrow.up.right.square")
                    .font(.callout)
            }
            HStack {
                if vm.isPolling {
                    ProgressView().scaleEffect(0.8)
                    Text("Waiting for activation…")
                        .font(.caption)
                        .foregroundStyle(Theme.subtle)
                }
                Spacer()
                Button("Cancel") { vm.cancelConnect() }
            }
        }
    }
}
