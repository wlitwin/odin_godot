# Cavecrawl with owner motion

This is an explicit cooperative motion profile beside the original Kit game and
the server-simulated [Replay Cavecrawl](../replay_cavecrawl/README.md). It reuses
that port's gameplay reducer—the function that applies inputs to world state—
along with its scenes and interface. A local pose producer samples the player's
locally simulated avatar and carried relic; authenticated, versioned pose samples become values in
the authoritative replayable world. Inventory, combat, AI, progression and room
authority remain server decisions.

```sh
nix develop --command bash examples/replay_cavecrawl_owned/play.sh
REPLAY_CAVE_ROLE=host nix develop --command bash examples/replay_cavecrawl_owned/play.sh
REPLAY_CAVE_ROLE=client nix develop --command bash examples/replay_cavecrawl_owned/play.sh
REPLAY_CAVE_ROLE=observer nix develop --command bash examples/replay_cavecrawl_owned/play.sh
```

The default port is **49585**. The native user directory is `ReplayCavecrawlOwned`;
browser profile and Party namespaces also differ from the server-simulated port.
Content `0x434156454f574e33` and the latest-observation contract are incompatible
with server-motion peers/saves. There is no implicit cross-profile conversion.
Both Replay profiles and the original Kit game remain independently runnable.

## Authoring and execution

Edit shared gameplay in `examples/replay_cavecrawl/shared/cave/` and shared Godot
authoring in `examples/replay_cavecrawl/scripts/` and its scenes/resources. The
`owner_cave` package composes that world with ownership/sample metadata. Its step
supplies accepted positions to the common reducer instead of integrating movement
there. Validation requires both representations to agree.

`prepare.py OUTPUT` creates a fresh isolated project, binds the common scripts to
the owner model, changes defaults, and records source hashes. `build.sh OUTPUT`
also builds/imports it. Existing output projects are refused. For a persistent
project to inspect in Godot:

```sh
nix develop --command bash examples/replay_cavecrawl_owned/build.sh /absolute/fresh/output
```

`play.sh` uses a temporary generated project and removes it on exit; game profiles
and saves live in the separate persistent user directory. Edit the shared authored
source, rather than the temporary project. Assets retain the common port's
[original provenance](../replay_cavecrawl/assets.md).

Keyboard motion is normalized; scripted `walk_to` uses the original independent
axis stepping. Local poses render immediately and are sampled into controls.
The original's manual owner movement is not a rigid-body solver, so this variant
does not add one or clip movement to the viewport/rift. Late owner poses can settle
after a health/victory update; the producer gates new movement from observed state.

Owner changes, floor transitions, respawn/revive, fresh identities and authority
epochs invalidate previous sample scopes. Respawn/revive cuts the scope even when
coordinates are unchanged. Checkpoints retain accepted pose/velocity, ownership,
revision and sample frontiers; replay consumes those values without invoking the
local producer. Scope and finite-value bounds are checked, but a cooperative owner
is trusted to supply its own pose. This is not competitive movement validation or
deterministic Godot physics.

## Recovery and acceptance

The existing Room path supports this model. A provision/checkpoint service can use
`REPLAY_ROOM_CONTENT=0x434156454f574e33` and
`REPLAY_ROOM_CHECKPOINT_MODEL=cavecrawl-owned`; see the
[service configuration](../replay_room_service/README.md). Service state must be
separate from deployments of the other content IDs.

```sh
REPLAY_CAVE_OWNER_OUT=/absolute/fresh/tests nix develop --command bash tests/replay_cave_owner/run.sh
CHECKPOINT_GAMES=cavecrawl-owned CHECKPOINT_RESTORE=1 REPLAY_CHECKPOINT_OUT=/absolute/fresh/checkpoints nix develop --command bash tests/replay_room_checkpoint/run.sh
```

The first native gates cover loot/door play, a faulted host → unowned → guest relic
handoff, and planned/crash recovery with either successor or surviving guest carrying
the relic. Pure model tests check stale/foreign/recycled samples, exact checkpoint
installation, epoch rebinding, inventory retention and life/floor cuts. The existing
shared reducer and native solo/network gates remain passing.

Three real Chrome instances now pass planned carried-relic handoff; abrupt host
loss passes with the two survivors. Owner epochs/revisions, fresh samples, social
state, RTC traffic and profile reload are checked. Browser solo saves pass exact
restore after a killed browser, continued actions, stale-writer rejection and
corruption preservation in the default isolated namespace.

```sh
REPLAY_CAVE_OWNER_WEB_OUT=/absolute/fresh/browser nix develop --command bash tests/replay_cave_owner/browser_run.sh
```

See [browser evidence and limits](../../docs/replay/results/cave-owner-browser-2026-09-19/README.md).
This is a new profile, not full original-game parity. Broader browsers and public
network deployment, richer fault/recovery cases, remote presentation and paired gameplay/performance/ergonomics comparisons remain
acceptance work.

## Action-time context and O1 saves

O2 attaches the local producer's pose and ownership scope to range interactions
and throws. The reliable action can be judged before its movement observation, or
after a newer observation, without overwriting the avatar's accepted current pose.
Take/door/pickup/carry/revive use the issued origin; thrown rocks clamp that origin
to within 64 pixels of the accepted avatar position, matching the original rule.
Current actor eligibility and target state still apply. Commands entered while a
restored producer scope is not ready are held in a bounded 16-entry local FIFO;
their origin is captured when submission becomes possible. Leave discards these
unsubmitted intents. Respawn, ownership changes
and authority epochs retire old contexts. This is a scoped owner claim, not a
verified historical simulation pose or competitive anti-cheat.

The lower-level action also supports `Accepted_Pose` for server-authored commands
and O1 compatibility. Ordinary UI actions use `Owner_Pose`. Action IDs retain the
runner's existing ordering and deduplication; contexts do not consume or rewind
pose-stream sequences. A preserved pending context from a previous authority epoch
is refused normally; a fresh command needs the newly observed scope.

Convert an O1 or O2 native save explicitly to a new destination:

```sh
nix develop --command odin build examples/replay_cavecrawl_owned/tools/upgrade_save \
  -collection:godot=. -out:/tmp/upgrade-owned-cave
/tmp/upgrade-owned-cave /path/to/owner1.replay /path/to/owner3.replay
```

World, ownership, controls, membership and action frontiers remain unchanged.
Pending O1 commands retain accepted-pose semantics; the converter does not invent
an issue-time origin. Existing destinations/corrupt files are preserved, and
coordinated archives require an application-owned upgrade. The converter does not
rewrite browser IndexedDB records. Older browser archives remain protected by strict
content checks; interactive cross-version browser import is still pending.

O3 adds the common [generation-bound dweller impacts](../replay_cavecrawl/impacts.md).
O2 saves convert with exact world/action preservation; explicit O2 recording
verification retains the old event sequence.
