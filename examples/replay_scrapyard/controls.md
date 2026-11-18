# Controls and discrete intents

Movement, aim, held fire and revive use sampled controls: values captured for
each scheduled simulation step. Discrete Replay actions instead request individual
operations and receive an accepted or refused result. The current Godot
driver submits dash as `Action{kind=.Dash, aim=direction}`. A versioned
`dash_schedule()` selects receipt-time delivery for dash and turret mount/release; other actions retain
scheduled timing. Receipt-time delivery queues a valid request for the next
available authority tick in per-seat order; the client's proposed tick does not
choose that execution time. The comparison fixture explicitly chooses receipt timing for
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

The reusable [action-intent helper](../../replay/godot/input/intents.md) owns the
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
future movement ticks. All dashes use this action path, with the same speed,
cooldown, event identity and counter rules. Continuous controls have no dash bit.
