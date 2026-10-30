# Typed authored archetypes

For ordinary scripted actors, use [Script_Archetypes](adapter-bindings.md) over
these foundations. It owns callback configuration and retains appearances, so its
source registry may close after initialization. The lower-level API below keeps
its explicit borrowing requirements.

Use a stable gameplay ID to connect a value definition to local scene assets:

```odin
assets: scenegd.Archetype_Assets(Enemy_Definition)
scenegd.archetype_assets_init(&assets, MAX_ENEMY_KINDS)
entries := []defs.Archetype(Enemy_Definition, scenegd.Archetype_Visual){
    {id=6, definition=storm_definition, local={storm_scene, storm_style}},
}
report := scenegd.archetype_assets_publish(&assets, entries, []u32{6})
```

`definitions.Registry(Definition, Local)` is engine-independent. Definition must
be a replayable value; Local may borrow pointers. IDs include zero and are bounded
by the explicit ID limit (maximum 65,536). Publication rejects duplicates, missing
required IDs, out-of-range IDs and typed validator failures before swapping the
complete registry. Lookup is direct by ID. Reports retain their diagnostic text.
The pure registry owns arrays, not objects referenced by Local.

`Archetype_Assets` adds Godot ownership: each entry must have a PackedScene and may
have an appearance Resource. Publication retains every accepted resource before
releasing the prior set. Failed publication preserves the prior set. Candidates
must stay alive until publication finishes. Game-specific Resource script/range
checks belong in the extractor before calling this API.

`Archetype_Pool2(Entity, Display, Rig)` combines those registrations with typed
scene bindings. Initialize it with an immutable asset registry, a capacity, a
`select(Display)->u32` callback, and a binding factory receiving the ID, copied
definition and local assets. Present ordinary `View_Item` batches through
`archetype_pool_present`. It rejects unknown IDs and duplicate entity identities
across archetypes before changing view lifetimes. Different IDs may use different
PackedScenes and scene compositions with the same typed display interface.

Each registered scene has a `View_Pool2`; the owner partitions into fixed scratch
buffers. Steady presentation allocates no partition buffers. Scene creation still
runs normal Godot lifecycle and can fail as with an ordinary view pool. Input
preflight does not promise a transaction spanning arbitrary user `_ready` code.

Keep the parent and asset owner alive until all dependent views have been destroyed.
Destroy/recreate the pools before replacing the asset registry. Keep callback
configuration at stable addresses. Views may borrow appearance scripts only for
that lifetime. Resource pointers never enter Display, World, input or checkpoints.

Memory scales with the ID limit and per-kind capacity, even when few nodes are
active. The partition bound is 1,048,576 item slots; each individual capacity is
also bounded by `view.MAX_INDEX_CAPACITY`. During a kind change or scope reset,
retired Godot nodes may await deferred deletion, as in the underlying view pool.
Applications with very large catalogs may prefer their own shared-capacity scene
pool or a specialized renderer. This convenience layer is optional.

Scrapyard stores one `ScrapEnemyArchetype` Resource in `archetypes/enemies` per enemy.
It references a `MobDef` (whose ID is the wire identity), a PackedScene and a
`ScrapEnemyStyle`. The loader validates definitions, required IDs and exact style
scripts, publishes the complete set, then binds the scene's one appearance input.
The enemy scene has no per-kind Resource slots or fixed skin array. Its standalone
preview exports one appearance so it remains editable without a game/session.
