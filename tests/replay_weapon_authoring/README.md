# Existing-family weapon authoring

Run `REPLAY_WEAPON_AUTHORING_OUT=/absolute/fresh/directory nix develop --command bash tests/replay_weapon_authoring/run.sh`.

The required test adds `data/guns/stapler.tres` to an isolated Replay Scrapyard
project using an existing ballistic family and atlas art. It changes no
handwritten gameplay, presentation or networking file for the weapon addition.
When the original sibling `../scrapyard` checkout is available, the same workload
also runs against Kit. The report lists the implementations actually exercised;
a Replay-only run supplies no Kit comparison evidence.

Each implementation has independently built `new/project` and `cold/project`
variants. The new project includes the resource; the cold project lacks it.
Replay catalogs are baked through the current typed Godot extractor after
building and importing each project, then embedded in the final script build.
Both canonical `stock.rpldef` bytes and their source receipt are recorded and
verified. The native catalog checks execute those artifacts independently of
Godot: eight guns in the new variant, seven in the cold variant, with the exact
weapon values and shop cycle.

Shared-resource runs use the new project for both players. Host-only runs use
the new host and the cold client. The latter must log seven local guns, receive
the host's eight-gun catalog, select ID 7 through ordinary shop cycling, and
display the actual name and sprite region.

One stationary, non-attacking heavy target isolates the damage check. Setting
its speed and bite to zero is a separate recorded fixture edit; its 20 HP,
damage/death code and projectile collision remain. A single host shot must leave
17 HP and record three damage before firing continues. Each player reaches seven
rounds, observes at least two reloads and ends with two rounds in the magazine.
The authority finishes with twenty damage, one kill and no living target.

The full matrix retains both resource cases, local and 120-ms receive-delay
conditions, and two repetitions. Replay therefore requires eight two-process
runs and sixteen peer receipts. With Kit available, alternating implementation
order produces sixteen runs and 32 peer receipts. Delay is per process, not
measured RTT; no loss, jitter or duplication is injected.
`REPLAY_WEAPON_AUTHORING_SMOKE=1` runs one shared/local pair and emits a distinct
smoke marker. Partial reports require `--allow-partial`.

Feature edits, training-target edits and derived catalog outputs have separate
hash records. The typed catalog receipt binds the combined authoring inputs;
the report does not attribute training-target changes to the weapon feature.
Source manifests, exact binaries, native catalog checks and raw gameplay
receipts identify each prepared project. The original games remain unchanged.
The fixture uses the SDK's ordinary debug build. Explicit `SCRIPT_BUILD_FLAGS`
overrides remain available and are recorded with the binary hashes.

`verify_report.py OUTPUT` rejects missing peers or native catalog evidence,
missing required implementations, wrong weapon/damage/ammo values, false
cold-client claims, missing reloads, changed fault parameters, source or catalog
tampering, handwritten-code claims, and missing setup or teardown barriers.
Its mutations affect copied receipts rather than prepared game projects.

`REPLAY_WEAPON_AUTHORING_REUSE=PREVIOUS_OUTPUT` reuses verified game binaries when
the contract, framework and Odin adapters still match. It refreshes only the
external GDScript driver and isolated project/user names, records that provenance,
and refuses changed compiled sources.

This covers content authoring and gameplay in an existing weapon family. It does
not measure human authoring time or runtime performance, and supplies no new
weapon-family, art-production, browser, save or migration acceptance evidence.
