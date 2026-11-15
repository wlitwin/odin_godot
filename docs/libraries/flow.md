# Timed sequences with flow

Build a sequence as data and tick it from your frame loop. `flow` supplies waits,
callbacks, parallel work, and resettable state without Godot or a suspended stack.

## Run a complete sequence

Enter the checkout's Nix shell. From the repository root:

```sh
mkdir ../first-odin-flow
```

Create `../first-odin-flow/main.odin`:

```odin
package main

import "core:fmt"
import flow "godot:flow"

started :: proc(ctx: rawptr) {
    fmt.println("started")
}

finished :: proc(ctx: rawptr) {
    fmt.println("finished")
}

main :: proc() {
    action := flow.sequence(
        flow.call(started),
        flow.wait(0.5),
        flow.call(finished),
    )
    defer flow.destroy(&action)

    for flow.tick(&action, nil, 0.1) == .Running {}
}
```

Run it:

```sh
odin run ../first-odin-flow -collection:godot="$PWD"
```

Expected output:

```text
started
finished
```

This loop advances simulated elapsed time in 0.1-second increments; it does not
sleep. In a Godot script, call `flow.tick(&self.action, self, delta)` once from
`_process` or `_physics_process`. Callbacks receive that same context pointer.

## Choose a step

| Builder | Behavior |
| --- | --- |
| `wait(seconds)` | Complete after the supplied tick deltas accumulate |
| `wait_frames(n)` | Complete after a number of ticks |
| `wait_flag(&flag)` | Wait for a caller-owned boolean |
| `wait_until(predicate)` | Poll a context-based predicate |
| `call(callback)` | Invoke a callback once |
| `sequence(steps...)` | Run children in order |
| `parallel(steps...)` | Complete after every child finishes |
| `race(steps...)` | Complete when any child finishes |
| `repeat(times, body)` | Repeat a body; see the source for the infinite-repeat sentinel |
| `custom(data, on_tick, on_reset, on_free)` | Adapt external work; optional hooks manage its lifecycle |

Check the exact signatures in
[sequence.odin](https://github.com/wlitwin/odin_godot/blob/main/flow/sequence.odin).
`tick` returns `Running` or `Done`. Completed nodes retain their completed state,
so ticking again does not repeat a finished callback. `reset` restarts a tree.

## Own and release the tree

Composite builders allocate child storage using `context.allocator`.
`flow.destroy` releases it; use the same allocator used to build it. An arena
can also own the complete tree when its lifetime covers all callbacks and state.

Pointers supplied to `wait_flag` must stay valid. Procedure pointers and script
addresses can become stale after reload. Destroy the old tree and rebuild it in
`<class>_reload`, then destroy the live tree in `_exit_tree`. Custom steps must
release external work through their free hook.

Keep flow callbacks with scene mutations outside replayed simulation. A flow
tree can contain process-local pointers and is unsuitable as a Replay World value.

## Next

Use [Tween steps](flowgd.md) for engine animation, or [Events](../events.md) when
another script should set a flag that the sequence waits on.
