# Complete run saves

Use F5 to save an uncoordinated solo/host run, then resume it in a fresh process
with the same identity. Native files and browser slots contain the complete
gameplay checkpoint and required spray images. The sections below describe each
store and the current saved-fixture checks.

The current content identifier is `0x525343524150304c`. Dash uses a scheduled
`Action.Dash`; continuous controls contain movement, aim, firing and revival.
Loaders accept the current contracts only. Owned archives were migrated before
retiring the old readers; [receipts and original fixture bytes](../../docs/replay/results/usability-legacy-2026-11-16/scrapyard/receipt.json)
record that conversion. [Controls](controls.md) describes current action timing.

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

## Current saved fixtures

`tests/replay_scrapyard/saved_fixtures_run.sh` reads current-schema saved fixtures,
checks their identity and public state digest, resumes each in a fresh Godot
process, and verifies exact installation, asset restoration and continued combat.
It does not require historical types or converters. The original bytes and
migration receipts are retained as evidence separately from active inputs.

The ordinary [save gate](save_run.sh) also rejects a raw checkpoint presented as a
game save, a wrong identity and corrupted data while preserving the rejected file.
Use the explicit `net.checkpoint_decode` API when deliberately composing raw
checkpoint storage; the game's save format includes the bundle envelope.

See [authority history](authority-history.md) for projection, prediction and
complete-checkpoint guarantees. Generic future schema conversion tools remain
available through [replay/evolution](../../replay/evolution/README.md).
