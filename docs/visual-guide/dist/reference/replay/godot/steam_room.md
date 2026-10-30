# Steam destinations for Room recovery

Use the Steam gameplay backend with Room when coordinator-approved recovery
needs to reconnect through Steam. The coordinator can use ENet or WebSocket.
It retains the same lease, complete-checkpoint and authority-fencing rules.
Steam is native-only; Web builds still require RTC gameplay.

Initialize and retain a `Steam_Runtime`, then select `session.backend = .Steam`
and set `session.steam.runtime` plus its virtual port. Room derives its registration
endpoint from the runtime's actual Steam ID. A supplied registration endpoint must
match; a peer for another Steam ID cannot become the approved local authority.

```odin
// runtime was initialized explicitly and will outlive room.
options := room_options_from_your_admission_service
options.session.backend = .Steam
options.session.steam = STEAM_CONFIG
options.session.steam.runtime = &runtime
options.session.steam.virtual_port = 0
// Room supplies this endpoint for process registration. Provisioning can use
// the same helper when initially enrolling this member.
options.registration_endpoint, _ = steam_endpoint(runtime.steam_id, 0)
err := room_open(&room, initial, model, options)
```

`steam_endpoint(id, virtual_port)` produces a value-owned coordinator endpoint with
host text `steam:<decimal-id>:<decimal-virtual-port>` and sentinel port 1. The format
is explicit and canonical, supports the full nonzero u64 ID and u16 port range
including port zero, and does not reinterpret existing ENet/RTC endpoints.
The coordinator's authenticated grant is the only source of a remote host ID.
Room applies it at initial admission, redirect, takeover and old-host return;
published restore uses the same validated transport configuration.

Each connection needs a fresh `SteamMultiplayerPeer`. Room rejects a one-off
`Steam_Config.peer` because its caller ownership cannot safely span later recovery.
Normally the adapter creates the engine peer itself. Applications with custom
bindings can set `peer_factory(user) -> gd.Variant`: return an owned Variant holding
a newly created peer. The adapter retains the peer and destroys the returned
Variant on every success/failure path. The factory user and runtime must outlive
Room. Session retains those factory settings but never retains a borrowed one-off
peer in its saved options.

A room uses one gameplay backend. Provision all Steam-host candidates with this
Steam endpoint format; this does not implement mixed Steam/ENet/RTC participants
in one room. A granted endpoint in another format is refused rather than guessed.

The endpoint selects transport; it does not grant game membership or successor
permission. Provisioning must still bind the enrolled token/identity, and only
explicitly trusted members may receive complete authority archives. Native Party
can use `steam_endpoint` for its configured admission endpoint and pass Steam
Session options into the ordinary Room setup.

The local API-contract fixture validates lifecycle wiring, not Valve networking.
Live multi-account Steam acceptance, lobby/invite integration, SteamGameServer
support and broader deployment/platform coverage remain open roadmap requirements.
