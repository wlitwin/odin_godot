# Write your first script

This example attaches a compiled Odin script to a `Node2D` and moves it every
frame. Start with the [SDK installed](install.md) and a project whose extension
and build helpers are wired as described in the [project setup](existing-project.md).

## Define the script state

Create `scripts/mover.odin`. Use the same package name as the project's other
scripts; the example below uses `my_game_scripts`.

```odin
//gd:extends Node2D
//gd:class Mover
package my_game_scripts

import gd "godot:godot"

Mover :: struct {
    owner: gd.Node2d,
    speed: f32 `gd:"export,default=120"`,
}

mover_ready :: proc(self: ^Mover) {
    gd.print("Mover ready!")
}

mover_process :: proc(self: ^Mover, delta: f64) {
    position := gd.node2d_get_position(self.owner)
    position.x += self.speed * f32(delta)
    gd.node2d_set_position(self.owner, position)
}
```

`owner` is the engine node. `self` points to the Odin struct. Pass `self.owner`
when an engine function asks for a node; pass `self` to your own procedures that
operate on the script state.

The `gd:"export"` tag makes Speed editable in the Inspector. The `mover_` prefix
associates the procedures with `Mover`; Godot sees the usual `_ready` and `_process`
callbacks through generated registration.

## Build the project

From an SDK development shell, pass the project directory to the build helper:

```sh
bash build/build_scripts.sh /absolute/path/to/your_game
```

For an installed addon, use its helper and prebuilt core as shown in
[existing project setup](existing-project.md#compile-the-scripts).

The build runs `scriptgen` and compiles authored and generated source together.
Generated `*.gen.odin` files are build outputs; edit the authored script instead.

## Attach the script and run

Open the project, add a `Node2D`, and attach `res://scripts/mover.odin` in its
Script slot. Speed should appear in the Inspector with a default of 120.
Run the scene: the Output panel prints the ready message and the node moves right.

Change Speed in the Inspector, then change the procedure and rebuild. This
separates authored scene values from compiled behavior and gives you a small
scene for checking the edit/build/run loop.

## Add the next piece

Use the [authoring reference](../../authoring-guide.md) for typed signals,
Godot-callable methods, Resource fields, and on-ready node lookup. The
[script model](../../onboarding/02-thinking-in-structs.md) explains shared data,
cross-script access, and composition. For input, movement, combat, or networking,
choose a [runnable example](examples.md) close to your game.
