# Durable Room checkpoints

`room_save(&room)` starts an asynchronous publication of a live host's state to
the configured checkpoint service. `room_frame` owns status lookup, snapshot
capture, transfer and completion while gameplay, authority renewals and ordinary
successor replication continue.

```odin
// Optional automatic publication; zero keeps saves manual.
options.checkpoint_interval_ms = 10000
// The default requires verified WSS. Explicit local development may use loopback WS.
options.checkpoint_local_development = local_development

// After room_open, call room_frame normally. A menu can also request a save:
error := replaygd.room_save(&room)
// None means requested. A durable receipt arrives asynchronously:
if room.save.phase == .Saved {
    saved_tick := room.save.publication.point.archive.tick
}
```

The service must support the deployment's content/model and dependency policy.
`checkpoint_assets` declares/validates external dependencies and `checkpoint_cache`
supplies their bytes. Room publishes a [complete package](../provision/checkpoint/assets.md)
when dependencies are present; missing bytes prevent publication.
Plain remote WebSocket
and ENet control are refused for publication; verified WSS is supported, with an
explicit loopback WS development opt-in. `Party_Config.checkpoint_interval_ms`
passes the interval into its Room options and retains Party's existing local
development choice. Valid automatic intervals are 1–120 seconds.

## State and lifetime

- `Checking` reads the latest durable publication revision. A signed `Missing`
  response permits the first publication. Other status failures do not capture or
  upload a new checkpoint.
- `Uploading` owns a complete immutable prepared checkpoint. Room captures the
  current world after status completes, derives the next archive sequence in the
  current epoch, and publishes against the observed revision. At most one operation
  is active. A second manual request returns `Busy`.
- `Saved` names a durable, authenticated publication. `completed` counts successful
  receipts, including recovery of an exact earlier committed attempt.
- `Interrupted` means authority/connection/registration changed or the control
  connection was explicitly paused. `Failed` includes service errors and timeouts.
  An interrupted/failed upload may already have committed: `uncertain` records
  that ambiguity. Neither state asserts that the previous durable save was lost.

The owned prepared bytes survive an interrupted upload until the next attempt or
Room close. A retry first reads current status. If the exact publisher/Point is
already stored, Room acknowledges it without publishing again. Otherwise it records
the latest authenticated publication and captures current state for a new attempt.
This does not claim that an older, now-superseded request never committed.

`publication` always describes the latest durable metadata observed; it may be from
a previous host. `attempts`, `serial`, `last_started`, `error` and `uncertain` expose
progress. Metadata and operation counters survive control reconnects within the
Room lifetime. Closing Room releases the checkpoint client and prepared bytes.

Only a registered live host may start or continue publication. Followers, handoff
and fenced phases cannot capture a new save. A role/epoch/coordinator-generation
change closes the old transfer. The service still independently enforces current
identity/nonce/connection binding, hosting permissions, live lease, typed model
validation, full Record/publication CAS and final commit authorization.

Automatic saving starts when the Room first becomes eligible, then keeps at least
the configured interval between starts. It never overlaps operations or blocks
play waiting for a result. Persistent save errors remain observable and subsequent
automatic attempts follow the same interval.

## Shared control I/O

After status resolves, Room obtains a fresh successful authority renewal before
capturing/packaging a new checkpoint. The expensive work therefore starts with a
refreshed lease rather than the remainder of the status round trip. Existing lease
duration and fencing rules remain unchanged.

Room uses one bounded control receiver to dispatch checkpoint and authority
RPC packets before pumping outgoing RPC work. The borrowed RPC transport copy has
reads/polling temporarily disabled during that outgoing pump, then restored. It
cannot drain checkpoint traffic accidentally. Existing control pause behavior is
preserved; checkpoint work stops while ordinary lease expiry remains in force.

`room_control_pump` and `room_save_frame` are lower-level driver steps used by
`room_frame` and transport-independent lifecycle tests. Normal games should call
`room_frame` once; they should not additionally drive these steps or drain the
control transport independently.

## Integration and bounds

Cavecrawl's online host can use its existing save action/F5 or the party checkpoint
button. `REPLAY_CAVE_ROOM_CHECKPOINT_MS` opts into automatic publication (zero by
default); browser launch parameters use `room_checkpoint_ms`. Solo/local save slots
remain separate. The native party test verifies both the original host's publication
and the successor's newer-epoch publication, then decodes the actual stored inventory.

The browser party test exercises both publications through Room during
RTC play, alongside a second isolated room, migration, and durable rejoin. It uses
explicit loopback development WS. A fresh native reader validates the saved
successor inventory; this is not production browser TLS/deployment evidence.

These operations save simulation checkpoints and their declared packaged asset
bytes. Personal profiles remain separate. Publication does not supply a restore
grant or guarantee preservation after the reported saved tick. Room separately drives
[fresh-process party restoration](room_restore.md), with native/browser Cavecrawl
acceptance. Broader asset profiles and other games require separate acceptance. See the
[service contract](../provision/checkpoints.md) and
[checkpoint transport](../provision/checkpoint/README.md).
