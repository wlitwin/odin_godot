# Revision contracts and explicit conversion

Run these tools during authoring or offline upgrades before changing a saved
or networked value type. They generate frozen type definitions, schema
manifests, and conversion scaffolds. The author must still decide whether the
old and new gameplay rules are compatible.

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

`scaffold` generates a starting procedure for additive schema changes. It
returns failure until the author supplies target defaults and changes its review
flag. The generated list names every added leaf by full path, including each
array element. Removed fields, changed widths/kinds, enum meanings/signedness,
privacy changes, and unions/enumerated arrays require a custom conversion.

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

These helpers compile schemas and allocate scratch. They search paths linearly
inside field loops, so keep them in authoring tools, offline upgrades, and tests.
Do not call them from a simulation tick or each presentation frame.

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
