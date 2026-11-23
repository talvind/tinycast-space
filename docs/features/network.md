# Network

Tinycast's own internet traffic can be routed through one proxy, configured in **Settings → General
→ Network → Proxy**. The switch is off by default, which leaves every request on macOS's own proxy
configuration.

## Invariants

- **Every request still uses its feature's private `.ephemeral` session with `urlCache = nil`.** The
  proxy only fills `proxyConfigurations`; it never introduces `URLSession.shared`, a shared cache or
  a cookie jar.
- **`Network.ProxyConfiguration` is the transport**, not `connectionProxyDictionary`. It is the only
  public API that sends SOCKS5 credentials: a proxy dictionary offers just the no-auth method, so an
  authenticated SOCKS5 server answers `0xFF` and CFNetwork reports `bad URL`.
- **Off, or an incomplete configuration, means macOS's own proxy.** `NetworkProxy.apply(to:)` leaves
  both proxy properties empty, so CFNetwork follows System Settings.
- **The type is explicit**: HTTP, HTTPS or SOCKS5. HTTP is a cleartext HTTP CONNECT proxy; HTTPS
  connects to the proxy itself over TLS; SOCKS5 uses `nw_proxy_config_create_socksv5`.
- **The server is one `host:port` field.** The host is a name or IP address and the port is 1–65535.
  A path, query, fragment, whitespace or `@` is rejected; Settings shows an inline error and the
  helper does not apply it.
- **Authentication is optional.** The username travels with the rest of the setting; the password
  lives in Keychain, never in `UserDefaults`, `settings.json` or a backup. `ProxyCredentialStore` is
  the only reader and writer. Credentials are handed to Network.framework with
  `applyCredential(username:password:)`.
- **Loopback and `.local` hosts are excluded** through `excludedDomains`, so Ollama, LM Studio and a
  local MCP or extension server keep answering while a proxy is set.
- **A change applies to connections opened afterwards.** Most AI requests and every extension-store
  search build a fresh session, so those pick a change up immediately; long-lived sessions may need
  a relaunch.

## Where it applies

`NetworkProxy.apply(to:)` is called wherever a feature builds its session:

| Feature | Sessions |
| --- | --- |
| AI | `HTTPAIProvider` turns and `AIModelDiscoveryService` |
| MCP | `MCPOAuthHTTP` |
| Calculator | `CurrencyRateStore`'s exchange-rate fetches |
| Updates | `UpdateCheckStore` and `UpdateDownloader` |
| Extensions | `ExtensionFetcher`, `ExtensionStoreClient`, `ExtensionIconCache` and `ExtensionWebSocketBridge` |
| Dictation | `DictationModelDownloader` |

`ExtensionStoreClient` owns one session for its lifetime, so a store search started after changing the
proxy uses the new setting rather than a session cached at launch. The `curl` in
`ExtensionFetcher.socketResponse` keeps `--noproxy *`: it talks to a Unix socket on this Mac, never to
the internet.

## The setting

`AppSettings` keeps `proxyEnabled`, `proxyKind`, `proxyServer` and `proxyUsername`;
`ProxyConfiguration.Kind` is `http`, `https` or `socks5`, and `proxyServer` is the one `host:port`
field. `settings.json` mirrors the four as `general.proxy*`, and only values Tinycast can parse are
accepted.

All of them stay out of backups: a proxy names a network this Mac is on, and an import must not
redirect another Mac's traffic or grant its credentials. The password has no settings-file key at
all. See [settings-file.md](settings-file.md) and [backup.md](backup.md).
