# Replay Cavecrawl

This is a **separate, in-progress reimplementation** of the original
[Cavecrawl](../cavecrawl/README.md). Both projects remain independently runnable.
The new version keeps mutable gameplay state in a `World` value. Replay's runner
schedules simulation steps and manages input and history; `replay/godot.Session`
connects that runtime to Godot and the network. Godot scenes display the resulting
state and effects.

The [online party menu](online.md) creates and joins rooms through a
[standalone service](../replay_room_service/README.md), persists credentials,
selects trusted successors automatically and rejoins recent parties. It has
native TLS and browser RTC acceptance; public deployment remains open.

From the repository root:

```sh
# Open the connection menu; choose Solo, Host, Join, or a native saved run.
nix develop --command bash examples/replay_cavecrawl/play.sh

# Listen host and a client, from separate terminals.
REPLAY_CAVE_ROLE=host nix develop --command bash examples/replay_cavecrawl/play.sh
REPLAY_CAVE_ROLE=client nix develop --command bash examples/replay_cavecrawl/play.sh

# Pure gameplay tests, then real Godot solo/co-op acceptance.
nix develop --command bash tests/replay_cave/run.sh
nix develop --command bash examples/replay_cavecrawl/run.sh
nix develop --command bash examples/replay_cavecrawl/network_run.sh
nix develop --command bash examples/replay_cavecrawl/replication_run.sh
nix develop --command bash examples/replay_cavecrawl/save_run.sh
nix develop --command bash examples/replay_cavecrawl/recovery_run.sh
nix develop --command bash tests/replay_migration/run.sh
nix develop --command bash tests/replay_migration/crash_run.sh
```

WASD/arrows move, E uses nearby objects, Space/click throws, Q drops the first bag
slot, R heals, G sets down the relic, F pings your position, Tab holds the scoreboard,
Enter focuses chat, and F5 saves the authority's game. Roles are `solo`, `host`, `server`,
`client`, and `observer`. `REPLAY_CAVE_ADDRESS`, `REPLAY_CAVE_PORT`, `REPLAY_CAVE_TOKEN` (test identity),
and receive-delay `REPLAY_CAVE_LATENCY` configure local runs. The co-op test uses
120 ms receive delay on each process. Opening the project without a role opens the
connection menu. `REPLAY_CAVE_LOBBY=1` enables staging for explicit launch roles.

Save files default to this project's `user://cave.replay`; set `REPLAY_CAVE_SAVE`
to use another path. Launch with `REPLAY_CAVE_RESUME=1` to resume as solo/host/server.
The host/solo profile must be the same one that owns the saved seat. Profiles
default to `user://<role>.token`, or an explicit `REPLAY_CAVE_PROFILE` path. Give
each local player a distinct profile when running several clients on one machine.
Keep the token file alongside your save when moving your own game to another
machine; the checkpoint contains hashes rather than the credentials themselves.
Original Cavecrawl saves/profiles are separate and are never read or changed.
Browser saves use the token-scoped IndexedDB slot described below.

Direct Session save/resume advances the authority epoch. Clients in that profile
set `REPLAY_CAVE_EPOCH` to the printed epoch and reuse their profile. The Room flow
below follows coordinator-approved authority changes automatically; the separate
direct co-op recovery fixture restarts both runtime processes. Pending actions
in a loaded save are explicitly retired; already executed actions keep their
deduplication frontier. See the [recovery contract](../../docs/replay/recovery.md).

The replication gate keeps the host and guest playing while periodic authority
checkpoints use their existing ENet connection. It opts the guest into backups
with `REPLAY_CAVE_BACKUP=1` and explicitly selects seat 2 through `backup_to`.
It verifies a shared checkpoint containing the looted gems and open door under
120 ms receive delay, 20 ms jitter, 10% loss, and 10% duplication. General live
runs also accept `REPLAY_CAVE_JITTER`, `REPLAY_CAVE_LOSS`, and
`REPLAY_CAVE_DUPLICATE` (loss/duplication values are per 10,000). This is replication;
that gate does not itself invoke takeover. The separate migration gates below do.

The native coordinator-driven room profile now supports planned handoff and crash
takeover while guests keep running. Its fixture starts a coordinator, host,
successor, and guest. The guest keeps its loot and performs a fresh action after
reconnecting in epoch 2; planned handoff also rejoins the old host as a player.
The game shows reconnect/host-change feedback and reports known rollback.

The fixture supplies `REPLAY_CAVE_COORD_PORT`, `REPLAY_CAVE_MEMBER`,
`REPLAY_CAVE_INCARNATION`, and a 64-character lowercase hex
`REPLAY_CAVE_COORD_KEY`. This example currently uses explicit local provisioning
for room 44; use the generic [Room API](../../replay/godot/room.md) for other
coordinator addresses/configurations. The game now has a party lobby; public account/room provisioning and the
remaining M5 coverage are still pending.

## Implemented gameplay

- The two authored floor layouts, chest stocks, den positions, wave counts, and
  wave rests from the original game.
- 120 px/s movement and a 20 Hz simulation matching the original gameplay timing.
- Six-slot bags, chest transfers, drop/grab pickups, and range-gated doors.
- Atomic relic carry/set-down state and a version counter for carrier changes.
  [C6 relic rules](relic.md) preserve it across floors and release it in place on restart.
  [C7 carrier rules](carrier.md) retain ownership through death, disconnect and recovery.
  [C8 adoption](adoption.md) transfers an old host’s relic to its successor.
- Rocks, stamina, cooldowns, damage, chill, death spills, respawn, heal, and revive.
- Dweller chase/flee/bite behavior, frame-owned wave/respawn clocks, floor changes,
  and the final escape condition.
- Replayable pool lifetime and generation-preserving floor teardown.
- [Rock presentation](projectiles.md): centered glyphs and bounded motion between
  simulation ticks, preserving simulation collision and impact timing.
- [Combat feedback](feedback.md): journal-driven player/dweller death bursts,
  player hit sparks and flashes, with correction/cancellation and detached lifetime.
- [Host moderation](moderation.md): remove a selected player and block rejoin,
  with coordinator-durable successor exclusion in Room sessions.
- Solo, listen-host, dedicated authority, client prediction, and observer modes
  through `replay/godot.Session`.

The pure tests cover item conservation/capacity, interactions, combat/revive,
floor progression, old-handle rejection, rift navigation, and the real cave model
contesting loot through the network runner under loss. Godot tests now include a [full co-op campaign](campaign.md): inventory handoff,
relic carry, death/revive/respawn, stale pickup rejection, healing, all four waves
and final escape with a shared victory-frame hash. Normal and faulted runs pass.
This still does not establish complete authored/visual feature parity.

## Comparison and intentional differences

The static `levels/level_*.tscn` files are byte-for-byte copies of the original
authored scenes. Entity views retain the original scene presentation while their
old script attachments are removed. [assets.md](assets.md) records source paths
and hashes. The original scripts/framework are not imported into gameplay.

The new model keeps all mutable gameplay state inside `World`. A chest transfer
updates both the chest and bag directly in one action. Projectiles, AI clocks,
status effects, and entity existence participate in replay. The original uses
owner-streamed movement and several authority-only consequences.

Known differences/gaps:

- This profile keeps server-simulated movement/relic state. The separate
  [owner-motion variant](../replay_cavecrawl_owned/README.md) now reuses this gameplay
  with versioned pose producers, scoped command origins, native/Chrome recovery
  and a matched quiet comparison. Broader remote presentation and full parity remain work.
- Dweller pathing uses a pure visibility graph around the authored rectangular
  rift. The original queries Godot's navigation mesh. Exact paths are not claimed
  identical; this is an explicit physics/navigation port cost to compare.
- Floor resources and markers are captured as saved world values; seeded decorative
  scatter matches the original integer recipe. See [authoring.md](authoring.md) for
  validation, local scene assets and explicit conversion of earlier Replay saves.
- Relic races now reject the losing action; the original consequence could accept
  a harmless no-op. Pickups retain any amount that does not fit the receiving bag.
- [Wave pacing](director.md) now matches the original director in 262 native/WASM
  scenarios. Population beyond the fixed 16-dweller pool and broader floor-state
  correspondence remain separate comparison boundaries.
- Chat/pings and a combat/loot scoreboard now use the optional [Comms service](../../replay/comms/README.md).
  Party names and readiness are replayable, with native/IndexedDB local name preferences.
  [Score latency and stamped ping names](social.md) now have native/browser
  rename/rejoin/migration acceptance. Public provisioning, Steam paths, richer
  effects, and the full migration failure matrix remain open. The full old `cave_test.gd` scenario
  inventory has not been ported yet.

See [parity.md](parity.md) and the repository [roadmap](../../docs/replay/roadmap.md).


## Browser authority migration

`nix develop --command bash examples/replay_cavecrawl/web_run.sh` builds the real
Cavecrawl project and a native SQLite-backed control/signaling fixture. Three
independent Chrome processes collect loot, replicate an approved checkpoint and
complete planned or killed-host migration. The guest retains its inventory/seat
and performs a newly accepted door action; planned mode rejoins the old host.
The default matrix includes `planned`, `crash`, `repeat`, `partition`,
`successor_loss`, `return` and `signaling`. Use `RCB_MODES` to select cases. Logs are retained at
the printed path (`RCB_LOGS` overrides it).

Browser launch uses lowercase URL equivalents of `REPLAY_CAVE_*` options, including
`coord_url`, `coord_key`, `member`, `incarnation`, `token` and `role`. These fixture
credentials demonstrate the protocol; they are not public account provisioning.
Room combines WebSocket control, challenged RTC signaling and direct gameplay
channels. Its native endpoint encoding is unchanged; RTC destinations are explicit
provider/code targets derived from the authenticated authority view.

Each run also records driver timestamps and a timing summary; these include
waiting for leases and fresh browser startup that the local Room timer can omit.
The `signaling` case drops host/client signaling sockets, verifies unchanged
connection generations and epoch, and performs a new accepted game action.
TLS/TURN, richer browser workloads and other browser/OS combinations remain open. See the [browser migration work](../../docs/replay/browser-migration.md).


Set the scene’s `debug_enabled` inspector property or launch with `REPLAY_DEBUG=1`
for the [local diagnostic overlay](../../replay/godot/debug/debug.md). F8 toggles the panel
and F9 explicitly audits recent replayable history. It is disabled by default.


Run the full host/client/observer campaign with
`nix develop --command bash examples/replay_cavecrawl/campaign_run.sh`.


`nix develop --command bash examples/replay_cavecrawl/social_run.sh` checks chat
submission through the actual input signal, typing without moving/firing, late-join
scrollback, transient ping expiry and live scoreboard loot. Chat is ephemeral
session history; it is not part of a gameplay save.

`nix develop --command bash tests/replay_migration/social_run.sh` adds chat before
and after planned/crash migration. `RCB_SOCIAL=1` enables the corresponding chat,
ping and scoreboard assertions in the real-browser migration gate (select
`RCB_MODES='planned crash'`). Lobby names, stamped social names and per-player latency columns have separate
[native/browser acceptance](social.md); broader social UX remains open.

Run `nix develop --command bash examples/replay_cavecrawl/social_web_run.sh` for
the registered browser social/migration gate.


The [party lobby](../../replay/lobby/README.md) stores names, readiness and a party
leader in World. Ready up, then let the leader press Start. Recorded departures
select the lowest present seat as a new leader; reconnecting players ready again
before a staged run. During play, Escape opens the party/Leave panel. After victory,
Another run resets the cave/inventory while retaining profiles and cumulative stats.

`REPLAY_CAVE_NAME` supplies a display name. Normal native menu sessions use a stable
`user://player.token`; existing explicit-role launch paths retain their role-specific
credential defaults. Local names use `user://display_name`; override with
`REPLAY_CAVE_NAME_PATH` or browser `profile_namespace`. `REPLAY_CAVE_PERSIST=0` makes
the preference session-only. Tests use isolated paths/namespaces and explicit tokens.
Browser multiplayer opens through provisioned Room invite URLs; the menu offers Solo
when no invite is present. Browser identities and local saves now use IndexedDB, with Resume available after a
validated slot read. Public provisioning remains separate work.

Run `nix develop --command bash examples/replay_cavecrawl/lobby_run.sh` for actual
menu, readiness, renaming, named chat/scoreboard, leave/reopen and native preference
reload checks. The current game content is `0x4341564552504c39`; see
[authoring.md](authoring.md) for explicit conversion of earlier Replay saves.


Browser Solo now stores its Session identity and complete save archive in IndexedDB.
The default namespace is `replay-cavecrawl`; `profile_namespace` changes it and
`save_slot` chooses a slot (default `cave`). F5 or the party panel's Save run button
starts a save. Wait for the completion message; Leave is disabled during the write.
Resume loads and validates the saved world under the same identity and advances the
authority epoch. The display name alone does not identify an owning player.

Each page retains the revision it observed before play. If another page saves first,
the stale writer is refused. Leave and explicitly resume the latest save before
continuing; a failed/corrupt record is never silently replaced. Room sessions keep
using approved checkpoint recovery and cannot be converted into an offline save
through this button. See the [browser checkpoint contract](../../replay/godot/browser_checkpoint.md).

Run `nix develop --command bash examples/replay_cavecrawl/browser_save_run.sh` for
real Chrome identity creation, forced-process recovery, exact frame restoration,
stale-tab refusal and corrupt-record preservation checks. The harness uses a new
isolated browser profile and dedicated test namespaces.

C5 preserves avatar health, stamina, cooldowns and active chill across descent.
Initial start and Another run use explicit reset policies. See [floor state and
save compatibility](floor-state.md); older Replay saves require explicit conversion.
