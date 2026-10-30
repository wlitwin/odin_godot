# Declarative visual and audio routes

`Effect_Route2(Event, Value, Rig)` connects a typed event projection, bounded visual
cue pool and typed scene binding. `Audio_Route(Event)` connects an event-to-sound
projection, bounded voices and a consumption ledger. Both consume ordinary journal
changes, preserving occurrence IDs through update, confirmation and cancellation.
They remain outside World and never rerun gameplay to create presentation.

A visual binding supplies:

- `project(Event) -> (Entity_View(Value), include)` for detached initial geometry
  and paint data. Prefer stable event-kind selection.
- Optional `animate(view, age, seconds) -> view` for root fade/motion over time.
- `View_Binding(Effect_State(Value), Rig)` to cache children at attachment and paint
  value, age, duration and confirmation. Detach releases any rig-owned resources.

```odin
route: rgd.Effect_Route2(Event, Flash_Value, Flash_Rig)
ok := rgd.effect_route_load(&route, parent, "res://flash.tscn", epoch,
    0.3, binding, capacity=32)
for change in changes { rgd.effect_route_change(&route, change) }
error := rgd.effect_route_frame(&route, render_delta)
```

Journal policy already determines speculative or watched delivery. Default route
policy Journal follows it. Confirmed delays this route until a confirmed Begin or
Confirm, useful for effects that should not be shown speculatively. The first
accepted start creates a lifetime; Update changes its value, Confirm marks it, and
Cancel retires it. Neither Update nor Confirm restarts its age or scene. Reused
slots get fresh generations and child bindings. Expired, canceled and capacity-
dropped IDs remain consumed so replay cannot restart them.

Changing the filter to exclude an active event cancels it. A later Update does
not invent a speculative Begin; use a stable event category for routing, and
ordinary value changes for animation. When a confirmed-only effect has not begun,
its Confirm may start it, subject to its consumption ledger.

`effect_route_clear` removes live visuals without forgetting consumed IDs.
`effect_route_epoch` requires a strictly newer epoch, clears visuals and resets the
ledger/bindings. `effect_route_retire` advances the floor only when the caller knows
no new Begin at or below it can arrive, including delayed watched/confirmed events.
Do not use the render clock as that frontier. Full cue pools drop new effects;
check `route.route.cues.stats`. Ledger history/per-tick capacity is explicit.
Root properties and Rig lifetimes follow the [view ownership contract](view-pools.md).
Scene instances are created on entry; bounded capacity does not mean prewarming.

For audio, the callback returns `(Audio_Cue, include)` and may borrow streams from
a presentation asset owner through `user`. Godot players retain their own stream
reference while assigned. Destroy the route before the parent or borrowed callback
owner. Each route owns its own bounded voices and ID ledger:

```odin
audio: rgd.Audio_Route(Event)
ok := rgd.audio_route_init(&audio, parent, epoch, sound_for_event,
    &sound_bank, .Confirmed, world_voices=8, screen_voices=2)
for change in changes { rgd.audio_route_change(&audio, change) }
```

Update moves an active spatial voice; it does not change the clip or restart
playback. Confirmed-only routes play once upon confirmation. Cancel stops only a
voice still owned by that occurrence, so canceling a stolen old voice cannot stop
its replacement. Full voice pools steal in bounded round-robin order; consumed
IDs remain tombstoned. `audio_route_epoch` clears voices under a newer epoch and
`audio_route_retire` has the same safe-frontier requirement as visual routes.
Use `audio_pool_volume(&audio.pool, volume)` for a local volume setting.

The pure `view.Cue_Route(Event, Value)` is also usable without Godot. Native and
executed WASM corpus checks cover lifetime/overflow/epoch behavior. Actual Godot
checks cover scene reuse, transform update, confirmation without restart, audio
voice identity, cancellation, epoch rejection and resource cleanup. The scene
fixture is compile-checked for WASM; it is not a browser audio-device claim.

## Routes that need event identity or history

`audio_route_init_change` accepts a callback with `(user, Change(Event))`, exposing
the original occurrence ID/tick, change kind and confirmation state. It shares the
same bounded voices, policy and consumption ledger as `audio_route_init`; choose
one initializer. Cancel retires matching voices without calling either projector.
A contextual projector sees the original Confirm even when the route delays its
start until confirmation, so it can choose the correct historical placement.

Scrapyard uses this callback for pitch derived from the occurrence ID and wound
positions reconstructed at the event tick. Event-only routing remains available
when a sound depends only on its gameplay payload.
