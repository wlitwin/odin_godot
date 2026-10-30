# Existing-family weapon authoring comparison

Run `REPLAY_WEAPON_AUTHORING_OUT=/absolute/fresh/directory nix develop --command bash tests/replay_weapon_authoring/run.sh`.

The experiment adds the same `data/guns/stapler.tres` to isolated Kit and Replay
Scrapyard copies. It uses an existing ballistic family and existing atlas art.
No handwritten gameplay, presentation or networking file is changed by the weapon
addition. Replay's normal `tools/stock.py` step also regenerates its catalog for
use outside Godot; that derived output is recorded separately.

Each implementation has two independently built projects: `new/project` includes
the resource, while `cold/project` lacks both it and (for Replay) its generated
stock row. Shared-resource runs use the new project for both players. Host-only
runs use the new host and the cold client. The latter must log seven local guns,
receive the host's eight-gun table, select ID 7 through the normal shop cycle,
and display its actual name and sprite region.

One stationary, non-attacking heavy target isolates the damage check. Setting
its speed/bite to zero is a separate, recorded test-fixture overlay on all four
projects. Its existing 20 HP, damage/death code and projectile collision remain.
A single host shot must leave 17 HP and record three damage before firing
continues. Each player then reaches seven rounds, observes two reloads and ends
with two rounds in the magazine. The authority must finish with twenty damage,
one kill and no living target.

The full matrix has two resource cases, local and 120-ms receive-delay conditions,
and two repetitions in alternating implementation order: sixteen two-process runs
and 32 peer receipts. Delay is per process, not measured RTT. No loss, jitter or
duplication is injected. `REPLAY_WEAPON_AUTHORING_SMOKE=1` runs one shared/local
pair and emits a distinct smoke marker; partial reports require `--allow-partial`.

The original games and primary Replay project stay unchanged. Resource/source
hashes, feature-only changes, generated stock diffs, separate fixture changes,
exact binaries and raw receipts identify each prepared project. The normal menu
and game remain runnable from those directories. Stop/polling barriers precede
teardown after all results settle, as in the paid-revive comparison.

This is content-authoring evidence in an existing family, not a timed human study,
new weapon-family implementation, new art production, browser/Steam acceptance,
save/migration acceptance or a runtime performance comparison. The new catalog is
transmitted as existing host-authored data; no protocol/schema version changes
are needed. Broader authoring and gameplay envelopes remain requirements.

`native_stock/main.odin` also executes the generated catalog without Godot. Build
it with `-collection:subject=PREPARED_PROJECT` and `-define:EXPECTED_GUNS=8` for the
new project, or 7 for the cold project. It checks definition values, cycling and
the common training-target fixture. This distinguishes generated source from an
actually usable standalone catalog.

`verify_report.py OUTPUT_DIRECTORY` checks rejection of missing receipts, wrong
weapon/damage/ammo values, false cold-client claims, missing reloads, changed fault
parameters, source tampering, handwritten-code claims, forged resource/generated
diffs and missing teardown barriers. The test mutations never target a prepared
project or primary source file.

The driver waits for both initial loadout declarations before starting and then
checks the exact 0→1→…→7 shop sequence. An earlier delayed run started before one
declaration arrived: that player correctly began on its default gun and seven
swaps wrapped to zero. That incomplete fixture run is retained separately; it was
not a duplicated network action or a change required by the new weapon.

`REPLAY_WEAPON_AUTHORING_REUSE=PREVIOUS_OUTPUT` reuses verified compiled game
binaries in fresh project copies when the contract, framework and Odin adapter
sources still match. It refreshes only the external GDScript test driver and
isolated project/user names, recording that provenance in `reuse.json`. It refuses
changed compiled sources. This was used after adding setup barriers to the driver;
feature and gameplay code did not change.
