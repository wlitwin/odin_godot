# Declarative visual and audio routes

Use effect routes to turn journal changes into visual or audio cues that retain
the same event identity through correction. `Effect_Route2(Event, Value, Rig)`
connects a typed event projection, bounded visual
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
route: scenegd.Effect_Route2(Event, Flash_Value, Flash_Rig)
ok := scenegd.effect_route_load(&route, parent, "res://flash.tscn", epoch,
    0.3, binding, capacity=32)
for change in changes { scenegd.effect_route_change(&route, change) }
error := scenegd.effect_route_frame(&route, render_delta)
```

The journal decides when to deliver speculative or watched occurrences. The
default route policy, Journal, uses that timing. Confirmed waits for a confirmed
Begin or a Confirm change before showing an effect. The first accepted start
creates its scene lifetime. Update changes its value, Confirm marks it confirmed,
and Cancel retires it; Update and Confirm do not restart the age or scene.
Reused slots receive new generations and child bindings. IDs remain consumed
after expiry, cancellation, or capacity drops, preventing replay from starting
them again.

If the filter excludes an active event, the route cancels it. A later Update
cannot start a new speculative effect. Keep event-category filtering stable
and animate through value changes. When a confirmed-only effect has not begun,
its Confirm may start it, subject to its consumption ledger.

`effect_route_clear` removes live visuals without forgetting consumed IDs.
`effect_route_epoch` requires a strictly newer epoch, clears visuals and resets the
ledger/bindings. `effect_route_retire` advances the floor only when the caller knows
no new Begin at or below it can arrive, including delayed watched/confirmed events.
Do not use the render clock as that frontier. Full cue pools drop new effects;
check `route.route.cues.stats`. Ledger history/per-tick capacity is explicit.
Root properties and Rig lifetimes follow the [view ownership contract](view-pools.md).
Scene instances are created when effects enter the route. Setting a capacity
does not instantiate those scenes in advance.

For audio, the callback returns `(Audio_Cue, include)` and may borrow streams from
a presentation asset owner through `user`. Godot players retain their own stream
reference while assigned. Destroy the route before the parent or borrowed callback
owner. Each route owns its own bounded voices and ID ledger:

```odin
audio: scenegd.Audio_Route(Event)
ok := scenegd.audio_route_init(&audio, parent, epoch, sound_for_event,
    &sound_bank, .Confirmed, world_voices=8, screen_voices=2)
for change in changes { scenegd.audio_route_change(&audio, change) }
```

Update moves an active spatial voice; it does not change the clip or restart
playback. Confirmed-only routes play once upon confirmation. Cancel stops only a
voice still owned by that occurrence, so canceling a stolen old voice cannot stop
its replacement. Full voice pools steal in bounded round-robin order; the
ledger continues to record consumed IDs after their voices are gone.
`audio_route_epoch` clears voices under a newer epoch and `audio_route_retire` has the same safe-frontier requirement as visual routes.
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

Scrapyard uses this callback to derive pitch from occurrence IDs and reconstruct
damage-effect positions at the event's tick. Event-only routing remains available
when a sound depends only on its gameplay payload.
