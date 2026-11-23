import Foundation

/// The optional proxy password, kept out of `UserDefaults`, settings.json and every backup.
enum ProxyCredentialStore {
    private static let store = KeychainSecretStore(scope: "network-proxy")
    private static let account = UUID(uuidString: "7A3B0E52-3D7A-4C1E-9E2A-9C1D0B5F6A21")!

    static var hasPassword: Bool {
        (try? store.hasSecret(for: account)) ?? false
    }

    static var password: String? {
        try? store.secret(for: account)
    }

    static func setPassword(_ password: String?) throws {
        guard let password, !password.isEmpty else {
            try store.removeSecret(for: account)
            return
        }
        try store.setSecret(password, for: account)
    }
}
