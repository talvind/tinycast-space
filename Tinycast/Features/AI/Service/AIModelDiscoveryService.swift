import Foundation

final class AIModelDiscoveryService: Sendable {
    func models(
        provider: AIProviderKind, baseURL: URL, apiKey: String, headers: [String: String]
    ) async throws -> [AIModelDiscovery.Model] {
        let query = try AIModelDiscovery.query(
            provider: provider, baseURL: baseURL, apiKey: apiKey,
            appTitle: Bundle.main.appDisplayName, headers: headers)
        let session = Self.makeSession()
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: query.request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else {
            throw AIModelDiscovery.DiscoveryError.unavailable
        }
        switch response.statusCode {
        case 200:
            do {
                return try AIModelDiscovery.decode(data, shape: query.responseShape)
            } catch {
                throw AIModelDiscovery.DiscoveryError.malformedResponse
            }
        case 401, 403:
            throw AIModelDiscovery.DiscoveryError.rejectedKey
        case 404, 405, 501:
            throw AIModelDiscovery.DiscoveryError.unsupported
        default:
            throw AIModelDiscovery.DiscoveryError.unavailable
        }
    }

    /// Cacheless, and fresh per lookup so a proxy change applies without relaunching.
    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        NetworkProxy.apply(to: configuration)
        return URLSession(configuration: configuration)
    }
}
