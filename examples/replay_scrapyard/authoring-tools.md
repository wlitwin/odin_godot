# Adding and evolving a Replay feature

Scrapyard is the canonical example for these optional Replay helpers. The Godot
editor owns composition and local appearance; Odin value types own gameplay state,
decisions and configuration. Stormcaller exercises all four parts of the workflow. The
[typed adapter layer](../../replay/godot/adapter-bindings.md) now owns binding
configuration, asset lifetimes, view traversal and contextual diagnostics.

## Register an enemy

1. Create a `MobDef` under `data/mobs`, with a stable ID within `MAX_MOBS`. Add
   nested gameplay Resources such as `PulseDef` there; the shared extractor checks
   ranges and copies their values. Implement new behavior in the pure reducer.
2. Create a style under `visuals/enemies` and compose a scene implementing
   `ScrapEnemyView`. Edit child geometry, animation and effects normally in Godot.
3. Add a `ScrapEnemyArchetype` Resource under `archetypes/enemies`, referencing that
   definition, scene and style. The definition supplies its gameplay ID.
4. Preview the scene with its single exported `appearance`, then exercise real
   gameplay in the workbench. No new enemy-view field or skin-array mapping is needed.

The loader checks every catalog ID has a registration, rejects duplicates and
invalid scene/style references, and retains the assets for the view owner's
lifetime. The adapter selects by copied display ID; the view remains concerned
with one enemy. New IDs still require deliberate gameplay/version decisions.
[Framework API and bounds](../../replay/godot/archetypes.md).

## Bake content once

Interactive `content_load` and `dev/export_content.tscn` call the same
`scripts/content.odin` extractor. After building/importing the current project:

```sh
GODOT=/path/to/godot python3 examples/replay_scrapyard/tools/stock.py \
  --project /absolute/path/to/built/project
python3 examples/replay_scrapyard/tools/stock.py --check
```

Check in `shared/content/stock.rpldef` and `stock.manifest.json` together. Headless
servers/tests decode this artifact; there is no second gameplay-value parser.
Godot remains required to rebake authored Resources, while `--check` only needs
Python. The manifest covers nested data Resources, definition scripts, the
extractor/exporter and catalog declarations. Cosmetic scenes/styles do not change
this gameplay artifact.

The command compares project sources, checks generated binding guards, and requires
the running compiled exporter/catalog hashes to match. Resource-only edits can be
rebaked directly; extractor/type edits need a rebuilt library. Export goes to a
temporary file and must pass before replacing either committed file. An interruption
between the two replacements leaves a pair that `--check` rejects. Invalid content
never replaces the last valid pair. Source hashes/checksums are build consistency
checks, not a trust or authentication mechanism.

World receives a copied catalog. Editing a Resource after admission cannot alter
live gameplay. The host's catalog still travels in snapshots/checkpoints. Reopening
a run admits a new value; changing schemas or rules still needs version policy.

## Freeze before changing a contract

`replay/evolution.freeze` creates self-contained old value declarations;
`contract` creates a reviewable canonical manifest. `scaffold` lists additive
fields and refuses to convert until their defaults are explicitly reviewed.
Changed/removed fields require authored mapping code. The tools do not infer
historical reducer compatibility.

Scrapyard's actual old codec uses `shared/revisions/content49/catalog.odin`, with
no live type dependencies. The content49→50 converter explicitly supplies zero
pulse defaults and copies all prior canonical leaf bytes. Tests verify each prior
leaf, assert the zero defaults and decode a real old checkpoint. Use
`tools/revision` to produce a separate review directory; keep old reducers and
fixtures with their declared contracts. [API and limits](../../replay/evolution/README.md).

## Exercise the feature

Use `replay/testing.correction` to compare predicted input followed by late
correction against an uninterrupted reference, including events. Use `takeover`
to roundtrip a checkpoint, change authority epoch, continue, audit and compare.
Assert feature-specific state in the returned before/after frames.

Stormcaller tests remaining charge time, one hit, a late escape, death interruption
and old-save conversion. Its native/WASM corpus uses the same takeover helper.
The peer runner supplies bounded process/log ownership while the game's real-peer
script checks warnings, damage/dodge and convergence under configured latency.
[Harness contracts](../../replay/testing/README.md).

```sh
REPLAY_AUTHORING_OUT=/absolute/fresh/results \
  nix develop --command bash tests/replay_authoring/run.sh
```

This runs focused definition/schema/evolution/scenario checks, native/WASM feature
comparison, authored scenes/negative registrations, canonical export rejection and
real peers. It is not a full parity campaign across every game.

## Costs and scope

Measured native optimized stock loading is about 1.7 ms per call on the development
machine, versus roughly 0.25 µs for the old literal table. It compiles a schema and
validates/decodes on each cold load: about 449 KiB peak tracked allocation and
1.04 MiB cumulative allocation, with zero retained allocations. Avoid `stock()` in
tick/frame loops. Long-lived content users can keep their own compiled Store/schema.

The scene pool uses 257,152 bytes of Odin buffer payload versus 24,576 for the
previous single-scene pool at capacity 64, ID limit 8 and seven registrations:
232,576 bytes extra (about 227 KiB), excluding allocator overhead and Godot assets.
It also partitions display items by kind each presentation. We have not established
a frame-time improvement. Its purpose is authored variation and reliable ownership;
the single-scene and specialized rendering APIs remain available.

The takeover corpus still hashes to `8825198089392801664` on native and executed
WASM. Its peak is 88,527,978 tracked bytes and cumulative allocation 197,797,441,
with zero live allocations at completion. Allocation totals include testing and
cold loading; they are not steady-state simulation costs.

[Exact receipts and limits](../../docs/replay/results/authoring-tools-2026-09-20/README.md).
Kit, the sibling original game, gameplay rules and network/content versions are
unchanged by these tools.

## Current adapter declarations

The enemy script declares its display field and typed hooks once:

```odin
//gd:replay_view value=value,present=enemy_view_present,validate=enemy_view_validate,retired=enemy_view_retire,appearance=skin,configure=enemy_view_configure
```

Scriptgen produces `scrap_enemy_view_replay_binding()`. The game initializes
`Script_Archetypes` with that descriptor, a catalog and an explicit kind selector.
The owner retains the required assets and callback configuration; the candidate
registry can close immediately. Presentation and notice traversal need no raw
callback casts or access to pool/index internals.

Runner uses the simpler declaration without appearance/configure:

```odin
//gd:replay_view value=value,present=runner_view_present,validate=runner_view_validate
```

Its generated `Script_View` descriptor binds the four permanent runner scenes.
Body generations, warps and epochs still reset cues inside each runner script;
they do not respawn its node. Enemy view scope explicitly includes run/floor and
observed rewind policy through `Scope_Tracker`. Sampling and feedback policies
remain visible game code.

Both views use typed `onready` component fields. Enemy F6 scenes supply a
`ScrapEnemyPreview` Resource that references a definition and sample attack state;
there is no preview-kind switch. The sample is baked at scene startup using the
same `defs.bake_mob` function as gameplay/export. Use the isolated preview
refresh controls to admit saved gameplay data; see [the editor workflow](editor-workflow.md). Generic Resource batches and checked access/narrowing
helpers simplify that explicit mapping; codegen does not infer it from Inspector
hints or generate a second extractor.

[Adapter acceptance](../../docs/replay/results/adapter-2026-09-21/README.md) records
codegen regression, component/ownership checks, independent ID-7 preview,
native/WASM equality, real revive peers and host-crash takeover.

The [Replay editor dock and ability workbench](editor-workflow.md) now expose
validation, baking, current/stale status, Resource references, draft scaffolding,
reproduction verification and scenario jobs through Godot.
