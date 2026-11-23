import SwiftUI

struct ProxySettingsSection: View {
    @Environment(AppSettings.self) private var settings
    @State private var password = ""
    @State private var passwordStored = false
    @State private var passwordFailure: String?
    @FocusState private var passwordFocused: Bool

    var body: some View {
        @Bindable var settings = settings
        return Section {
            Toggle(isOn: $settings.proxyEnabled) {
                SettingsRowTitle(.generalNetwork, "Proxy")
                Text("Route Tinycast's internet requests through this proxy.")
            }
            if settings.proxyEnabled {
                Picker(selection: $settings.proxyKind) {
                    ForEach(ProxyConfiguration.Kind.allCases) { kind in
                        Text(verbatim: kind.title).tag(kind)
                    }
                } label: {
                    Text("Type")
                }
                SettingsRow(
                    title: String(localized: "Server"),
                    subtitle: String(localized: "Host name or IP address and port.")
                ) {
                    TextField(
                        "", text: $settings.proxyServer,
                        prompt: Text(verbatim: "127.0.0.1:8080")
                    )
                    .labelsHidden()
                    .font(.callout.monospaced())
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .frame(width: 240)
                }
                SettingsRow(
                    title: String(localized: "Username"),
                    subtitle: String(localized: "Optional.")
                ) {
                    TextField("", text: $settings.proxyUsername, prompt: Text(verbatim: "user"))
                        .labelsHidden()
                        .font(.callout.monospaced())
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .frame(width: 240)
                }
                SettingsRow(
                    title: String(localized: "Password"),
                    subtitle: passwordStored
                        ? String(localized: "A password is stored in Keychain.")
                        : String(localized: "Optional.")
                ) {
                    VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                        ZStack(alignment: .trailing) {
                            SecureField(
                                "", text: $password,
                                prompt: passwordStored
                                    ? Text(verbatim: "••••••••") : Text("Optional")
                            )
                            .labelsHidden()
                            .font(.callout.monospaced())
                            .multilineTextAlignment(.trailing)
                            .padding(.trailing, passwordStored ? 28 : 0)
                            .frame(width: 240)
                            .focused($passwordFocused)
                            .onSubmit(savePassword)
                            if passwordStored {
                                Button(action: removePassword) {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .padding(.trailing, 4)
                                .help("Remove password")
                                .accessibilityLabel("Remove password")
                            }
                        }
                        if let passwordFailure {
                            Text(passwordFailure)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                if ProxyConfiguration.serverParts(from: settings.proxyServer) == nil {
                    Label(
                        "Enter a server and port, like 127.0.0.1:8080.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
        } header: {
            SettingsSectionHeader(.generalNetwork)
        }
        .onAppear { passwordStored = ProxyCredentialStore.hasPassword }
        .onChange(of: passwordFocused) { old, new in
            if old && !new { savePassword() }
        }
        .onDisappear { savePassword() }
    }

    private func savePassword() {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try ProxyCredentialStore.setPassword(trimmed)
            password = ""
            passwordStored = true
            passwordFailure = nil
        } catch {
            passwordFailure = String(localized: "The password could not be saved to Keychain.")
        }
    }

    private func removePassword() {
        do {
            try ProxyCredentialStore.setPassword(nil)
            password = ""
            passwordStored = false
            passwordFailure = nil
        } catch {
            passwordFailure = String(localized: "The password could not be removed from Keychain.")
        }
    }
}
