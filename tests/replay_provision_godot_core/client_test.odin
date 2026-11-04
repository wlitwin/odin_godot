package provision_godot_test
import "core:testing"
import p "godot:replay/provision"
import rgd "godot:replay/godot"

@(test)
credential_transport_requires_tls_or_explicit_literal_loopback :: proc(t: ^testing.T) {
    for url in ([]string {
            "",
            "ws://localhost:80",
            "https://example.com",
            "wss://",
            "wss://user@example.com",
            "wss://example.com\n",
            "wss://example.com\\evil",
        }) {
        testing.expect(t, !rgd.provision_url_valid(url))
    }

    for url in ([]string{"ws://localhost:80", "ws://127.0.0.1:1234/path", "ws://[::1]:65535"}) {
        testing.expect(t, rgd.provision_url_valid(url, true))
    }

    for url in ([]string {
            "ws://localhost:80@evil.test",
            "ws://localhost:80.evil.test",
            "ws://127.0.0.1.evil.test:80",
            "ws://localhost:0",
            "ws://localhost:65536",
            "ws://localhost:80%40evil",
            "ws://192.168.1.2:80",
        }) {
        testing.expect(t, !rgd.provision_url_valid(url, true))
    }

    testing.expect(t, rgd.provision_url_valid("wss://rooms.example.test/join"))
}

@(test)
grant_handoff_requires_content_and_keeps_process_registration :: proc(t: ^testing.T) {
    options := rgd.Room_Options {
        session                 = rgd.SESSION_OPTIONS,
        provisioned_incarnation = true,
    }
    options.session.network.content = 55
    g := p.Grant {
        room = 44,
        content = 55,
        identity = {2, 9},
        key = {0 = 1},
        token = {0 = 2},
    }
    result, ok := rgd.room_with_grant(options, g)
    testing.expect(
        t,
        ok &&
        result.identity == g.identity &&
        result.session.token == g.token &&
        result.key == g.key &&
        result.room == 44,
    )
    testing.expect(t, !result.bootstrap && !result.provisioned_incarnation && result.session.incarnation == 0)
    g.content = 56
    _, ok = rgd.room_with_grant(options, g)
    testing.expect(t, !ok)
    g.content = 55
    g.can_host = true
    _, ok = rgd.room_with_grant(options, g)
    testing.expect(t, !ok)
    g.trusted_authority = true
    g.identity.member = 1
    result, ok = rgd.room_with_grant(options, g)
    testing.expect(t, ok && result.bootstrap && !result.provisioned_incarnation)
}
