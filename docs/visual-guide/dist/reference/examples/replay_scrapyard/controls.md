# Controls and discrete intents

Movement, aim, held fire and revive remain sampled controls. The current Godot
driver submits dash as `Action{kind=.Dash, aim=direction}`. A versioned
`dash_schedule()` selects receipt-time delivery for dash and turret mount/release; other actions retain
scheduled timing. The comparison fixture explicitly chooses receipt timing for
every action and disables the classifier in its isolated game copy.

**T** captures a generation-checked turret target for mount/release through the
same action-intent helper. Aim/fire operate the mounted turret; movement, dash,
revive and casting are blocked until dismount. See [shared turret](shared-turret.md).

The driver captures a dash direction once it has a readable player state, keeps
the request through queue-capacity or recovery delays, and clears it only after
`issue_action` returns a sequence ID. Sampling movement/fire cannot consume that
pending request. The lobby, spectators, typing and menus discard unsubmitted input, and holding Shift
while leaving an overlay does not manufacture a new press. A request during an
unreadable interval remains latched until the driver can capture its direction.

The reusable [action-intent helper](../../replay/godot/input/intents.md) now owns the
copied payload, pending tickets and recovery bookkeeping. Tickets include their
epoch, so a reused sequence after migration cannot consume an old result.

After queue admission the normal action ledger owns delivery. The driver tracks
confirmed outcomes by sequence, removing each tracked ID once. A game rejection
is a result, not an instruction to retry the dash automatically. `dash_probe`
exposes submitted, confirmed, refused and pending counts for diagnostics. Dash
effects use the existing speculative event and correction/cancellation path.

The authority still checks connection, yard membership, health and cooldown.
Direction is bounded and normalized; zero direction uses the player's current
facing. Actions run after the movement step, so their dash expiry includes ten
future movement ticks. The legacy control path starts its ten ticks immediately.
Both use `dash_start`, the same speed, cooldown, event identity and counter rules.

`Control.dash` remains a compatibility field for already-recorded scheduled
inputs in earlier Replay saves. The current authored driver never sets it. Its
presence does not give those historical inputs receipt-time delivery or a new
action verdict. This preserves their original execution semantics during import
and replay while the new input path uses explicit action results.

Content 47 adds the Dash enum member and timing contract. The offline converter
accepts content 42–47, using frozen old action enums and preserving world state,
pending action IDs/ticks, recorded controls and assets. A newly loaded game does
not silently reinterpret an older save; use the explicit converter described in
[saves](saves.md).

The stress-fire development helper uses the same local origin as ordinary input:
predicted position on a client, current authoritative position on a host. Its
nearest-target census still uses the authoritative enemy observation. This does
not add line-of-sight filtering, target leading, damage changes or guaranteed hits;
cover and stale enemy observations can still produce misses.

`RSY_SNAPSHOT_EVERY=N` (browser query `snapshot_every=N`) sets the requested
snapshot interval in simulation ticks, clamped to 1..30 (default 3). Simulation remains at
60 Hz; three ticks requests 20 snapshots per second. Actual delivery also depends
on backpressure, loss and recipient budgets. This is a local delivery preference,
not a change to gameplay speed or saved world content.

Current content 48 adds [authority-only rewind history](authority-history.md); dash timing remains unchanged.
