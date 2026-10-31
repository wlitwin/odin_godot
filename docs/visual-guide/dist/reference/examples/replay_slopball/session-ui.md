# Slopball session UI

Run `nix develop --command bash examples/replay_slopball/play.sh` for Solo, Host,
Join and Watch controls with name/address/port fields. The default port is 49570.
Host waits for the first connected player to Start; Solo starts automatically.
`RSL_PLAYERS` sets the minimum count and `RSL_GOALS` the winning score. Explicit
`RSL_ROLE` launches retain automatic start for existing gameplay fixtures.

WASD moves and Space kicks. Enter opens chat; Escape releases focus while keeping
the draft. Typing clears gameplay button edges and movement intent, while the ball
continues its owned solver/observation path. Chat text is literal. A named observer
negotiates its label while retaining seat zero. Hold Tab for authoritative names,
teams, score and measured round-trip time. Departed rows remain until reused.

Leave returns to the menu and clears local chat/presentation state. The game keeps
its scene bodies but resets their driver/sample state, freezes them and disables
collision while disconnected. Rejoin reseeds from current authority state and
restores the collision layers/masks authored in the body scenes. It keeps identity,
seat and match score instead of reopening a new match.

Native identity/name preferences use `user://replay_slopball_identity` and its
adjacent `.name` file. `RSL_PROFILE` selects a separate prefix. Explicit tokens,
bots and `RSL_PERSIST=0` bypass storage for fixtures. Malformed name data blocks
connection and is preserved. A migration epoch clears name-submission bookkeeping
so a rolled-back declaration can be submitted again.

Names and manual start are replayable game values/commands. Waiting rejects solver
observations in the simulation rule as well as disabling local control. Content B24
(`0x52534c4f50423234`) identifies the changed world/action schema; B21/B22/B23 peers and
checkpoints are incompatible without an explicit conversion.

The established Body2 prepare/commit handoff, velocity seeding and confirmed goal
policies remain in use. This UI does not add solver rollback, replay contact
caches or provide netgraph parity. See [Party and browser play](online.md) for service-backed sessions.
Original Slopball and the separate 3D port remain intact.

## Native checkpoint saves

The menu selects a save file; the default is `user://slopball.replay`, configurable
with `RSL_SAVE`. Save/F5 is available to a standalone native authority. A failed
staging write preserves the prior completed file. A successful later save replaces
it. Clients and configured Rooms cannot use this direct file-save path.

Resume solo/host requires the profile of the saved host. It installs the exact
checkpoint in a new epoch, then the owner-stream driver rebinds and seeds the local
solver from authority state before publishing fresh observations. Other saved peers
are scheduled to leave; the same profiles can rejoin their reserved seats. Match
settings, names, score, ownership scopes, pose/momentum and movement baselines are
restored. Shared file-resume policy retires pending commands; it is separate from
coordinated migration.

Missing, malformed/incompatible, wrong-owner, protected-policy and exhausted-epoch
saves are refused without replacing existing data. Native chat history is not part
of the game checkpoint, and solver contacts/joints are not serialized. Public deployment remains further port work.
Party Save/F5 publishes through the service, separately from these native files. This adds no new model schema.

## Play again

After a match finishes, its first connected player can choose **Play again** when
the minimum roster is present. This is a round-scoped command inside the same
session. It rejects guests, observers, stale round numbers and exhausted revision
counters. Names, seats, connected/departed flags and match settings survive.

The reset clears scores, per-match counters, player/ball poses and momentum,
challenges and pending offers, and starts a new kickoff hold. Every body receives
a newer ownership revision; old samples and old offer scopes cannot publish into
the new match. The reset is built as a candidate so exhaustion cannot partially
change the world. The standard Body adapter reseeds from those new scopes.

Gameplay events also identify their round, and new-round presentation ignores old
goal effects. The UI resets local kick/button/report state without reconnecting.
The original game interface has no Play again control; this is a Replay addition.

## Browser-local checkpoints

Browser Solo uses named slots instead of native file paths. The default slot is
`pitch`; the `save_slot` URL parameter selects another. Names accept 1–48 ASCII
letters, digits, dots, dashes or underscores. Slots belong to the current browser
origin/profile and personal identity; they do not synchronize between devices.

Save/F5 captures the current checkpoint once and reports completion after its
IndexedDB write. Leave is blocked during that write. Resume solo waits for both
identity and slot loading, restores the exact saved world in a newer epoch, and
seeds the local physics bodies before new observations can commit. A URL with
`role=solo&resume=1&save_slot=pitch` uses the same asynchronous loading sequence.

Two tabs cannot silently overwrite each other's progress: a stale revision fails
and keeps the committed slot. Unreadable slots and malformed identity data are
preserved. Choose another valid slot or reload after a conflict; Resume is disabled
when no readable checkpoint is available. Play again can be saved in the same slot.

Native file saves keep their existing host-profile policy. Party Save/F5 publishes
through the service and does not create or replace a browser-local checkpoint.
Local slots store game state, not a promise to preserve cosmetic chat or Godot
solver contact caches. Clearing the browser's site data removes its local records.

See [browser-save results and limitations](../../docs/replay/results/owner-streamed-browser-save-2026-09-14/README.md).
