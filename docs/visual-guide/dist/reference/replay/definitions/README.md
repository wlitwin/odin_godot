# Immutable authored definitions

`definitions.Store(Value)` publishes bounded canonical values under a `Ref` containing
semantic version, schema fingerprint and content checksum. Resource handles, nodes,
strings, slices and pointers cannot enter Value. Reads return copies. The store is
an owner outside World; do not copy it or mutate its metadata/entries directly.

```odin
store: defs.Store(Weapon_Definition)
report := defs.init(&store, 16)
// Destroy also cleans up a failed init.
ref, report := defs.publish(&store, definition, GAME_CONTENT_VERSION)
value, found := defs.get(&store, ref)
```

Publication validates schema values, then an optional typed validator returning a
`Report`. Failure preserves existing entries. Reports own bounded 256-byte path
and message buffers, including after schema destruction; longer diagnostics are
truncated. `report_path`/`report_message` borrow text from the report you supply.
Repeat publication of identical canonical values reuses a reference; changed
values or semantic versions produce distinct references. Padding is excluded.
The fingerprint/checksum uses Replay's existing FNV codec, not cryptographic
identity. A matching reference with different canonical bytes is rejected as a
collision within the store. Authenticate imported content through the existing
transport/admission layer; this API alone is not a trust boundary.

There is no automatic eviction. `pin(ref)` protects a version needed by live
history, pending work or checkpoints; `remove` and `destroy` refuse pinned values.
Call `unpin` after the last corresponding dependency ends. Multiple pins count
independently. Pinning is explicit because the store cannot infer references
hidden in arbitrary World layouts. Build/admit a complete dependency set before
starting or restoring a simulation. Missing definitions must fail admission; do
not silently substitute the latest revision.

Two valid approaches:

- Embed baked values in World/checkpoints. Replay owns their lifetime naturally;
  no external lookup or store pin is needed after copying. Cavecrawl uses this.
- Store only portable definition references in World and keep a frozen catalog
  available to the reducer. Pin every version its retained history may read, and
  serialize/transfer those dependencies with checkpoints before allowing restore.
  Never hide mutable Resource data behind a reference to reduce history size.

The store uses bounded linear lookup; it is intended for definition catalogs,
not per-entity hot loops. It allocates at initialization, and publication/read/pin
operations allocate nothing internally. Schema and diagnostics retain their
usual compiled-module lifetime. Access and callbacks must be serialized; callbacks
must not mutate/reenter the same store.

# Godot baking

`scenegd.bake` runs a typed extractor against an authored source and publishes
only after complete success. Source can be a Resource pointer, typed script value,
or a fixed batch. The source is borrowed synchronously; it must stay alive during
extraction. The output has the store's pointer-free canonical value type.

```odin
ref, report := scenegd.bake(&store, source, GAME_CONTENT_VERSION,
    proc(source: Source, ctx: ^scenegd.Bake_Context) -> Definition {
        root := scenegd.bake_scene2(ctx, source.scene, "$.scene")
        spawn, ok := scenegd.bake_marker2(ctx, root, "Markers/Spawn")
        count := scenegd.bake_int(ctx, source.count, 0, 32, "$.count")
        return Definition{spawn=spawn, count=u16(count)}
    })
```

The first `bake_fail` wins. Numeric narrowing follows validation. Schema checks
and an optional typed validator run before publication. Application rules such as
collision geometry, wave limits and cross-field constraints remain explicit.

`bake_scene2` owns temporary detached scene instances, destroying them on success
and every failure path. The context supports at most 16 simultaneous scenes.
Roots must be Node2D with identity transform. `bake_marker2` accepts nested Node2D
ancestry and composes local transforms into root-local coordinates; top-level
ancestors and nonfinite positions are rejected. Detached extraction does not run
`_ready`, but scripts/resources can still have constructors: use authored data
scenes appropriate for loading. Do not free or retain a returned temporary node.

Presentation PackedScenes remain separately owned by the application. Retain them
only after a successful bake and release old references when their presentations
retire. Cavecrawl demonstrates atomic replacement of a two-floor definition set
and its retained scenes. Resource edits after baking cannot mutate the values.

No reflection annotations or generator are required. The typed manual extraction
keeps authored paths and game constraints visible and remains compile-checked on
native and WASM targets. `tests/replay_definitions` covers store contracts;
`tests/replay_nodes` exercises actual detached scene extraction and cleanup.

# Canonical build artifacts

`artifact_export(&store, ref, source_digest)` returns owned envelope bytes from an
already validated immutable definition. `artifact_import(&store, bytes, semantic,
source_digest)` validates exact schema, semantic contract, length, checksum and
canonical values before publishing. An overload accepts a typed game validator.
Passing source zero accepts any source digest; a nonzero value requires a match.
Callers delete export bytes. This remains corruption detection, not authentication.

Artifacts reuse the canonical schema envelope with definition kind `0x4446` and
file-format epoch 1. The metadata tick holds the optional authoring-source digest;
it grants no authority and schedules no simulation work.

Scrapyard has one typed Godot extractor for interactive admission and explicit
headless export. `tools/stock.py` invokes `dev/export_content.tscn`, records source
hashes and verifies build provenance; it never interprets gameplay TRES fields.
Its headless stock code decodes the committed artifact. Use `--check` in CI to
reject changed nested resources or stale artifact/receipt pairs without Godot.
See the [complete authoring workflow](../../examples/replay_scrapyard/authoring-tools.md).

The [typed archetype registry](../godot/scene/archetypes.md) associates these value
contracts with separately owned local scenes. [Evolution tools](../evolution/README.md)
freeze revision dependencies and scaffold explicit conversions.
