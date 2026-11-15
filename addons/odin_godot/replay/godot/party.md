# Party setup shared by games

`Party` durably stores room enrollment requests and credentials, selects recent
rooms, issues invites, and configures Room. Cavecrawl, Scrapyard, Speedball, and
Quickdraw use it. Their scene code supplies menus, game options, and recovery
prerequisites. The game retains responsibility for simulation, loadouts,
progression, and assets required to prepare a checkpoint.

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

The service URL determines storage slot and reference keys. These keys and the
enrollment/cursor formats remain compatible with Cavecrawl's original online
implementation, so existing records retain their identities. Configure the
namespace, content, and exact service URL in the application. `Party_Storage` supplies
native slot selection and recent-reference CAS callbacks. The optional
`provision_sqlite.Party_Store` owns a database connection and a copied path, and
returns those callbacks.

Native storage callbacks and TLS objects must outlive their borrows. Configuration
strings are copied. Closing releases connections, profile operations, owned strings
and the retained TLS reference. Browser CAS and native CAS retain their observed
revision; conflicts do not refresh merely to overwrite another window's choice.

Games that allow separate players in multiple browser tabs can opt into
`Party_Config.browser_seats=true`. Party first acquires an exclusive Web Lock
for a durable seat in the namespace/service scope, then opens its IndexedDB
enrollment and Recent keys. Seat zero uses the original keys, preserving saved
crews. Other live tabs use `.seatN` suffixes, so joining the same room cannot
adopt the first tab's credentials or overwrite its Recent selection. Native
storage and the default browser mode remain unchanged.

A per-tab `sessionStorage` hint remembers the seat across reloads. Duplicated
tabs may copy that hint, but the exclusive lock forces a different seat while
the original is open. Closing Party or the document releases the seat; a fresh
tab chooses the first free seat, including the original saved crew at seat zero.
The hint contains no room credentials. Up to 32 seats are available per scope;
unavailable Web Locks/session storage or exhausted seats fail before credentials
are opened. Keep Party alive for the entire Room lifetime and close Room before
Party. Refresh all open tabs when updating from the older shared-identity build.

`party_open(&party, config, allocator)` optionally selects the allocator for its
entire lifetime. Party retains that choice for later frames, enrollment retries
and close. Close it before destroying the borrowed native store or allocator.
This does not create a managed lifetime for arbitrary storage callbacks: their
stable user data and code must still outlive Party. Strict native Box3D SDKs can
select an explicit static SQLite archive with `-define:REPLAY_SQLITE_LIBRARY=ABS`
while preserving the normal `system:sqlite3` default for other applications.

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

### Optional five-character room codes

Cooperative games may set `short_codes=true` with `invite_role=.Player` and
`invite_uses` from 1 to `SHORT_CODE_MAX_USES` (8). With one use the code seats one
guest; a party game that seats several players with one code sets more, and each
guest joins with the same five characters until the uses run out. This uses the provision layer's short-code format v1, while
keeping the existing Room wire protocol and durable enrollment. Create derives
the room locator from a fresh creator claim's code. A collision cannot replace
the server's creator or adopt another local enrollment. Display `code[:code_count]`
after `invited`; the default long-ticket mode still returns its original 85 bytes.

Parse a user-entered code with `short_ticket_parse(text, content)`. The explicit
Watch door uses index 1 and a separately registered `creator_short_invite(record,1)`.
Both use the same five-character room code, with distinct single-use invitation
secrets. Existing long tickets and stored guest enrollment remain usable. A
creator rejoining an older long-ticket room retains that format.

Short codes deliberately have 25 bits of invitation entropy and are for casual
Player enrollment, not administrative or trusted-host credentials. Creator claims
and member keys remain independent 256-bit secrets; no membership credentials are
shortened. The existing TLS, global/per-peer limits, use counts, revocation and
CAS checks remain in force. The default format and other games are unchanged.

Scrapyard keeps its personal progression token and profile file/IndexedDB record
separate from the room token. Changing parties therefore does not create another
progression identity. Its local profile still supplies the saved name, loadout,
cores and parts under the existing co-op profile rules. Its asset preparation
callback still verifies every spray dependency before acknowledging a takeover
checkpoint. The game implements both policies separately from Party.

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
