# Godot Tween steps

Use `godot:flowgd` to include a Godot Tween in a `flow` sequence. Godot processes
the animation; the sequence starts it and waits until it finishes or becomes invalid.

This guide assumes [Timed sequences](flow.md) and the
[script lifecycle](../scripting/index.md).

## Add a Tween step

```odin
import flow "godot:flow"
import flowgd "godot:flowgd"
import gd "godot:godot"
```

The entry point is `flowgd.tween(node, configure) -> flow.Action`. `configure`
is a `proc(t: gd.Tween, ctx: rawptr)` callback that adds the desired tweeners.
The callback receives the context supplied to `flow.tick`; obtain your script
state from that context rather than retaining a closure.

Keep the returned Action in the tree you tick each frame. The node must remain
valid when the step starts. Use the
[engine Tween helpers](../authoring-guide.md) to configure property changes,
intervals, and callbacks.

## Reset and cancellation

Reset kills a running Tween and allows the step to start again. Destroying the
tree kills a running Tween and frees the step's allocation. A node leaving the
tree can invalidate its Tween; the flow step then completes.

To wait for a signal, connect a script method that sets a boolean and use
`flow.wait_flag(&self.flag)`. There is no separate `flowgd.wait_signal` API.

See [tween.odin](https://github.com/wlitwin/odin_godot/blob/main/flowgd/tween.odin)
for the callback and cleanup signatures. Rebuild the tree after script reload
because its callbacks and pointers belong to a script generation.
