# Party setup shared by games

`Party` coordinates durable enrollment, recent-room selection, invite issuance and
Room configuration. Cavecrawl, Scrapyard, Speedball and Quickdraw use it; their scene code supplies menu
controls, game options and any game-specific recovery prerequisites. It does not
own the simulation, choose loadouts, store progression or make an asset checkpoint
ready by itself.

## Lifecycle

1. Open a native `Party_Store` if applicable, then call `party_open` with the
   service/content, storage namespace, advertised endpoint and explicit invite
   role/use count. Browser storage is built in; native SQLite remains optional.
2. Pump `party_frame` until `recent_loaded`. Choose Create, Join with a parsed
   ticket, or Rejoin. `party_begin` creates or loads the per-room enrollment slot.
3. Continue pumping. The request and recent-room reference reach durable storage
   before transmission. The returned credential reaches durable storage before
   `party_grant` exposes it. Storage/transport errors remain explicit.
4. Use `party_room_options` to configure the game's Room. It retains challenged
   process registration, copies the stable room credential and selects trusted
   successor discovery. Add game-specific callbacks before `room_open`.
5. Close Party before its borrowed native storage. Room separately owns any TLS
   reference it retained during open.

```odin
party: rgd.Party
cfg := rgd.Party_Config{
    service = service_url, namespace = "my-game-rooms", content = GAME_CONTENT,
    endpoint = gameplay_endpoint, storage = native_storage,
    invite_role = .Trusted_Peer, invite_uses = 3,
}
ok := rgd.party_open(&party, cfg)
// Wait for party.recent_loaded, then handle the player's menu action:
ok = rgd.party_begin(&party, .Create)
// In _process:
rgd.party_frame(&party)
grant, ready := rgd.party_grant(&party)
if ready {
    options, valid := rgd.party_room_options(&party, session_options)
    // Install the game's preparation callback, then room_open(..., options).
}
```

Check the returned booleans, `failed`, `error`, and `protocol_error`. `party_message`
provides a short default explanation for menus. The caller must prevent competing
game starts while an attempt is active and avoid calling `room_open` repeatedly.
The helper does not silently close an existing game session to start another one.

## Storage and permission rules

The service URL hashes to the same slot/reference keys used by Cavecrawl's original
online implementation. The helper preserves its enrollment/cursor formats, so existing
enrollment records retain their identities. Namespace/content and an
exact service URL remain the application's configuration. `Party_Storage` supplies
native slot selection and recent-reference CAS callbacks. The optional
`provision_sqlite.Party_Store` owns a database connection and a copied path, and
returns those callbacks.

Native storage callbacks and TLS objects must outlive their borrows. Configuration
strings are copied. Closing releases connections, profile operations, owned strings
and the retained TLS reference. Browser CAS and native CAS retain their observed
revision; conflicts do not refresh merely to overwrite another window's choice.

Invites use the existing reproducible creator recipe with index zero and the
configured role/use count. Guests with a ready credential need no provisioning
socket to rejoin. A creator retries its invitation after restart; a **correlated
invite refusal does not revoke an already stored credential**. In that case Party
can become ready with `invited=false` and `invite_error` set. The game can still
join with its credential, and must not display a usable invite that was refused.
This is distinct from a transport failure where the operation's result is unknown.

`Trusted_Peer` is an explicit co-op disclosure/hosting decision. Ordinary player
invites remain available; dedicated infrastructure enrollment stays with the
trusted provider. `party_room_options` enables backup reception only for a granted
trusted host. Authority still requires the coordinator's current lease, and the
Room still validates the authenticated roster and process incarnation.

## Game-specific ownership

Scrapyard keeps its personal progression token and profile file/IndexedDB record
separate from the room token. Changing parties therefore does not create another
progression identity. Its local profile still supplies the saved name, loadout,
cores and parts under the existing co-op profile rules. Its asset preparation
callback still verifies every spray dependency before acknowledging a takeover
checkpoint. The shared helper does not replace either policy.

Defaults require verified WSS. Native private CA options and explicit loopback WS
development mode remain supported. Public TLS/TURN deployment, general invite
rotation/revocation intent storage, account/device transfer, room retirement and
other native storage platforms remain separate work. See the
[enrollment contract](../provision/enrollment.md),
[Cavecrawl flow](../../examples/replay_cavecrawl/online.md),
[Scrapyard flow](../../examples/replay_scrapyard/online.md), and
[recorded integration evidence](../../docs/replay/results/scrapyard-party-2026-09-07/README.md).

`Party_Config.ice_json` carries validated deployment ICE settings into Room,
including relay-only TURN configuration. The string is copied during open and
retained across Room transitions. See [ICE configuration and relay evidence](transport/ice-deployment.md).

Alternatively set `relay_credentials=true` to use the authenticated
[relay provider](../relay/README.md). Party obtains credentials before becoming
ready, refreshes them while pumped, and supplies a lifetime-checked callback to new
RTC connections. Do not combine this with static `ice_json`. Close Room before
Party. Invitation completion alone does not mean relay setup has finished.


[Speedball's native party flow](../../examples/replay_speedball/online.md) also
exercises invited observers. Room preserves a requested `Session_Role.Observer`
when opening the following session; redirect/reconnect keeps that spectator flag.
Speedball disables checkpoint reception for observers, and automatic successor
selection considers connected player seats. The watch preference does not revoke
the underlying invite's trusted membership permissions.

[Quickdraw parties](../../examples/replay_quickdraw/online.md) exercise native
create/join/rejoin and browser combat recovery, observer permissions, fresh host
return and original/successor checkpoint publication through the same component.
