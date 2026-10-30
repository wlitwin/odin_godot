# View pool foundations

The [Godot bridge goal](../../docs/replay/godot-bridge-plan.md) adds typed
entity bindings and detached projections above the existing `Nodes2` owner.

`Nodes2` now uses bounded indexed identity lookup, with a separate preflight index
for each presentation batch. Zero and duplicate keys are rejected before changing
scene instances. Retained keys retain their node; absent identities retire before
new ones allocate, so a full pool can replace every identity in one call. The map
preserves lowest-vacant-slot allocation and performs no per-frame Odin allocation.
A fully retained membership batch skips capacity scans and index/free-slot rebuilds
after complete preflight. Sparse indexes clear only recorded occupied buckets; each
index adds four bytes per configured entry for those bucket locations.
Scene creation/free still occurs when identities enter/leave.

Capacity is 1–65536. Each index uses a power-of-two table with at most half its
buckets occupied. Lookup is expected constant time, with a bounded full-table
probe limit; it is not a worst-case constant-time hash guarantee. The extra index,
free-slot and cached-value arrays increase presentation-owner memory in exchange
for fewer repeated scans. They do not enter World, history or network packets.

## Optional property caching

Existing callers keep `cache_properties=false`, so every call reapplies position,
rotation, scale and modulation as before. An adapter that exclusively owns those
four root properties can opt in:

```odin
views.cache_properties = true
ok := rgd.nodes_present(&views, instances)
```

The first presentation applies all properties. Later calls apply only changed
values. The cache compares desired values, not Godot state, so it does not need
four engine reads per node. If animation/editor/game code changes an owned property,
invalidate before the next presentation:

```odin
rgd.nodes_invalidate(&views, entity_key) // one view
rgd.nodes_invalidate(&views)             // all views
```

Invalidation does not respawn the view or restart effects. Turning caching off
reapplies all values. Keep independently animated children separate from root
properties controlled by this binding, or explicitly invalidate after an external
write. Callers still own any game-specific child state and cleanup policy.

`Nodes2.stats` counts scene creations/retirements and property writes/skips. The
two indexes count probes. These are local diagnostics, not simulation state.

## Identity and ownership

`view.handle_key(handle)` encodes the complete nonzero pool generation and index.
Use a separate view pool for each source pool/timeline scope; the key does not
globally identify a pool. An invalid handle returns zero. A replacement generation
gets a new view. Clear views at an explicit session/epoch boundary when identities
can otherwise repeat. The typed owner below handles scope changes automatically.

The parent must outlive `Nodes2`. It owns the scene reference and its child views;
external code may borrow a node from `nodes_get` but must not free it behind the
owner. `nodes_destroy` releases references and queues node retirement. Engine
retirement completes asynchronously. Failure to instantiate a scene is explicit;
the existing API does not promise rollback of earlier scene lifecycle operations
in that call.

Pure index tests cover duplicates, collisions, capacity, reset and handle lifetime.
`tests/replay_nodes/run.sh` exercises actual Godot properties, retained/replaced
instances, opt-in behavior, external-write invalidation and resource retirement.
The benchmark compares the preserved old owner, indexed owner and cached owner
with the same scene/input workload. Timings isolate presentation calls, not GPU
rendering or total game performance.

## Typed entity bindings

`View_Pool2(Entity, Value, Rig)` owns one source entity pool's views. `Value` is a
pointer-free presentation value; `Rig` caches child nodes and may own local resources.
The parent and callback `user` must outlive the owner. `attach` returns a rig once
per new view; `paint` runs initially and when Value changes; `detach` releases rig
resources before the node retires. A failed attach also receives detach, so cleanup
must accept a partially initialized rig. Callbacks must not reenter this owner.

```odin
Actor_UI :: struct { health: i32 }
Actor_Rig :: struct { label: gd.Label }
views: rgd.View_Pool2(Actor, Actor_UI, Actor_Rig)
binding := rgd.View_Binding(Actor_UI, Actor_Rig){
    attach = proc(_: rawptr, node: gd.Node2d) -> (Actor_Rig, bool) {
        label := cast(gd.Label)gd.get_node(node, "Health")
        return {label}, label != nil
    },
    paint = proc(_: rawptr, rig: ^Actor_Rig, ui: Actor_UI) {
        gd.set_text(rig.label, fmt.ctprintf("%d", ui.health))
    },
}
ok := rgd.view_pool_load(&views, parent, "res://actor.tscn", 128, binding)
// items contain typed handles and detached Entity_View(Actor_UI) values.
error := rgd.view_pool_present(&views, {epoch, view_revision}, items)
// When leaving: rgd.view_pool_destroy(&views).
```

The typed owner caches root position/rotation/scale/color automatically. Reserve
those properties for this owner. `view_pool_invalidate(&views, handle)` invalidates
both root properties and typed paint; omitting the handle invalidates all views.
Do not mutate or free borrowed nodes outside these ownership rules. A changed
scope recreates every rig, even when numeric handles repeat. Older epochs are
rejected; revision is a caller-supplied reset token, not an authority credential.
Generations distinguish reused entity slots within one scope.

Invalid values, duplicates and capacity are preflighted before scene changes.
Instantiation/attachment can fail after lifecycle work starts; that failure clears
the typed owner and is explicit. It does not restore old scene nodes. Payload
comparison uses value equality, not padding bytes. Floating values that differ
continually will repaint; choose a quantized UI value when appropriate.

## Detached projection and sampling

`replay.project(&timeline, tick, proc(World)->Display)` selects a retained frame and
returns a pointer-free value. The callback receives World by value and cannot
mutate history through a borrowed pointer; timeline mutation reentry is refused.
It does not promise zero copying or automatically shrink the result. Keep Display
small when reducing copy costs matters. Hello demonstrates a full view batch for
clarity; its small World is actually smaller than that batch.

`view.project_pool` fills a reusable bounded `Projection(Entity, Value)` from a
detached pool. Its typed entity callback returns `(Entity_View(Value), include)`;
false filters a member. Invalid/capacity failures preserve the previous output.
Projection owners allocate at initialization and allocate nothing per call.

`projection_select` requires explicit predicted, observed or authoritative input.
`Local_Predicted_Remote_Observed` takes local-owner entities from prediction and
others from observation, preserving each item's source and tick. Missing sources,
mismatched scopes, and conflicting lifetimes/ownership in one slot are errors.
Selection never grants simulation authority. Feed sources from the corresponding
runner APIs; labeling a value does not establish its provenance.

`projection_blend` interpolates poses only for matching handles and teleport `cut`
values. Before alpha reaches one, membership and discrete UI come from the older
sample. Changed cuts snap the pose; changed scopes choose the newer batch directly.
It refuses mixed-source interpolation and backward tick pairs. For mixed displays,
interpolate observation first, then select local prediction. Keep destination and
source owners distinct. Projection storage is presentation-owned and must not be
mutated while another operation consumes it.

See the compile-checked Hello and `tests/replay_nodes` examples, and
[typed bridge evidence](../../docs/replay/results/typed-views-2026-09-20/README.md).

## Animation without repainting data

An optional `View_Binding.frame(user, rig, value, dt)` hook advances presentation
animation even when the detached Value is unchanged and `paint` is skipped.
Call `view_pool_frame(&views, dt)` once after presenting a successful batch.
It visits live entries only and rejects negative/nonfinite delta without callbacks.
The callback receives the retained detached value and may animate rig-owned children;
root pose/scale/modulation remain owned by the pool. Callbacks must not reenter or
change pool membership. Simulation time and presentation time remain separate.

Scrapyard's enemy bridge uses paint for texture/telegraph/health changes and frame
for idle/attack/death animation, status flicker and hit wobble. A cached unchanged
value therefore does not freeze an idle animation. This hook is optional for
existing bindings; no frame callback is invoked by `view_pool_present` itself.
