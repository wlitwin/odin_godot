# Pure-Odin events — `events.Event(T)`

Use `events.Event(T)` for typed notifications between Odin scripts in the same
library. `import events "godot:events"` provides an observer list that invokes
subscribers through direct procedure calls, without engine dispatch, Variant
boxing, or allocation during emit. Engine signals also perform a StringName
lookup, box arguments into Variants, dispatch through `Object::emit_signal`,
and call back into Odin through C. Use those signals when the notification
crosses a module or engine boundary.

```odin
import events "godot:events"

Spawner :: struct {
	owner: gd.Node2d,
	slow_changed: events.Event(f64), // untagged field: private, pure Odin
}

// publisher
events.emit(&self.slow_changed, 0.5)

// subscriber (ctx points to the receiving script struct, as in flow callbacks)
events.subscribe(&spawner.slow_changed, self, enemy_on_slow, owner_id)

enemy_on_slow :: proc(ctx: rawptr, factor: f64) {
	self := cast(^Enemy)ctx
	self.slow = f32(factor)
}
```

The payload can be any Odin type, including a struct, slice, or pointer. It is
passed by value and checked at compile time, without the `gd.Int`/`f64`
restrictions or Variant marshalling required by engine signals. Normal Odin
value-copy and referenced-data lifetime rules still apply.

<a id="which-tool-when"></a>

## Choose events or engine signals

| | use |
|---|---|
| Crossing a boundary: another script module, GDScript, `.tscn` `[connection]`s, the Inspector, the editor | **engine signal** (`gd.Signal1(int)` / `gd.SignalN(struct{...})` fields): uses the engine's connection mechanism |
| One-to-many notifications between scripts in the same module/dll | **`events.Event(T)`**: direct calls, typed payloads |
| Per-bullet or per-frame-per-entity loops | **batch and iterate** when callback overhead matters (see barrage's SOA bullet field) |

<a id="two-rules-for-safe-use"></a>

## Module and subscriber lifetime requirements

**1. Same module only.** Script modules are isolated dlls with no cross-imports
([modules](modules.md)). A subscription is a raw proc pointer plus a struct pointer, and
these are not a supported cross-module interface: typeids are module-local,
and `rt.script_of` returns nil for another module's class. When a trigger
comes from another module, make one engine call into the module that owns the
event, then use `Event` to notify its subscribers. Barrage's SlowEnemies powerup
uses this arrangement:
`pickup.odin` (powerups module) makes one `object_call("slow_all_enemies")` into the
Spawner (enemies module), which `events.emit`s to every subscribed Enemy:

```text
powerups dll                       enemies dll
pickup ── object_call (engine) ──> spawner ── events.emit (direct) ──> enemy
                                                                  ├──> enemy
                                                                  └──> enemy
```

**2. Unsubscribe before the subscriber dies.** The subscription stores your struct
pointer raw; if the script instance is freed first, the next emit is a use-after-free.
For a node script, do it in `<class>_exit_tree`, which fires on `queue_free` *and* on scene
teardown:

```odin
enemy_exit_tree :: proc(self: ^Enemy) {
	if sp := find_spawner(self); sp != nil {
		events.unsubscribe_owner(&sp.slow_changed, u64(gd.object_get_instance_id(cast(gd.Object)self.owner)))
	}
}
```

The publisher frees its list in its own `exit_tree` with `events.destroy`.

## Hot reload

Subscriptions store procedure pointers. Before moving a live publisher or
subscriber to a new DLL generation, the core requires a reload hook. Without
one, it keeps the instance on the old generation and emits a warning. A reload
that changes layout also reallocates structs, invalidating old ctx pointers.
Resubscribe in `<class>_reload`, using an owner tag to remove stale
subscriptions first. This makes repeated calls safe regardless of the order
in which instances are rebound, as with [flow](workflow.md)'s `Action` trees:

```odin
enemy_subscribe_slow :: proc(self: ^Enemy) {
	sp := find_spawner(self)
	if sp == nil {return}
	id := u64(gd.object_get_instance_id(cast(gd.Object)self.owner))
	events.unsubscribe_owner(&sp.slow_changed, id) // idempotent
	events.subscribe(&sp.slow_changed, self, enemy_on_slow, id)
}

enemy_ready  :: proc(self: ^Enemy) { /* ... */ enemy_subscribe_slow(self) }
enemy_reload :: proc(self: ^Enemy) { enemy_subscribe_slow(self) }
```

After all affected reload hooks return, the old generation may unload. Each
hook must therefore remove or replace subscriptions holding an old fn or ctx
pointer before returning.

This applies to `//gd:tool` scripts and editor-driven reloads. Ordinary game
scripts do not hot-reload during a run.

## Semantics reference

- `subscribe(e, ctx, fn, owner = 0)` appends the subscription. Duplicates are allowed,
  and each fires once. `owner` is a caller-chosen tag (use the engine instance id) for
  bulk removal.
- `unsubscribe(e, ctx, fn)` removes the first `(fn, ctx)` match.
- `unsubscribe_owner(e, owner)` removes every subscription with that tag.
- `emit(e, payload)` calls live subscribers in subscription order. It is
  reentrancy-safe: subscribing during an emit defers to the *next* emit, and
  unsubscribing during an emit takes effect immediately (a not-yet-called subscriber
  removed mid-emit will not fire). Nested emits are supported.
- `count(e)` returns the live count, `clear(e)` drops all subscriptions, and
  `destroy(e)` frees the event. `destroy` must not run from inside one of the event's
  own callbacks.
- **Not thread-safe.** Use events on the main gameplay thread.

The package is engine-agnostic (no `godot` import) and unit-tested standalone:
`tests/events/run.sh` (suite entry `events`, sentinel `EVENTS_OK`).
