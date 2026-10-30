# Slopball3D session UI

`play.sh` now opens Solo, Host, Join and Watch controls with name/address/port.
The default port remains 49580. Host waits for the first connected player to Start;
Solo starts automatically. `RS3_PLAYERS` and `RS3_GOALS` set the minimum roster and
winning score. Explicit `RS3_ROLE` launches retain the automatic fixture path.

WASD moves on XZ and Space kicks with loft. Enter opens chat; Escape releases focus
while preserving the draft. Typing suppresses movement and kick edges while the
owned ball continues its normal solver/observation path. Chat is literal, including
markup characters. Named observers retain seat zero. Tab shows authoritative names,
teams, score and measured ping; departed rows remain until reused.

Leave freezes the bodies, resets their local driver/sample state and disables
collisions while disconnected. Rejoin reseeds current authority state and restores
each scene's authored collision layers/masks. Skin position and quaternion are
restored before reattachment. Identity, seat and match score survive rejoin.

Native identity/name preferences use `user://replay_slopball3d_identity` and its
adjacent `.name` file. `RS3_PROFILE` selects another prefix. Explicit tokens, bots
and `RS3_PERSIST=0` bypass storage. Malformed names are refused and preserved. Name
submission bookkeeping resets after an authority epoch change.

The UI/HUD layers scale to the visible viewport; camera and physics scenes remain
unchanged. Names and manual start are replayable values/commands. Waiting rejects
solver observations at the reducer as well as disabling local controls. Content D4
(`0x52534c4f50334434`) identifies the changed world/action schema. D1/D2/D3 peers/checkpoints
require an explicit conversion; none is supplied here.

The established Body3 ownership handshake, interpolation and solver seeding remain.
This does not replay contact caches/joints or add netgraph parity. Original Slopball3D and the separate
2D port remain intact.

## Native checkpoint saves

The menu selects a save file; the default is `user://slopball3d.replay`, configurable
with `RS3_SAVE`. Save/F5 is available to a standalone native authority. A failed
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
of the game checkpoint, and solver contacts/joints are not serialized. Public deployment remains further port work. This adds no new model schema.

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

See [Party and browser play](online.md) for service-backed invitations, stored
credentials, handoff and publication through Save/F5.

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
