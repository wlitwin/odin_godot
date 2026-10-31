# Device controls and signal actions

Use `Input_Binding(Control)` to preserve button edges between Godot frames and
simulation ticks. It interns InputMap names once and maps buffered button values
to the game's Control type. Keep the binding outside World. A mapper can also
read presentation-owned aim/device data through its borrowed user pointer.
It must return a copied value without mutating the simulation.

```odin
bindings := [2]inputgd.Input_Action{{"ui_left", 0}, {"ui_right", 1}}
controls: inputgd.Input_Binding(Control)
ok := inputgd.input_binding_init(&controls, bindings[:], Control{},
    proc(_: rawptr, buttons: replay.Buttons) -> Control {
        return {move=i8(buttons.held & 2 != 0)-i8(buttons.held & 1 != 0)}
    })

// Once per engine frame; combine all applicable gates.
inputgd.input_binding_sample(&controls, {.Menu})
value := inputgd.input_binding_read(&controls)
// After a tick/control submission commits:
inputgd.input_binding_consume(&controls)
```

Up to 64 unique actions map to unique bits. Capture coalesces repeated presses of
the same button within one simulation tick, while preserving simultaneous press
and release. Reading does not consume; failed simulation steps keep their edges.
Held state remains after consuming edges. For a Session, consume when
`session.control_consumed` reports that a simulation step used the control.
A successful frame call alone does not establish that. This helper does not
change the runner's scheduling.

`Paused`, `Unfocused`, `Menu` and `Inspecting` gates return the supplied neutral
Control and discard buffered edges. A button held across a gate transition must
be released before reuse. Supply gates before sampling each frame; application
code supplies focus/menu eligibility explicitly; the library does not infer it
from an arbitrary Control node. Analog axes can be sampled in the mapper; applications
with analog hold/rearm requirements must apply their own dead-zone policy.
The engine-free `replay.Control_Capture` exposes the same bit/edge/gate behavior.

# Signal actions

`Signal_Action(Action)` connects a no-argument signal such as Button.pressed to a
typed payload constructor and the existing `Action_Intent`. Keep it at a stable
address. Emitter and user must outlive it; destroy/disconnect before freeing them.

```odin
buy: inputgd.Signal_Action(Action)
ok := inputgd.signal_action_init(&buy, button, "pressed",
    proc(user: rawptr) -> (Action, bool) {
        ui := cast(^Shop_UI)user
        return Action{item=ui.selected_item}, ui.selection_valid
    }, &shop_ui)

inputgd.signal_action_gate(&buy, gates) // cancel only unsubmitted input by default
sequence, error := inputgd.session_bound_action(&session, &buy)
for change in changes {
    inputgd.bound_action_observe(&buy, &session, change)
}
```

The payload is copied on the click. Another click while a payload awaits
submission returns Capacity and preserves the first click. There is no hidden
unbounded click queue. Call the submit helper every frame: backpressure/fencing
retains the payload; accepted submission transfers delivery to the action ledger.
`room_bound_action` provides the Room equivalent. Confirmed epoch-scoped results,
including recovered tickets, remain in `buy.intent`; ordinary prediction cannot
settle an action. Recovery reports are processed even while UI submission is gated.

Gates reject new captures. Default Cancel drops only unsubmitted work; Keep holds
it until the gate clears. Neither can cancel work already accepted by the ledger.
Update gate state before signals can arrive (including inside menu/focus handlers),
then sample/submit in your frame loop. The library cannot infer when your UI became
ineligible. Programmatic `signal_action_capture` uses the same typed latch.
Signals with arguments should use a normal typed script handler to construct the
action, or a separate adapter; this initial binding accepts no-argument signals.

Destroying a binding disconnects its callable and discards local tracking. It does
not cancel an action already in a running Session. Consume results/recovery in
order, and use explicit session lifecycle boundaries before reusing an owner.
See [intent contracts](intents.md) for counters and result semantics, and
`tests/replay_nodes/scripts/input.odin` for the compile-checked engine example.
