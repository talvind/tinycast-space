import Foundation
import Network

/// Applies Settings' proxy to every private session; disabled or incomplete settings keep macOS's own.
enum NetworkProxy {
    static var current: ProxyConfiguration? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: AppSettingsKey.proxyEnabled.rawValue) else { return nil }
        let kind =
            defaults.string(forKey: AppSettingsKey.proxyKind.rawValue)
            .flatMap(ProxyConfiguration.Kind.init(rawValue:)) ?? .http
        let serverText = defaults.string(forKey: AppSettingsKey.proxyServer.rawValue) ?? ""
        guard let server = ProxyConfiguration.serverParts(from: serverText) else { return nil }
        let username = defaults.string(forKey: AppSettingsKey.proxyUsername.rawValue)
        return ProxyConfiguration(
            kind: kind, host: server.host, port: server.port, username: username,
            password: ProxyCredentialStore.password)
    }

    /// `Network.ProxyConfiguration` is the only transport that carries SOCKS5 credentials; a
    /// `connectionProxyDictionary` offers only the no-auth method and the proxy rejects the tunnel.
    static func apply(to configuration: URLSessionConfiguration) {
        configuration.connectionProxyDictionary = nil
        guard let proxy = current,
            let port = NWEndpoint.Port(rawValue: UInt16(proxy.port))
        else {
            configuration.proxyConfigurations = []
            return
        }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(proxy.host), port: port)
        var networkProxy: Network.ProxyConfiguration
        switch proxy.kind {
        case .http:
            networkProxy = Network.ProxyConfiguration(httpCONNECTProxy: endpoint)
        case .https:
            networkProxy = Network.ProxyConfiguration(
                httpCONNECTProxy: endpoint, tlsOptions: .init())
        case .socks5:
            networkProxy = Network.ProxyConfiguration(socksv5Proxy: endpoint)
        }
        if let username = proxy.username {
            networkProxy.applyCredential(username: username, password: proxy.password ?? "")
        }
        networkProxy.allowFailover = false
        networkProxy.excludedDomains = ["localhost", "127.0.0.1", "::1", "local"]
        configuration.proxyConfigurations = [networkProxy]
    }
}
