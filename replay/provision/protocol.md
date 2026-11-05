# Create/join protocol and Godot connection

Use this protocol to create rooms and issue, consume or revoke invitations
through the admission backend. It provides canonical request/reply messages, a
bounded room hub and a Godot client connection requiring verified TLS by default.
Native tests create rooms, issue/use invites, authenticate authority RPCs,
reconnect, and recover the same credentials after a server kill/restart. The
[recorded gate](../../docs/replay/results/provision-tls-2026-09-07/README.md) separates
this local TLS acceptance from public deployment and browser enrollment.

## Server ownership

`Hub_Config` selects one game content ID, the policy for new rooms, and a resident
room limit (1–32, default 16). `hub_open` receives the complete existing bundle set
before accepting traffic. `sqlite.load_all` reads that inventory transactionally
into a caller-bounded destination; excessive, corrupt or wrong-content rows fail
without returning a partial inventory. One service owns this room set. Multiple
instances sharing the database reject stale writes from one another. This does
not provide a highly available coordinator cluster.

New cooperative rooms use a client-supplied nonzero room ID and fresh 32-byte
creator claim. Retain both before sending. A collision with another creator's room
fails the claim check. Retrying a successful create with the same room, claim and
endpoint returns the same credential; changed endpoints fail. Content and policy
come from server configuration, not client permission fields. Existing rooms retain
their persisted policy after restart.

Public creation in a **dedicated** deployment is denied: its bootstrap credential
belongs to infrastructure. Trusted deployment code must construct and persist such
rooms before public admission starts. Ordinary-player invites remain available;
trusted-player invites remain denied. A previously provisioned dedicated creator
claim is an explicit infrastructure capability.

Creation persists before publishing a room or grant. An uncertain create commit
stops the whole hub from serving until startup reloads its inventory. An uncertain join follows
the room owner's existing fail-closed rule. Unknown-room requests neither load
storage nor trigger coordinator generation changes.

Poll the transport once per update and bound its ingress loop. Pass provisioning
packets to `hub_receive` and authority RPCs to `hub_control_receive`. Both can share
a connection; authority still checks its MAC, nonce/incarnation, request frontier,
lease and own budget. `hub_room` exposes a room to trusted embedding code. RTC
rendezvous can bind to that room's service; multi-room signaling routing and game
frontends still need integration.

Admission has a global burst/rate of 32 requests and 32 requests/sec, and per
connection a burst of 8 and 4 requests/sec. It retains at most 128 peer budget
entries, reusing entries after 10 seconds of inactivity. The transport must also
bound handshakes, connections, ingress and buffers. These limits do not replace
account authorization, per-user creation quotas or room retirement. Rooms remain
resident for the hub's lifetime and persist across restarts.

### Optional trusted retirement

Embeddings with an ephemeral end/rehost policy can provide `creation_guard`,
`reclaim` and `lifecycle_user` to `hub_open`. Defaults preserve the resident-only
contract above. The reclaim hook runs only after a validated, budgeted Create
finds no free slot. `hub_room_idle` requires an idle interval and no live lease;
the embedding must additionally protect physical connections and detach borrowed
signaling/checkpoint references before calling `hub_archive_room`.

The SQLite adapter atomically archives the exact expected private bundle and
removes it from the resident table. Archived IDs stay reserved through the
creation guard and storage commit check. A failed CAS/archive cannot publish a
replacement room; uncertain storage fences the hub. The wire protocol and bundle
schema are unchanged. The sample service enables this only for explicitly opted-in
cooperative deployments with checkpoint publication disabled.

## Wire and retry contract

The optional human-entered **short room code v1** is a client-side recipe using
this existing protocol. `short_code` maps a random creator claim and content ID
to five characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. Separate HMAC-SHA256
domains derive the room locator and two invitation secrets (crew index 0, watch
index 1). `creator_short_invite` registers only `.Player`, one-use invitations;
the normal server authorization checks still require the full creator claim.
Codes are case-insensitive and trimmed at the edges. Other input is rejected.
The independent member/creator credentials, message shapes, protocol version,
stored bundle schema, request budgets and long `RP1` ticket format are unchanged.

Protocol version 1 uses canonical envelopes: request kind `0x5051`, reply kind
`0x5053`, epoch 1, tick zero and the configured content ID. Fixed-size messages
fit within `PACKET_BYTES` (1024). Wrong schema/version/content, noncanonical fields,
invalid enums and wrong sizes are rejected before admission mutation.

| Request | Required fields beyond room/content/version/verb |
| --- | --- |
| Create | `claim`: creator secret; `endpoint`: advertised gameplay endpoint |
| Invite | `claim`: creator secret; `ticket`: new invite secret; `role`; `uses` |
| Join | `claim`: guest's fresh retry secret; `ticket`: invite secret; `endpoint` |
| Revoke | `claim`: creator secret; `ticket`: invite secret |

Unused fields must be zero. Replies contain the SHA-256 hash of the exact request
and matching room/content, plus a grant, ticket or error with empty result values.
Clients reject unrelated or malformed replies. Retrying the same committed
request through a new client or transport connection returns its saved result.

The generic `Client` borrows a transport and clock. It keeps one request pending,
retries identical bytes every 250 ms, and returns `Not_Ready` after 10 seconds
without a correlated reply. Timeout is an uncertain outcome, not proof of failure;
retry the same persisted request. Clock failure/reversal is explicit.
`client.complete` and `client.reply` expose completion. Closing clears owned
protocol buffers/credentials but does not close the borrowed transport.

**This protocol is not encryption.** The embedding must provide authenticated,
confidential transport or an explicitly local test channel. Claims and credentials
are bearer capabilities. Never put them in URLs, logs, gameplay snapshots or
authority backup archives.

## Godot connection and TLS

`replay/godot.Provision_Connection` owns the socket and protocol client:

```odin
connection: rgd.Provision_Connection
err := rgd.provision_connect(&connection, "wss://rooms.example.test/admission")
// Persist room_id and creator_claim before submission. Check every error.
err = rgd.provision_request(&connection, {
    version = provision.PROTOCOL, verb = .Create,
    room = room_id, content = content_id,
    claim = creator_claim, endpoint = advertised_endpoint,
})
err = rgd.provision_frame(&connection) // call from _process until complete
// Consume connection.client.reply only when connection.client.complete is true.
// Persist a successful grant before treating enrollment as recoverable.
rgd.provision_disconnect(&connection)
```

The URL must use `wss://`. Explicit `local_development=true` permits only literal
`localhost`, `127.0.0.1` or `[::1]` with a valid port. Userinfo, misleading suffixes
and non-loopback WS endpoints are rejected. Godot validates remaining URL syntax.
The wrapper reconnects dropped sockets at most every 500 ms, retaining its request.

Optional native `TLSOptions.client` can supply a private CA. Unsafe client and
server options are refused on client connections. Browsers use their trust store;
WASM compilation does not prove browser TLS enrollment. The test fixture installs
no trusted root on the host machine.

`websocket_host(..., tls=server_options)` retains server TLS options and wraps
accepted TCP streams. Handshakes occupy bounded slots and must complete within
the configured deadline before HTTP/WebSocket acceptance. Closing releases open
peers and pending TLS streams. Existing plain WebSocket callers retain their
behavior. Godot documents these underlying
[TLS stream](https://docs.godotengine.org/en/stable/classes/class_streampeertls.html)
and [WebSocket acceptance](https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html)
APIs; fixtures verify the adapter under Godot 4.7.1.

`room_with_grant(options, grant)` validates content/credential shape and copies
room, identity, key and stable game token into `Room_Options`. It keeps challenged
process registration, clearing `provisioned_incarnation` and the session incarnation
hint. Creator member 1 is bootstrap. Connection settings/model configuration remain
game inputs. Membership and hosting permission do not confer a live authority lease.

## Remaining integration

The [client enrollment journal](enrollment.md) persists pending requests before
submission and successful credentials before use, with native SQLite and browser
IndexedDB acceptance. The older TLS fixture still uses predetermined test claims
and fingerprints; the enrollment fixture generates fresh claims and exercises the
actual journal. The [room service](../../examples/replay_room_service/README.md)
and the Cavecrawl/Scrapyard party menus integrate it with per-room RTC signaling and a
reproducible co-op invite. Other game menus, general invite-operation persistence,
public TLS/relay deployment and account/room lifecycle remain work.
Original games and their existing fixture provisioning remain separately runnable.
