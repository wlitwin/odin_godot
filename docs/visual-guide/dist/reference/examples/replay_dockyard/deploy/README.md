# Dockyard service configuration

The selected [Pi deployment](pi.md) serves
`wss://mc.laserturtle.net:62127/replay-room/dockyard`, alongside the existing
Scrapyard `/rtc` route and shared TURN relay. The files here also include generic
templates for another deployment. Public-origin iframe checks and off-network
acceptance are separate from local HTTPS/WSS and relay tests.

Serve the **ordinary production export**, including its PCK and Wasm files, from
one HTTPS origin. Never publish the test-bridge project, browser profiles,
enrollment databases, private fixture directories, certificates' private keys or
TURN credentials. The [Caddyfile](Caddyfile) sets the same COOP/COEP/CORP response
headers used by the browser checks. It takes `DOCKYARD_HTTPS_ADDRESS`,
`DOCKYARD_WEB_ROOT`, `DOCKYARD_TLS_CERT` and `DOCKYARD_TLS_KEY` from the operator's
environment and uses supplied certificates. It performs no automatic certificate
enrollment. Its syntax follows Caddy's [header](https://caddyserver.com/docs/caddyfile/directives/header)
and [TLS](https://caddyserver.com/docs/caddyfile/directives/tls) directives.

Use the existing [Replay room service](../../replay_room_service/README.md), built
with the selected Native library and explicit static SQLite input. It owns
enrollment, authority leases, signaling and relay credential issuance. It does
not simulate Dockyard. Set `REPLAY_ROOM_CHECKPOINT_MODEL=disabled`; this release
does not supply durable-world publication or host takeover. Use the selected
artifact's exact `DOCKYARD_LOBBY` cohort in `REPLAY_ROOM_CONTENT`, with separate
databases/services for incompatible cohorts. Native and Web cohorts differ.

Copy [service.env.example](service.env.example) to a private operator file, replace
the paths/addresses and explicitly initialize the database once. Subsequent starts
must not silently recreate a missing database. Run the service's prepared project
with `ODIN_SCRIPTS_DLL` pointing to its exact scripts library. The service itself
serves WSS using its certificate and key; the static-file Caddy server is separate.

For a public relay, complete [turnserver.conf.template](turnserver.conf.template)
using the [pinned Coturn configuration reference](https://github.com/coturn/coturn/blob/4.9.0/examples/etc/turnserver.conf).
The room service and Coturn share the server-only secret. Clients receive short
lived credentials through authenticated membership. Set the listener/relay IPs,
any actual NAT mapping and firewall rules for the chosen UDP/TCP/TLS listeners
and relay port range. The public template deliberately has no loopback-peer
exception; that exception belongs only to the isolated local tests.

Open the game with public routing configuration, for example:

```text
https://game.example.invalid/index.html?service=wss%3A%2F%2Frooms.example.invalid%3A49740&relay=1
```

The URL contains no credentials. Players choose a name and Host or Join; they share
the explicit invitation code through Copy Invite. Invite codes are capabilities,
so keep them out of logs, public URLs and screenshots. Recent Crew uses the stored
membership, rather than reusing a consumed invitation. Serve the same qualified
Wasm artifact to both browser players. Public Internet acceptance still requires
two actual remote endpoints, valid public trust and recorded selected candidate
pairs with transferred traffic. Local certificate pins and local TURN success
do not establish that result.

## itch.io connections and local DNS

An itch page is a public origin. If the room hostname resolves to a private LAN
address on the player's network, browser local-network restrictions can block
the WebSocket before a room request reaches the proxy. The observed itch iframe
does not delegate the `local-network` permission. A successful localhost preview
or command-line WebSocket handshake does not test that permission boundary.

Compare the system resolver with a public resolver:

```sh
dig +short mc.laserturtle.net
dig @1.1.1.1 +short mc.laserturtle.net
```

For this public game endpoint, remove a local DNS rewrite to `10.0.0.10` so clients
use the public DNS record. Keep LAN-only names separate. Restart the browser after
the DNS correction. The existing public port and proxy paths remain the same.
Keep the WSS hostname for certificate validation; changing the URL to an IP literal
does not preserve that validation.

The retained itch-origin probes reproduced failures on both `/rtc` and
`/replay-room/dockyard` with local DNS. Using public DNS restored WebSocket
connections in Chrome and Firefox without disabling browser protections. Chrome
reported `ERR_BLOCKED_BY_LOCAL_NETWORK_ACCESS_CHECKS`; Firefox reported a generic
connection failure. The separate Firefox `Source Map URL: null` diagnostic concerns
debugging metadata, not the WebSocket route. See
[Chrome's WebSocket rollout](https://groups.google.com/a/chromium.org/g/blink-dev/c/O6GMKt44Ups)
and the [Local Network Access permission model](https://wicg.github.io/local-network-access/#permissions).
