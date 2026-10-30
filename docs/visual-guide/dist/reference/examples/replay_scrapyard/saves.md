# Complete run saves

Use F5 to save an uncoordinated solo/host run, then resume it in a fresh process
with the same identity. Native files and browser slots contain the complete
gameplay checkpoint and required spray images. The sections below describe each
store and the explicit conversion path for older Replay archives.

Current content 51 adds shared turrets; content 50 added authored pulse attacks and
content 49 records takeover timer resets in the simulation. Content 48 made rewind history authority-only in ordinary replication; complete saves retain it. Content 47 added receipt-time dash actions. The explicit offline converter
accepts content 42–50 and retains their pending action IDs/ticks, recorded controls
and assets. Frozen old action enums prevent the new Dash member from changing the
source schema. The [control contract](controls.md) explains why the legacy dash
control bit remains available for imported history.

Browser solo play saves the complete checkpoint-and-image bundle in IndexedDB.
F5 starts an asynchronous write; **Saving run…** changes to **Run saved.** only
after the database completion receipt. Resume solo waits for the blob and validates
identity, content and every image dependency before opening the simulation runtime. The
`save_run()` browser return value means submission accepted; observe completion
before treating `saved_tick`/`saved_hash` as the new saved point.

Browser records use the profile namespace and reconnect identity. `save_slot`
defaults to `run`; other slots stay under a separate `run/` key prefix so they
cannot collide with profile or spray records. Slots are separate from native
`RSY_SAVE` paths. Replacement compares the last observed storage revision. A
conflict preserves the stored record and previous success receipt. Reload or use
another slot before deciding to replace competing work; no automatic rebase occurs.

Resume uses the bundled image even if the user's separately stored spray
preference changed afterward. That preference applies to fresh runs; an explicit
selection can still change a resumed run. This rule also applies on native.

`web_save_run.sh` uploads image A, saves active zone/lob combat, stores preference B,
and kills Chrome. It deletes both uploads, checks that a fresh run uses B, then
checks exact restore with A and new gunfire after the saved lob lands. It repeats
resume after deleting the separate spray record. Stale-save conflicts, missing
images, wrong identities and corruption preserve the source save. A slot named
`profile` must preserve the profile and default run. The verified browser path is
solo on local Chrome; Room worlds recover through leases/migration. Browser
eviction/deletion and the [storage contract](../../replay/godot/storage/browser_store.md) apply.

On native, F5 writes the current uncoordinated solo/host authority checkpoint to
`user://run.replay`. The menu's **Resume solo** opens it with the same local
identity. A host can explicitly resume a saved co-op run with:

```sh
RSY_ROLE=host RSY_RESUME=1 nix develop --command bash examples/replay_scrapyard/play.sh
# For a save created in epoch one, other processes join the resumed epoch two:
RSY_ROLE=client RSY_EPOCH=2 nix develop --command bash examples/replay_scrapyard/play.sh
```

`RSY_SAVE` overrides the file location. Start a fresh process to resume; this
does not replace a live Session. Clients reconnect using their original tokens,
which resolve the saved seats. Uncoordinated clients/observers must be given the
resumed epoch with `RSY_EPOCH`; their default is one. Room handles this discovery
and redirect automatically. This manual co-op resume path still needs integrated
connection UX. Without a matching local token a player-hosted
resume fails. A dedicated server may use seat zero. The archive must match current
content and schema; this experiment does not silently convert old versions.

The save bundle contains the checkpoint and all PNG payloads referenced by its
players. The checkpoint contains the entire simulation frame, roster, ownership, admitted
action frontiers and configured runner state. Zones, airborne deliveries, cooldowns,
effect credit, pools, history, run timers and progression resume together. The
installed frame is checked against the decoded frame before simulation advances.
The new process uses a newer epoch; pending old work follows the standard explicit
retirement policy. No fresh gameplay event is synthesized merely by loading a frame.

The file uses the shared bounded codec and staged storage writer. A malformed,
wrong-identity or wrong-content save fails without replacing the source. Successful
close/rename is a process-crash boundary; portable power-loss durability is not
claimed. Saves restore the older world, including its economy, and subsequent local
profile writes reflect that restored authority. Profiles are local co-op progress,
not an independently authoritative bank.

Room sessions use coordinator-approved prepared checkpoints and migration. This
manual entry point rejects Room archives requiring a permit: a local file does
not authorize a new leader. Manually restarting an uncoordinated host also requires
the previous authority to have stopped; use Room for live handoff/partition fencing.

`save_run.sh` creates active combat, saves, kills the source process, and starts a
fresh one. It checks the actual installed world hash/tick, epoch and seat, lets the
saved lob land once, then exercises new gunfire. It also rejects an unrelated token
and a corrupted archive while preserving the corrupted file. The scenario uses
the same long-lived combat fixture as the Room test.

`save_coop_run.sh` saves after both players have used abilities, kills all three
game processes, restores the host and rejoins fresh client/observer processes.
It preserves seats/loadouts and the client's previous cast, permits its next cast,
continues saved effects and compares the complete world across all peers. The
fixture supplies the explicit resumed epoch. Faulted/repeated manual save-rejoin,
connection UX and conversion of older game schemas remain additional acceptance work.

`save_assets_run.sh` saves a spray supplied by a client, kills all game processes,
deletes the original PNG and restarts only the host. The host must restore the
image and placement from the bundle before any peer connects. A fresh observer
then receives that image, the saved lob lands, new gunfire succeeds and both
processes compare their complete world. A correctly framed bundle whose checkpoint
still references a removed image is rejected without modifying the good file.

The reader also accepts current-compatible plain checkpoint files when no external
assets are required. Older gameplay/schema versions still need explicit conversion.
Only current-frame dependencies are bundled: the default resume policy retires
pending old actions. A different pending-action policy must include their asset
dependencies too. See the [bundle contract](../../replay/assets/bundles.md).

<a id="converting-a-protocol-6-run"></a>

## Converting older Replay runs

The standalone Odin tool converts protocol-6 or protocol-7 / checkpoint-4 saves
from Scrapyard content `0x5253435241503042`, plus protocol-7 contents `...3043` through `...304a`,
into current content `...304b`. It uses frozen original world/Flash and action/event contracts
and preserves existing world values and the control schema while updating the
world, action and timing contracts for Arc paths and receipt-time dash. Content-42 actions receive a
zeroed development payload. Archived event histories do not exist, so the new
event detail, wall-contact kind and arc kind change the contract without inventing
past occurrences or spread hops.
The converter seeds `authority_epoch` from the validated checkpoint epoch while preserving the original timer values. Restore installs that exact converted frame; the first committed tick of the new epoch rearms the original takeover timers. See [succession behavior](recovery.md#takeover-timers).

The normal game loader remains strict. Build and invoke from the repository root:

```sh
nix develop --command odin build examples/replay_scrapyard/tools/upgrade_run \
  -collection:godot=. -out:/tmp/replay-upgrade-run
/tmp/replay-upgrade-run /path/to/old-run.replay /path/to/new-run.replay \
  --identity-file /path/to/replay_identity
```

Use the filesystem path of this Replay project's 16-byte `replay_identity`, not a
`user://` URI. For a test save created with `RSY_TOKEN`, supply `--token SAME_LABEL`
instead. The identity must resolve to a playable reservation in the archive.
Identity verification here prevents accidental selection of another local save;
local archives are not a secure competitive progression ledger.

The tool validates the old contract, the full archive and bundle, matching
container metadata, complete current-frame image dependencies and bounded PNG
header information. It updates schema/content/protocol/contract stamps, maps any
pending original actions into the new shape, and rebuilds container checksums.
Godot performs the full PNG decode during normal resume. The world, roster, action
sequences/refusal reasons, image bytes, tick and old epoch remain intact. Raw
checkpoints are supported only when their worlds have no external image dependencies.

The output path must be new. The tool stages and syncs a complete file in the same
directory, then publishes it using a hard link that cannot replace an existing
file or symlink. A failed conversion leaves the source and any existing destination
untouched. Concurrent writers cannot replace the winner. Filesystems without hard
links fail explicitly; portable power-loss durability of directory changes is not
claimed. No interactive confirmation or in-place overwrite mode is needed.

Resume the output with the same identity and `RSY_SAVE=/path/to/new-run.replay`.
Normal resume advances the epoch and applies its existing pending-action retirement
policy. Stop the old uncoordinated authority before resuming its world.

The CLI rejects coordinator-permit archives and custom admission policies; use an
application-owned coordinated upgrade/recovery path for those. It does not convert
Scrapyard content `...3040`/`...3041`, older layouts or other game schemas. It also
does not edit browser IndexedDB records; browser import/export UX remains separate
work. See the [library conversion contract](../../replay/net/checkpoint_upgrade.md).

```sh
nix develop --command bash tests/replay_scrapyard/upgrade_run.sh
```

This gate converts genuine older plain/spray saves from retained protocol-6 and
protocol-7 game binaries, resumes them in fresh Godot processes, checks exact frame
hashes/ticks and continued combat, and exercises
corruption, wrong identity/content, missing dependencies, existing destinations,
symlinks and concurrent publication. The original game and original saves remain
separate and unchanged.

See [authority history](authority-history.md) for projection, prediction and full-checkpoint guarantees.

## Content 50 / Stormcaller

The Stormcaller revision introduced content 50/J. The offline converter also accepts
content 49/I, freezing its catalog shape and adding disabled zero-valued pulse
components. Converted runs preserve their catalog; new runs load the current
Resources. Network protocol 7 is unchanged, but old peers cannot join the new
content/schema contract. See [Stormcaller](stormcaller.md) for the feature and tests.

## Content 51 / shared turret

Content 51/K adds the turret pool, authored turret definitions, and targeted
mount/release actions. Content-50 imports start with no turrets; new configuration
and action-target fields are zero. Existing catalogs and pending action identities
remain intact, so this conversion does not inject the new ability into an old run.
See [shared turret](shared-turret.md) for behavior and recovery tests.
