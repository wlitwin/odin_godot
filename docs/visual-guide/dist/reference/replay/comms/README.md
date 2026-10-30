# Session communications

`replay/comms` supplies bounded host-ordered chat and positional markers outside
simulation. `World`, action/event schemas and gameplay checkpoints stay unchanged.
The Godot adapter uses the existing gameplay connection and recovery router.

```odin
import co "godot:replay/comms"
import rgd "godot:replay/godot"

chat: co.Comms // keep at a stable address beside Session/Room
assert(co.init(&chat))
options := rgd.SESSION_OPTIONS
assert(rgd.session_comms_enable(&options))
// Open Session/Room using options.

// After each Session/Room.frame, including reconnect/fenced frames:
rgd.session_comms_frame(&chat, &session)
co.say(&chat, "found a torch")
co.mark(&chat, 1, {330, 210, 0}) // application-defined nonzero tag
for {
    marker, found := co.poll_marker(&chat)
    if !found {break}
    // Present once; expire using the presentation clock.
}
for {
    receipt, found := co.poll_result(&chat)
    if !found {break}
    // receipt.submission identifies the local submission; value is owned by value.
    // Present failures, and retain/repopulate the original text if desired.
}
// Render chat.lines[:chat.line_count] when chat.history_serial changes.
// co.destroy(&chat) before releasing its containing owner.
```

The caller's text and marker positions are copied into value payloads. Text is
clipped at a UTF-8 rune boundary to 240 bytes. Empty/malformed text and control or
line-separator characters fail validation. The UI should render plain text; the
Cavecrawl view explicitly disables BBCode. Each line stores the admitted seat, token hash and optional approved display name
separately from text. There is no client-supplied speaker field. Display names, permissions and game-specific position checks remain application policy.
Pass authority-observed `[]lobby.Name` values to `session_comms_frame` to stamp
names at delivery creation. Existing lines keep their original name after a rename;
changing display metadata does not reset connection retry/acknowledgement state.

A client sends one numbered request at a time and waits for its result. Retries
repeat the same request identity. The host stamps the speaker from the current
admission roster, orders accepted messages, and echoes them to the sender through
the same delivery path. Duplicate acknowledgements cannot consume a later request.
Observers can chat but cannot create positional markers. Only the authority can
call `system` to publish an unattributed system line.

`None` from `say`/`mark` means queued locally. Drain `poll_result` for each
submission and its copied payload; the authority may reject with `Rate_Limited` or
`Capacity`. Unread results retain their reserved submission slots, so they cannot
be overwritten. `last_result` / `result_serial` also summarize the latest outcome. A
rejected submission is not silently promoted to a delivery. The default limit is
four messages of burst capacity, refilling at two per second for each sender.
System lines bypass that per-sender bucket, but still obey queue capacity.

## Bounds and transport

The component retains 64 chat/system lines, eight local submissions, 32 pending
marker notifications and 128 outgoing deliveries per connection, for at most
32 connections. Its peer storage is allocated once at initialization. Rendering a
smaller window of history is a UI choice. Marker overflow is counted explicitly.
A broadcast reserves capacity at every current recipient before committing to the
host's history. A slow recipient can therefore cause new submissions to receive
`Capacity`; it cannot silently lose an accepted broadcast from that queue.

Traffic uses a canonical version-2 communications schema envelope, kind `0x434d`, current content,
room, authority epoch and per-recipient connection generation. Source transport
identity comes from the adapter. The receiver validates all of these, the request
direction, payload and speaker rules. Checksums detect corruption; they are not
cryptographic authentication. The authority is trusted to order and stamp messages.

Comms gets an independent application lane through `recovery.link_add_application`.
It can coexist with the original application lane used by Session assets. The
router's total budget and gameplay reserve still apply. Version 2 adds stamped names and does not accept version-1 communications packets.
Enable the same service on participating builds; optional service protocols are not negotiated with older
builds. Do not attach two consumers to the same route.

The pure `configure`/`frame` API accepts an explicitly authenticated roster. The
Godot facade derives that roster from live Session connections and checks the
current permit before pumping. Applications using the pure API must provide the
same admission, authority and clock discipline. No received message grants state
ownership, a gameplay action or authority to migrate.

## Recovery semantics

Local scrollback survives a same-room authority change. A successor starts its new
epoch's ordering and catches new connections up from the chat lines it actually
received. Late joiners receive chat history, not expired marker events. Local
history deduplicates using increasing `(epoch, sequence)` identities; reconnect
never appends older catchup lines after newer lines already displayed. Changing
room/content clears the local history. Authority epoch regression is rejected.

A same-connection gameplay resync keeps communications active: it replaces the
gameplay baseline, not the admitted communications binding. Queued requests,
reliable deliveries and their sequence frontier survive that resync. A client
still needs a previously accepted world/generation and any required valid permit.

Pending local submissions are retired on fencing or scope/connection replacement,
with `Scope_Changed` and `scope_drops` explaining the loss. Already received lines
remain visible. This is **ephemeral session history**, not a durable messaging
service: a killed host can lose lines that never reached its successor. Fresh
process save/resume does not reconstruct chat. Persisting or moderating chat,
private/team channels, identity display names and account services need their own
explicit policies. Durable gameplay consequences belong in the simulation or a
committed service, not in chat callbacks.

Tests cover ordered echo, marker delivery, malformed UTF-8, clipping, spoofed
speakers, stale connections, duplicate acknowledgements, rate/capacity limits,
bounded late-join history and fencing. Cavecrawl adds real native and browser
integration gates alongside its normal gameplay/migration tests.


## Observer display names

An observer can attach a validated display label to a chat submission when its
admitted `Binding.observer_name_allowed` capability is enabled. The sender captures
the name with the queued payload, so renaming does not alter retries or historical
entries. Empty labels retain the ordinary fallback. Names are bounded UTF-8 single
lines under the existing lobby-name validation rules; they are not unique or
verified account identities.

The authority always supplies the speaker identity and seat from the admitted
binding. A player cannot override its authoritative name through this observer
path, and observer markers/system-message claims remain forbidden. A configured
authority name still supplies the fallback when a request has no label.

Godot's Session adapter negotiates Features bit 1024 in both directions before
allowing these labels. `session_comms_frame` accepts an optional `observer_name`
separately from the player-seat name array. Old clients keep empty name claims;
new clients keep that behavior when an old server does not confirm support. Packet
version 2 and its schema are unchanged: this uses the existing Entry.name field.
Reconnect and authority replacement clear negotiation until the new handshake.
