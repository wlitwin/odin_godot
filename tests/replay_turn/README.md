<a id="actual-turn-relay-gates"></a>

# TURN relay tests with Coturn

These fixtures use Coturn and real Chrome peer connections. They force
`iceTransportPolicy: "relay"`, inspect the selected candidate pair through the
browser's statistics API, and require relay candidates and transferred bytes on
both sides. A successful direct localhost connection cannot satisfy the gate.

The relay binds only to `127.0.0.1`. Test credentials are random and stored in a
private work directory. The fixture deliberately permits loopback relay peers;
that exception is for this local test and must not be copied to a public deployment.
Neither these tests nor the library install a public relay or issue production
relay credentials.

## Running

Provide a Coturn executable. Linux installations can use their packaged version.
The repository's pinned Coturn derivation is marked broken on macOS; the fixture
was tested using an isolated build of its pinned 4.9.0 source with existing native
OpenSSL, libevent and SQLite development libraries:

```sh
COTURN_BUILD=/tmp/replay-coturn \
bash tests/replay_turn/build_coturn.sh
```

`build_coturn.sh` prints the executable path. It changes no system installation.
`COTURN_SOURCE` supplies a pre-fetched source tree; otherwise Nix fetches the
pinned source. `COTURN_PREFIX` defaults to `/opt/local` for the tested native setup.

```sh
TURNSERVER=/tmp/replay-coturn/bin/turnserver \
nix develop --command bash tests/replay_turn/run.sh

TURNSERVER=/tmp/replay-coturn/bin/turnserver REPLAY_PREBUILT=1 \
REPLAY_TURN_PROTOCOL=tcp \
nix develop --command bash tests/replay_turn/run.sh

TURNSERVER=/tmp/replay-coturn/bin/turnserver REPLAY_PREBUILT=1 \
REPLAY_TURN_SCENARIO=auth \
nix develop --command bash tests/replay_turn/run.sh

TURNSERVER=/tmp/replay-coturn/bin/turnserver REPLAY_PREBUILT=1 \
REPLAY_TURN_SCENARIO=outage \
nix develop --command bash tests/replay_turn/run.sh

TURNSERVER=/tmp/replay-coturn/bin/turnserver REPLAY_TURN_GAME=scrapyard \
nix develop --command bash tests/replay_turn/run.sh

TURNSERVER=/tmp/replay-coturn/bin/turnserver REPLAY_TURN_PROVIDER=1 \
nix develop --command bash tests/replay_turn/run.sh
```

Run these serially: the fixtures use relay ports 53000–53100. Cavecrawl is the
default game; run its normal relay gate before the authentication scenario, which
uses its built export. `REPLAY_PREBUILT=1` requires current previously built game
artifacts. Set `REPLAY_TURN_OUT` to retain results at a chosen path.

UDP/TCP selects the browser-to-TURN transport. Relayed peer traffic still uses
the browser's WebRTC/DTLS data-channel stack. The selected candidate's
`relayProtocol` must match the requested transport. The normal gates run menu
enrollment, simultaneous-room isolation where included by the game fixture,
gameplay, host migration and fresh-process rejoin. Scrapyard additionally checks
the asset preparation barrier and active-combat checkpoint.

The authentication scenario gives the guest an intentionally wrong TURN password.
It requires a candidate error, no connected candidate pair and no gameplay entry.
A fresh process then uses correct ICE settings with the same stored membership,
registers a newer incarnation and joins through the relay. This is not a general
relay-outage/restart test.

The separate `outage` scenario retains the coordinator and game processes, stops
and restarts the relay, and checks a new relay-selected connection, unchanged
identity/epoch/inventory and a new authority-confirmed guest action. It requires
the current Cavecrawl export. `REPLAY_TURN_DOWNTIME_MS` selects 1,000–30,000 ms of
deliberate downtime before relay startup; actual downtime includes startup time.
The same fixture can run with UDP or TCP relay transport. See
[RTC continuation](../../replay/godot/transport/rtc-recovery.md) for the reconnect mechanism.

## Evidence handling

The browser probe observes real constructors and calls `getStats`; it does not
substitute peer connections, candidate pairs or payload traffic. Reports include
candidate types, relay protocol and byte counters, omitting IPs and credentials.
Coturn's verbose allocation/channel logs provide independent relay-side evidence.
Never copy `ice.json`, `turn.conf`, credential databases or browser profiles into
published results. Screenshots from the game fixtures mask party invite text.

Configuration validation runs independently:

```sh
nix develop --command bash tests/replay_turn/config_run.sh
```

It checks bounded ICE JSON, server/URL/credential structures, relay-only requirements,
owned configuration strings and propagation into Room options, plus WASM compilation.

The authoritative contracts are
[Coturn's configuration](https://github.com/coturn/coturn/blob/master/examples/etc/turnserver.conf),
[Godot's connection API](https://docs.godotengine.org/en/stable/classes/class_webrtcpeerconnection.html),
and the browser's [selected-pair statistics](https://www.w3.org/TR/webrtc-stats/#dom-rtctransportstats-selectedcandidatepairid).
See [recorded results](../../docs/replay/results/turn-relay-2026-09-07/README.md) for
actual acceptance and the remaining public deployment limits.

The [UDP datagram fault gate](../replay_turn_faults/README.md) adds a bounded
multi-client loopback proxy and Slopball planned/crash recovery checks under actual
Chrome-to-TURN packet delay, loss and duplication.
