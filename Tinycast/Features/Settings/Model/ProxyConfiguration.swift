import Foundation

/// One proxy endpoint, in the shape Settings and Network.framework both understand.
struct ProxyConfiguration: Equatable, Sendable {
    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case http
        case https
        case socks5

        var id: Self { self }

        var title: String {
            switch self {
            case .http: "HTTP"
            case .https: "HTTPS"
            case .socks5: "SOCKS5"
            }
        }

        var defaultPort: Int {
            switch self {
            case .http: 80
            case .https: 443
            case .socks5: 1080
            }
        }
    }

    let kind: Kind
    let host: String
    let port: Int
    let username: String?
    let password: String?

    init?(kind: Kind, host: String, port: Int, username: String?, password: String?) {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidHost(host), (1...65_535).contains(port) else { return nil }
        let username = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = password ?? ""
        self.kind = kind
        self.host = host
        self.port = port
        self.username = username.isEmpty ? nil : username
        self.password = password.isEmpty ? nil : password
    }

    static func isValidHost(_ host: String) -> Bool {
        !host.isEmpty
            && host.allSatisfy { !$0.isWhitespace && !"/?#@".contains($0) }
    }

    /// Splits the one Settings field into the host and port a session needs.
    static func serverParts(from text: String) -> (host: String, port: Int)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            !trimmed.contains(where: { $0.isWhitespace || "/?#@".contains($0) }),
            let components = URLComponents(string: "http://\(trimmed)"),
            let rawHost = components.host,
            let port = components.port,
            (1...65_535).contains(port),
            components.path.isEmpty,
            components.query == nil,
            components.fragment == nil
        else { return nil }
        let host = rawHost.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        guard isValidHost(host) else { return nil }
        return (host, port)
    }
}
