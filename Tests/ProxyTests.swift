import Foundation

@main
struct ProxyTests {
    static func main() {
        var failures = 0

        func check(_ description: String, _ condition: @autoclosure () -> Bool) {
            if condition() {
                print("PASS  \(description)")
            } else {
                print("FAIL  \(description)")
                failures += 1
            }
        }

        let http = ProxyConfiguration(
            kind: .http, host: "127.0.0.1", port: 7890, username: nil, password: nil)
        check("an HTTP proxy parses", http?.kind == .http)
        check("its host survives", http?.host == "127.0.0.1")
        check("its port survives", http?.port == 7890)

        let socks = ProxyConfiguration(
            kind: .socks5, host: "proxy.local", port: 1080, username: nil, password: nil)
        check("a SOCKS5 proxy parses", socks?.kind == .socks5)

        let authenticated = ProxyConfiguration(
            kind: .http, host: "proxy.local", port: 8080, username: " user ", password: "pass")
        check("the username is trimmed", authenticated?.username == "user")
        check("the password survives", authenticated?.password == "pass")
        check(
            "an empty password becomes nil",
            ProxyConfiguration(
                kind: .http, host: "proxy.local", port: 8080, username: nil, password: ""
            )?.password == nil)

        check(
            "a missing host is rejected",
            ProxyConfiguration(kind: .http, host: " ", port: 8080, username: nil, password: nil)
                == nil)
        check(
            "a host with a path is rejected",
            ProxyConfiguration(
                kind: .http, host: "proxy.local/path", port: 8080, username: nil, password: nil)
                == nil)
        check(
            "a port outside the range is rejected",
            ProxyConfiguration(
                kind: .http, host: "proxy.local", port: 70_000, username: nil, password: nil)
                == nil)
        let server = ProxyConfiguration.serverParts(from: "2.27.16.115:11080")
        check("a server field splits into a host", server?.host == "2.27.16.115")
        check("a server field splits into a port", server?.port == 11080)
        check(
            "a host name with a port parses",
            ProxyConfiguration.serverParts(from: "proxy.local:1080")?.host == "proxy.local")
        check(
            "an IPv6 literal parses",
            ProxyConfiguration.serverParts(from: "[::1]:1080")?.host == "::1")
        check("a missing port is rejected", ProxyConfiguration.serverParts(from: "proxy.local") == nil)
        check(
            "a path is rejected",
            ProxyConfiguration.serverParts(from: "proxy.local:8080/path") == nil)
        check(
            "an out-of-range port is rejected",
            ProxyConfiguration.serverParts(from: "proxy.local:70000") == nil)

        check(
            "the kind's default ports are right",
            ProxyConfiguration.Kind.http.defaultPort == 80
                && ProxyConfiguration.Kind.https.defaultPort == 443
                && ProxyConfiguration.Kind.socks5.defaultPort == 1080)

        print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }
}
