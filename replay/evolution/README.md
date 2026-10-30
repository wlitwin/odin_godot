# Revision contracts and explicit conversion

Use these cold-path tools before changing a saved or networked value type. They
freeze representation contracts; they do not infer compatible gameplay behavior.

```odin
source, report := evolution.freeze(Old_World, "game_revision_12", "World_12")
// source is owned; write only after report.error == .None, then delete(source).
manifest, report := evolution.contract(Old_World, CONTENT_12)
scaffold, report := evolution.scaffold(Old_World, New_World,
    "game_revision_conversion", "World_12", "World_13")
```

`freeze` recursively emits all type dependencies into one self-contained Odin type.
It retains field names/tags, fixed array bounds, scalar widths, enum names/values
and bit-set definitions. It normalizes native layout and endianness: Replay's
canonical encoding, not `memcpy` layout, is the contract. No imports of live game
types remain. Choose globally unique Odin package names for different revisions.

Supported shapes are canonical scalars, structs, fixed arrays, enums and bit sets.
Unions, enumerated arrays and unsupported shapes fail with an owned diagnostic
and no generated source. Existing schema union support remains available; freeze
those revisions with explicitly authored source until a union-aware generator is
provided. This tool uses the complete authority projection.

`contract` returns owned JSON containing the semantic ID, schema fingerprint,
canonical schema text and leaf field paths/kinds/widths/wire offsets, privacy,
enum meaning and bit masks. Check it into source control beside the frozen type.
Compare regenerated manifests in CI. It does not freeze reducer code, authorize
an old recording for a new reducer, or replace a signed build manifest.

`scaffold` handles additive schema changes. Its generated procedure deliberately
returns failure until the author supplies target defaults and changes the review
flag. Every added leaf is listed by full path, including every array element.
Removed fields, changed widths/kinds, enum meanings/signedness, privacy changes and
unions/enumerated arrays require custom authored conversion code instead of an automatic scaffold.

```odin
defaults := New_Catalog{} // Deliberate decision: old enemies gain no pulse attack.
paths := []string{"$.enemy.pulse.windup", "$.enemy.pulse.damage"}
value, report := evolution.copy_preserved(old, defaults, paths)
report = evolution.verify_preserved(old, value, paths)
```

`copy_preserved` validates both values, copies matching canonical leaf bytes into
the supplied target defaults and decodes transactionally. It requires exactly one
acknowledgement for every added field and rejects extra/duplicate acknowledgements.
It does not validate game invariants: call the target model's validator before
publishing a checkpoint. `verify_preserved` checks every old leaf; separately
assert the chosen new defaults. `remove_added` provides an explicit inverse
projection for fixture builders, acknowledging each discarded leaf.

These helpers compile schemas, allocate scratch and use linear path lookup within
field loops. They are intended for authoring, offline upgrades and tests, not the
simulation tick or a per-frame presentation path.

Scrapyard demonstrates this with a fully frozen
[`content49`](../../examples/replay_scrapyard/shared/revisions/content49/catalog.odin),
its committed contract, and the actual content49→50 checkpoint converter. Run:

```sh
mkdir -p /absolute/staging/revision
nix develop --command odin run examples/replay_scrapyard/tools/revision \
  -collection:godot=. -- /absolute/staging/revision
nix develop --command odin test tests/replay_evolution -collection:godot=.
```

The example command writes a reviewable pair of frozen catalogs, JSON contracts
and a disabled conversion scaffold into the staging directory. Review before
adopting them; retain the historical reducer and real old-file fixtures.
