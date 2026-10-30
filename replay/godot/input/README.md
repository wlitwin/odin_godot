# Replay input adapters

Import `inputgd "godot:replay/godot/input"` for Godot InputMap sampling and copied
UI action capture. Keep device state, signal connections and pending input
outside the replayable World.

`Input_Binding(Control)` interns action names once. Initialize it with a typed
mapping callback and neutral control value, then sample once per engine frame, read the
copied controls and consume edges after an actual simulation step uses them.
For a Session, use `session.control_consumed` as that receipt. Destroy the
binding when its owner exits.

`Signal_Action(Action)` captures one copied payload when a no-argument Godot
signal fires. Submit it with `session_bound_action` or `room_bound_action`, then
feed presentation changes to `bound_action_observe`. Its `Action_Intent` retains
submission/result bookkeeping through retry and recovery. Apply explicit input
gates when menus, pause or focus block gameplay.

Live bindings need stable addresses. Signal emitters and borrowed callback users
must outlive their binding; destroy the binding before freeing the emitter.
`bind_key` and `bind_mouse` add InputMap events and release their temporary
constructor references after InputMap retains them.

The Session/Room owners remain in `replaygd "godot:replay/godot"`. See
[input and signals](controls.md), [action intents](intents.md) and the
[checked recipes](../../../examples/replay_recipes/README.md).
