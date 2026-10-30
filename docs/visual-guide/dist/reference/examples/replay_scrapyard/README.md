# Replay Scrapyard — canonical editor-first example

Run `nix develop --command bash examples/replay_scrapyard/play.sh` from the
repository root, then choose Solo to try the game. Scrapyard calls its player
characters **runners** and its guns **irons**. Replay's runtime runner is separate:
it schedules simulation steps and manages input/history. Godot presents the
resulting state and effects through authored scenes.

**Start with the [visual contributor guide](contributor-guide.md):**
run the game, learn the state boundaries, follow a turret from input to scene,
and choose a first change with the right tests.

The [code guide](code-guide.md) maps the frame loop, input, session startup,
event handling and presentation, with the project's formatting command.

[Shared turret](shared-turret.md) adds a deployable ability that any player can
operate, with shared ammunition, predicted claims, handoffs and occupied recovery.

[Stormcaller](stormcaller.md) is a new Replay-only enemy built through this workflow: an authored pulse attack, composed charge view, and tested correction/recovery behavior.

The [editor workflow](editor-workflow.md) adds validation/baking, refreshable
previews, Resource pickers, feature drafts and an ability workbench with replay tests.

The [authoring tools workflow](authoring-tools.md) covers typed enemy registration,
one canonical bake, frozen revisions and reusable feature tests.

Start with the [editor-first authoring guide](editor-first.md): authored actor scenes,
reusable child view components, detached HUD/display values and validated gameplay
Resources around the replayable model. Enemy, runner and HUD scenes have independent
F6 previews. The [initial bridge comparison](bridge.md) records the earlier migration
and its measured tradeoffs; current composition is described in the authoring guide.

[Dash input](controls.md) now uses receipt-time actions with explicit outcomes;
movement and held combat input retain scheduled controls.

The [online party menu](online.md) now creates, joins and rejoins rooms through
the standalone Replay room service. It uses the shared Party helper while keeping
personal progression separate from network credentials and retaining asset-aware
takeover checks. Native TLS and local browser RTC gates pass; the full port and
public deployment remain in progress.

This is a separate reimplementation of the sibling Scrapyard project using Replay.
The original game remains runnable. This version currently covers seeded cover,
runner movement/dash, staging, ballistics, grenades, historical rail/healing queries, all enemy brains, status/reaction rules, damage, drops, camera
and multiplayer views. The [historical port ledger](roadmap.md) records remaining comparison work; exhaustive
parity is outside the current canonical-authoring goal.

[Audio and local settings](audio.md) now include the original sound assets, music
crossfades, persisted volume/shake preferences and menu controls.

Original dirt/grass dressing and the animated gate/direction arrow are restored.
The [scenery gate](../../docs/replay/results/scrapyard-scenery-2026-09-07/README.md)
checks three floors across host/client/observer. The [bottom shop cards](shop.md)
now restore clickable purchases and the original shortcut order; broader HUD and
hardware-audio parity remain work.

The [combat HUD](hud.md) now includes the original health/cooldown/status displays,
large magazine, boss health and revive prompt, driven from Replay state.

[Run transitions](transitions.md) now include large departure/wipe panels,
current wave/rest information and recovery narration reconstructed from state.

[Borrowed eyes](camera.md) follows a living teammate while downed, returns on
revival and handles a watched host's loss without changing local controls or HUD.

[Chat and yard history](chat.md) now include named messages, a late-join scrollback,
wave/run announcements and history retained through asset-aware host migration.

[Positional pings](pings.md) use middle mouse, with a stamped floating name and
the original fading diamond; late-join history excludes old markers.

[Browser UI acceptance](browser_ui.md) now exercises chat, pings, shop, HUD and
camera/revival in three actual Chrome processes with shared world-state checks.

[Actor presentation](actors.md) now restores downed poses/beacons, muzzle/reload
cues, ghost tint and enemy attack/hit/death behavior with lifecycle checks.

[Combat feedback](feedback.md) adds bounded bursts, debris, damage numbers and
pickup effects, with expiry, floor-change and recovery checks.

[Screen effects](screen.md) restore the health vignette, zoom kicks and floor
veil, with camera-motion controls and native/browser checks.

[Directional wounds](wounds.md) use recorded hit origins and historical victim
positions, with personal-view and expiry checks.

[Wall contacts](walls.md) preserve the resolved cover face for ballistic/spit
sparks and sound, with bounded capacity and explicit older-save conversion.

[Rail and grenade presentation](ordnance_view.md) adds beam contact sparks,
original shell shapes and bounded ember trails.

[Escape menu and tally](menu.md) add screen dimming, responsive panels, healing
credit, keyboard focus handling and native/browser Quit.

[Staging muster](muster.md) restores player previews, readiness lamps, bidirectional
pickers, host Start and late Drop In.

[Automatic loadouts](automatic.md) persist local choice modes and resolve them
for the current seat while keeping gameplay profiles concrete.

[Editor workbench](workbench.md) provides inspector-driven previews of the real
game, with a live tally and Esc menu.

[Browser play and migration](browser.md) now have a real three-browser gate,
including PNG upload, an asset-dependent checkpoint, planned/crash recovery and
continued combat with whole-world state comparison.

```sh
nix develop --command bash examples/replay_scrapyard/play.sh
RSY_ROLE=host RSY_NAME=Axle nix develop --command bash examples/replay_scrapyard/play.sh
RSY_ROLE=client RSY_TOKEN=local-bolt RSY_NAME=Bolt nix develop --command bash examples/replay_scrapyard/play.sh
RSY_ROLE=observer nix develop --command bash examples/replay_scrapyard/play.sh

nix develop --command bash examples/replay_scrapyard/run.sh
nix develop --command bash examples/replay_scrapyard/combat_run.sh
nix develop --command bash examples/replay_scrapyard/weapon_run.sh
nix develop --command bash examples/replay_scrapyard/enemy_run.sh
nix develop --command bash examples/replay_scrapyard/abilities_run.sh
nix develop --command bash examples/replay_scrapyard/storm_run.sh
nix develop --command bash examples/replay_scrapyard/gauntlet_run.sh
nix develop --command bash examples/replay_scrapyard/spray_run.sh
nix develop --command bash examples/replay_scrapyard/spray_migration_run.sh
nix develop --command bash examples/replay_scrapyard/run_loop.sh
nix develop --command bash examples/replay_scrapyard/revive_run.sh
nix develop --command bash examples/replay_scrapyard/profile_run.sh
nix develop --command bash examples/replay_scrapyard/migration_run.sh
nix develop --command bash examples/replay_scrapyard/lobby_migration_run.sh
nix develop --command bash examples/replay_scrapyard/save_run.sh
nix develop --command bash tests/replay_scrapyard/upgrade_run.sh
nix develop --command bash examples/replay_scrapyard/workbench_run.sh
nix develop --command bash examples/replay_scrapyard/shop_run.sh
nix develop --command bash examples/replay_scrapyard/hud_run.sh
nix develop --command bash examples/replay_scrapyard/chat_run.sh
nix develop --command bash examples/replay_scrapyard/pings_run.sh
nix develop --command bash examples/replay_scrapyard/web_ui_run.sh
nix develop --command bash examples/replay_scrapyard/actors_run.sh
nix develop --command bash examples/replay_scrapyard/feedback_run.sh
nix develop --command bash examples/replay_scrapyard/screen_run.sh
nix develop --command bash examples/replay_scrapyard/wounds_run.sh
nix develop --command bash examples/replay_scrapyard/walls_run.sh
nix develop --command bash examples/replay_scrapyard/ordnance_view_run.sh
nix develop --command bash examples/replay_scrapyard/menu_run.sh
nix develop --command bash examples/replay_scrapyard/muster_run.sh
nix develop --command bash examples/replay_scrapyard/muster_peers_run.sh
nix develop --command bash examples/replay_scrapyard/automatic_run.sh
nix develop --command bash examples/replay_scrapyard/automatic_web_run.sh
nix develop --command bash tests/replay_scrapyard/development_run.sh
nix develop --command bash examples/replay_scrapyard/save_coop_run.sh
nix develop --command bash examples/replay_scrapyard/save_assets_run.sh
nix develop --command bash examples/replay_scrapyard/mod_run.sh
nix develop --command bash examples/replay_scrapyard/mod_migration_run.sh
nix develop --command bash examples/replay_scrapyard/stress_run.sh
RSY_JITTER=20 RSY_LOSS=1000 RSY_DUPLICATE=1000 nix develop --command bash examples/replay_scrapyard/run.sh
REPLAY_REQUIRE_BASELINE=1 nix develop --command bash tests/replay_scrapyard/run.sh
```

The menu offers Solo, Host, Join, Watch and Resume solo at localhost; port defaults to 49610.
Pick a name, skin and iron, mark ready, then the displayed lobby leader starts. WASD moves and Shift
dashes; hold the left mouse button to fire. All seven irons have
magazines, automatic reloads and deterministic jams (continued trigger pulls
clear jams). The lobber bounces and blasts mobs; the lance pierces; the mender
heals the first living friend. Interactive play now runs waves, floor clears,
shops, regroup/departure and wipe/reset. Hold F to revive; the clear-stage panel
lists purchases and parts. [Run rules](run.md) explain what persists within the
world. [Local co-op profiles](profiles.md) now save cores, parts and loadouts;
[Room recovery](recovery.md) carries live combat checkpoints to a successor.
F5 saves an uncoordinated solo/host run; [run saves](saves.md) describe fresh-process
resume and identity requirements. `RSY_RUN=0` retains isolated
encounters; then `RSY_ENCOUNTER=mixed`, `boss` or `barrels` selects those fixtures.
Select two abilities in staging, then Q/E cast toward the mouse. Q carries a point;
E a direction. Cooldowns appear below the status line.
Equip shared turret to deploy one; press T nearby to mount/release, then aim/fire
normally. Its last round despawns it and automatically dismounts the operator.
Project name, custom user-data directory and port are separate from the original.

One reducer—a function that applies inputs to gameplay values—handles
roster/profile actions, readiness, start/drop-in,
movement, dash, gun mechanisms, enemies, projectiles, drops and events. Server
authority and local prediction replace the original's owner-streamed movement;
remote player characters are displayed using the observed view clock.
The model never calls Godot. Arena rendering and collision use the same saved cover
list, and camera/animation/smoothing do not modify it.

The test compiles selected unmodified original arena/movement procedures into an
isolated oracle and compares every cover plus final position bits for 12 layouts
and 48 movement traces. It never runs the original `run.sh` or clears its profiles.
The cached baseline corpus permits standalone tests when the sibling is absent;
`REPLAY_REQUIRE_BASELINE=1` requires a live source comparison. Native tests also cover
staging gates, collision forgiveness, UTF-8 names, rewind and mid-dash checkpoint
resume. The gun oracle compares the original magazine/reload/jam mechanism over
16 scenarios; additional combat tests cover occlusion, capacity/conservation,
rollback of kills/pickups and active-combat checkpoint continuation.
The three-process arena gate checks seed/loadout agreement, movement, one dash per
player, effect counts and settled position convergence under latency/faults.
The combat gate drives two shooters and a spectator, requires four kills, exactly
29 damage/12 scrap and reconciled shot effects, then compares the complete world
at a common authoritative tick. `weapon_run.sh` also checks grenade/lance combat
and a separate wounded-teammate healing scenario, including validated historical
queries. `RSY_JITTER`, `RSY_LOSS` and `RSY_DUPLICATE` apply to these gates too.

See [combat rules and limits](combat.md), [asset hashes](assets.md) and the
[port ledger](roadmap.md) for unmatched rules and missing slices. The current fixed-tick
dash is ten ticks, compared with the original's 0.16-second owner-frame duration;
variable-frame feel and network trust are not yet matched.

The original ability gate uses three players and a late spectator to exercise the six original
abilities: slime lob, igniter cone, frostwave nova, battlecry buff, salvefield zone
and sparkjar lob. It checks cross-player reactions, attribution, pulse/expiry
behavior and a complete same-tick world comparison. See [ability rules](abilities.md)
for the saved-state contract and remaining comparison limits.

`storm_run.sh` gives slime/frost to one runner and spark/ignite to another. It proves
cross-player freeze/shatter credit, observes burn before dousing, then checks shock
spread. A support runner supplies rally/salve and every participant must observe
surge. The normal ability gate now explicitly checks that friendly transmutation too.

`gauntlet_run.sh` exercises all three floor-one waves (4/4/5 enemies), records each
saved rest deadline and refuses early wave/floor completion. Its players use normal
weapons and support casts, then gathers the crew for a separately spawned barrel
chain. The [matched solo comparison](../../docs/replay/results/solo-gauntlet-2026-09-13/README.md)
uses isolated original/Replay games with one player and no support casts. All six
games clear the waves; one Replay stationary barrel finale is blocked by cover,
so the full paired cohort does not pass. Difficulty and human feel remain unverified.

[Spray images](sprays.md) use content-addressed transfer and value-owned placements.
Choose a PNG in staging, then press G to stamp it. The existing decal follows image
replacement, and Room preparation waits for referenced image bytes.

[Host-owned JSON mods](mods.md) overlay the value catalog in filename order. Clients
use the host’s catalog, including sparse loadouts, and saves retain that catalog.

The [stress/profiling record](../../docs/replay/results/scrapyard-stress-2026-09-06/README.md)
includes a 40-enemy workload, raw timings and memory/traffic observations. The [optimized-build copy fix](../../docs/replay/results/scrapyard-copy-lowering-2026-09-06/README.md)
now permits ordinary -o:speed builds. A fair baseline comparison remains open.

[Authority-only rewind history](authority-history.md) reduces ordinary snapshot traffic while preserving complete recovery checkpoints.

The [cover-aware solo comparison](../../docs/replay/results/solo-navigation-2026-09-14/README.md) now verifies blocked shots and ordinary movement around cover through complete wave/barrel finales in both games.

With `RSY_DEV=1`, the Escape menu includes **Export recording**. It saves recent
authority/prediction frames, controls, actions and verdicts to a native file
(`RSY_RECORDING_PATH`, default `user://scrapyard.rplrec`) or browser download.
The [network recording guide](../../replay/net/recording.md) explains the headless
verifier, compatibility and cost. This diagnostic does not pause the live session
or replace its recovery checkpoint.

Dedicated authorities can run with `RSY_ROLE=server`. The [server-act comparison](../../tests/replay_dedicated_comparison/README.md) checks two clients through combat and floor progression. For coordinator-managed avatarless authorities, see the [Room infrastructure profile](../../replay/godot/dedicated.md).
