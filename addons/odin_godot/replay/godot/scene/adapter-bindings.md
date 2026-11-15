# Typed scene adapters

Use typed scene adapters to pass detached gameplay display values into ordinary
Godot scripts. The game chooses those values and their lifetime boundaries; shared
runtime owners handle script resolution, borrowed pointers, asset retention,
callback configuration, entity membership, and diagnostics. Scrapyard uses these
bindings for authored enemy scenes and permanent runner scenes, where runner
means the game's character rather than the runtime advancing simulation.

## Script descriptors

`Script_View(Value, Script)` has one optional `validate` callback returning a
`definitions.Report` identifying the exact failed component. The display type must
be a bounded replayable value. Script pointers, local clocks and Godot objects
belong to the view script, not its display value.

```odin
descriptor := scenegd.Script_View(Runner_Display, Runner_View){
    present  = runner_present,
    validate = runner_validate,
}
```

Return `{}` on success or `definitions.problem(.Invalid, field, message)` on
failure. Older descriptors using `valid = check` must replace it with
`validate = validate_view` and retain every check from the predicate. `valid`
is no longer a descriptor field, so old initializers fail compilation.
In an archetype binding, validation checks scene
components before `configure` supplies the appearance. A directly bound scene
that requires an authored appearance must validate that appearance as well.

`Script_Binding(Value, Script)` stores that descriptor by value and borrows a
permanent authored node. `script_bind` resolves and validates its script;
`script_present` passes a detached value; `script_release` invokes optional
retirement and releases the binding, without freeing the node. Release before the
node is freed or rebound. It never decides that a body generation, warp or epoch
change should replace a permanent scene. Scrapyard's runner retains its node and
handles those display transitions explicitly in its script.

For entity scenes with authored appearances:

```odin
descriptor := scenegd.Script_Archetype(Enemy_Display, Enemy_View, Enemy_Style){
    view = {
        present  = enemy_present,
        validate = enemy_validate,
        retired  = enemy_retire,
    },
    configure = enemy_configure, // proc(^Enemy_View, ^Enemy_Style)->defs.Report
}
views: scenegd.Script_Archetypes(Enemy, Enemy_Display, Enemy_View, Enemy_Style)
report := scenegd.script_archetypes_init(&views, &assets, parent, CAPACITY,
    select_kind, descriptor)
```

This owner copies configuration, allocates stable callback contexts, and retains
appearance resources. Underlying view pools retain their scenes. The source
registry can close after successful initialization. Keep the owner at a stable
address and destroy it before its parent/script module disappears. It resolves
the root script after `_ready`, validates scene components, resolves the exact
appearance script, then calls configure. Configure validates/applies appearance;
scene validation should not require appearance configuration to have happened yet.

`script_archetypes_present` returns an owned diagnostic on failure. `retired` must
accept partial initialization and end all borrowed-resource use; queued node
removal completes later. Ordinary process callbacks should stop after retirement.
Nodes/scripts remain Godot-owned. No callback may reenter or mutate membership of
its view owner.

## Iteration and scope

`view_pool_visit`, `archetype_pool_visit` and `script_archetypes_visit` provide typed
entity handles and rigs/scripts to a callback with a typed user pointer. Use them
to drain local visual notices without depending on bucket/index storage. Borrowed
storage must not escape the visit. Matching `*_stats` functions provide aggregate
node/paint/property counters.

`view.Scope_Tracker(Key)` compares explicit inputs:

```odin
scope, error := view.scope_update(&tracker,
    {epoch, reset_serial, observed_tick},
    World_View_Key{run, floor},
    rewind_resets = true)
```

The caller chooses the key and whether backwards observation time resets a view
lifetime. Forward ticks and unchanged keys preserve scope; epoch/reset/key changes
advance the revision. Zero/stale epochs, unsupported key types and revision
exhaustion fail without changing the tracker. It does not infer authority, sample
prediction, use correction counts as reset events, or know what a floor means.

## Diagnostics and data ownership

`view_pool_problem` and `archetype_pool_problem` retain detailed diagnostics while
existing low-level presentation functions still return their original error enum.
Script-based owners return the diagnostic directly. Errors identify archetype,
scene path, entity key and the component/field supplied by the typed validator.
Input validation runs before membership changes. Scene instantiation and
`_ready` code can still have side effects that these checks cannot roll back.

`Resource_Batch` loads a bounded directory of `.tres`/`.res` resources, retaining the
whole candidate set until `resource_batch_destroy`. Loading failure publishes no
partial batch. It rejects reinitializing a live batch, preserving the existing one.
Use `resource_script(resource, Script, path)` for checked borrowed script access,
or `bake_resource(ctx, resource, Script, path)` inside an extractor.

`bake_integer(ctx, u16, source, minimum, maximum, path)` checks explicit domain and
representation bounds before narrowing. Supported targets are fixed 8/16/32-bit
signed/unsigned integers. Inspector ranges are editing hints, not inferred game
validation. Complex mappings, nested dependencies and cross-field rules remain
explicit functions. Scrapyard shares one `defs.bake_mob` among live admission,
artifact export, and previews, so each path uses the same validation function.

## Optional generation

Place this declaration above the script's `package` line:

```odin
//gd:replay_view value=value,present=enemy_present,validate=enemy_validate,retired=enemy_retire,appearance=skin,configure=enemy_configure
```

`value` names a direct display field; `appearance` names a direct typed Resource
script pointer. `present` is required, `validate` and `retired` are optional;
`appearance` and `configure` must appear together. Procedures are ordinary
same-package Odin procedures. The script must extend Node2D or a compatible class.

The generated `<snake_script_name>_replay_binding()` returns `Script_View` or
`Script_Archetype`, with compile-time assertions on callback signatures. Types come
from the named fields, so imported display types need no duplicate import/mapping
in generated code. Unknown/duplicate options and missing fields fail generation.
It emits no simulation state, wire registration, sampling policy, signals or extra
lifecycle callbacks. Unannotated scripts keep their existing generation behavior.

Handwritten descriptors use exactly the same public helpers. Actual scene nodes,
Resource scripts and required components are validated in Godot; code generation
alone cannot prove that every PackedScene has the expected hierarchy.

## Authoring previews

Use existing typed `onready` fields for composed scripts:

```odin
charge: ^ScrapChargeView `gd:"onready=Charge"`,
```

Scrapyard's `ScrapEnemyPreview` Resource references a MobDef and supplies sample
attack/warning/charge state. The same mob extractor validates the definition, and
a detached display is baked on scene startup. A pulse radius comes from the
selected definition without a switch over known enemy IDs. The
[authoring tools](../../editor/README.md) provide explicit refresh of isolated
preview data; live-bound views reject refresh. Appearance and scene-local
animation use the live-play display interface while remaining independent of
Session/World.
