# Pure-Odin events — `events.Event(T)`

Godot signals are the engine's cross-boundary contract, and every emit pays for that
generality: a StringName lookup, one Variant boxed per argument, `Object::emit_signal`
connection dispatch, then the C trampoline back into your script. When both ends of a
notification are Odin scripts **in the same dll**, that whole round trip is overhead.
`import events "godot:events"` gives you a typed observer that dispatches with direct
proc calls instead — no engine, no boxing, no allocation on the emit path. This is the
same split C# users know: C# `event` inside the assembly, Godot signals at the edges.

```odin
import events "godot:events"

Spawner :: struct {
	owner: gd.Node2d,
	slow_changed: events.Event(f64), // untagged field: private, pure Odin
}

// publisher
events.emit(&self.slow_changed, 0.5)

// subscriber (ctx round-trips to your struct, like flow's callbacks)
events.subscribe(&spawner.slow_changed, self, enemy_on_slow, owner_id)

enemy_on_slow :: proc(ctx: rawptr, factor: f64) {
	self := cast(^Enemy)ctx
	self.slow = f32(factor)
}
```

The payload is any Odin type — a struct, a slice, a pointer — passed by value, fully
typed at compile time. There is no Variant in the path, which also means there is no
`gd.Int`/`f64`-only restriction and no marshalling cost for big payloads.

## Which tool when

| | use |
|---|---|
| Crossing ANY boundary: another script module, GDScript, `.tscn` `[connection]`s, the Inspector, the editor | **engine signal** (`gd.Signal1(int)` / `gd.SignalN(struct{...})` fields) — the engine is the contract |
| Decoupled one-to-many between scripts in the SAME module/dll | **`events.Event(T)`** — direct calls, typed payloads |
| The hottest loops (per-bullet, per-frame-per-entity) | **neither** — batch the data and iterate (see barrage's SOA bullet field); a callback per element is still a call per element |

## The two rules that keep it safe

**1. Same module only.** Script modules are isolated dlls with no cross-imports
([modules](modules.md)); a subscription is a raw proc pointer + struct pointer, and
handing those across dlls silently defeats that contract (typeids are module-local;
`rt.script_of` on another module's class returns nil by construction). The canonical
shape when the *trigger* comes from another module: the cross-module edge stays **one
engine call** into the module that owns the event; the fan-out inside the module is the
`Event`. Barrage's SlowEnemies powerup is the living example — `pickup.odin` (powerups
module) makes one `object_call("slow_all_enemies")` into the Spawner (enemies module),
which `events.emit`s to every subscribed Enemy:

```text
powerups dll                       enemies dll
pickup ── object_call (engine) ──> spawner ── events.emit (direct) ──> enemy
                                                                  ├──> enemy
                                                                  └──> enemy
```

**2. Unsubscribe before the subscriber dies.** The subscription stores your struct
pointer raw; if the script instance is freed first, the next emit is a use-after-free.
For a node script that means `<class>_exit_tree` — it fires on `queue_free` *and* scene
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

Same trap as [flow](workflow.md)'s `Action` trees, same fix: subscriptions cache raw
proc pointers into the scripts dll, so a hot reload leaves them pointing at stale code
(and a changed-layout reload reallocates structs, dangling the ctx pointers too). The
self-healing pattern is owner-tagged resubscription in the `<class>_reload` hook —
idempotent and order-independent across the reload's rebind loop:

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

(Ordinary game scripts never hot-reload mid-run — this matters for `//gd:tool` scripts
and editor-driven reloads.)

## Semantics reference

- `subscribe(e, ctx, fn, owner = 0)` — appends; duplicates allowed, fire once each.
  `owner` is a caller-chosen tag (use the engine instance id) for bulk removal.
- `unsubscribe(e, ctx, fn)` — removes the first `(fn, ctx)` match.
- `unsubscribe_owner(e, owner)` — removes every subscription with that tag.
- `emit(e, payload)` — calls live subscribers in subscription order. Reentrancy-safe:
  subscribing during an emit defers to the *next* emit; unsubscribing during an emit
  takes effect immediately (a not-yet-called subscriber removed mid-emit won't fire);
  nested emits are fine.
- `count(e)` / `clear(e)` / `destroy(e)` — live count, drop-all, free. `destroy` must
  not run from inside one of the event's own callbacks.
- **Not thread-safe** — a main-thread gameplay tool, like the rest of a script.

The package is engine-agnostic (no `godot` import) and unit-tested standalone:
`tests/events/run.sh` (suite entry `events`, sentinel `EVENTS_OK`).
