# Your first Odin scene

Create a colored square that moves across the window, with its speed exposed in
the Inspector. Use Godot's scene editor and the installed addon's build commands.
You need Godot 4.7.x, an Odin compiler, and basic familiarity with creating nodes.

## 1. Install and set up scripts

Create an ordinary Godot project with the Compatibility renderer. Install
`addons/odin_godot/` using the [distribution guide](../distribution.md#install-into-a-godot-project),
then reopen the project and let its initial import finish. The addon includes
the extension manifest and core library.

Choose **Project → Tools → Set Up Odin Scripts**, then **Build Odin Scripts**.
The first command creates `res://scripts/hello.odin`; the second compiles it.
If Odin cannot be found, set `odin_godot/odin_bin` to the compiler's absolute path
or launch the editor from a toolchain shell. See [workflow settings](../workflow.md#editor-settings-reference).

If you are starting from a repository checkout, create your Godot project in
`../first-odin-scene`, then build and copy the addon:

```sh
cd odin_godot
nix build
mkdir -p ../first-odin-scene/addons
cp -R result/addons/odin_godot ../first-odin-scene/addons/
chmod -R u+w ../first-odin-scene/addons/odin_godot
nix develop
"$GODOT" --editor --path ../first-odin-scene
```

The pinned development shell provides the compiler and editor tools. On a setup
without `/Applications/Godot.app`, enter it with `GODOT=/path/to/godot nix develop`.

## 2. Make a visible scene

1. Create a **Node2D** scene root named **Main** and save it as `main.tscn`.
2. Add a **Node2D** child named **Mover**, positioned at `(80, 225)`.
3. Add a **Polygon2D** child under Mover. Draw a small square around its origin
   and choose a visible color.
4. Select Mover, choose **Attach Script**, select **Odin**, and save the new
   script as `res://scripts/mover.odin`.

The starter's `hello.odin` can stay in the package or be deleted. It does not
need to be attached to this scene.

## 3. Write the movement

Replace `mover.odin` with:

```odin
//gd:extends Node2D
package scripts

import gd "godot:godot"

Mover :: struct {
    owner: gd.Node2d,
    speed: f32 `gd:"export,default=120"`,
}

mover_ready :: proc(self: ^Mover) {
    gd.print("Mover ready")
}

mover_process :: proc(self: ^Mover, delta: f64) {
    position := gd.node2d_get_position(self.owner)
    position.x += self.speed * f32(delta)
    if position.x > 800 {
        position.x = 0
    }
    gd.node2d_set_position(self.owner, position)
}
```

`self` addresses the script state; `self.owner` is its Godot node. The `mover_`
prefix associates the procedures with `Mover`. `_ready` runs when the node is
ready, and `_process` receives elapsed seconds each frame.

Save the script and wait for the build to finish. Registration and boot code are
generated for you. The Inspector now shows **Speed**, defaulting to 120.

## 4. Run and tune

Press **F6**. The game prints `Mover ready` and the square moves right, wrapping
at x = 800. Stop the game, select Mover, change **Speed** to 240, save the scene,
and run again. The square now moves twice as fast.

Inspector values belong to the scene instance; the script tag supplies its
default. The child Polygon2D follows the moving parent without extra code.

For a terminal build from the project directory:

```sh
SKIP_CORE=1 bash addons/odin_godot/build/build_scripts.sh .
"$GODOT" --editor --path .
```

The builder locates its bundled SDK automatically. The prebuilt core stays in
the addon and the game's compiled scripts go in `bin/`.

## If something fails

| Symptom | Check |
| --- | --- |
| Odin is absent from Attach Script or the Tools menu | Confirm the addon is installed, reopen the project, and let its import finish |
| The editor cannot find Odin | Set `odin_godot/odin_bin`, or launch from the toolchain shell |
| Build failed | Read the compiler error in Output; the editor keeps the previous library and blocks Play after a failed build |
| The square stays still | Check the attached script and `mover_process` spelling; Speed must be greater than zero |

## Next

- Use the [authoring reference](../authoring-guide.md) to add input, signals, and resources.
- Read [Development workflow](../workflow.md) for builds, debugging, and external editors.
- Follow [Kit's two-window tutorial](../kit/quickstart.md) when you need multiplayer.
