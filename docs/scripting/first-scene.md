# Your first Odin scene

Create a Godot project with a colored square that moves across the window. Its
speed is an Odin field exposed in the Inspector. This tutorial uses a repository
checkout and the pinned Nix development shell.

You need Git, Nix with flakes enabled, and Godot 4.7.x. The shell targets Godot
4.7.1. You should know how to open and run a Godot project.

## 1. Enter the toolchain shell

```sh
git clone https://github.com/wlitwin/odin_godot.git
cd odin_godot
nix develop
```

If you already have a checkout, start there. The shell prints the compiler and
Godot paths. On a setup without `/Applications/Godot.app`, select your executable
when entering it:

```sh
GODOT=/absolute/path/to/godot nix develop
```

Keep the following commands in this shell, at the repository root.

## 2. Create the project files

Create a directory outside the checkout so your game stays separate from the SDK:

```sh
mkdir -p ../first-odin-scene/scripts
```

Create `../first-odin-scene/project.godot`:

```ini
config_version=5

[application]
config/name="First Odin Scene"
run/main_scene="res://main.tscn"

[display]
window/size/viewport_width=800
window/size/viewport_height=450

[rendering]
renderer/rendering_method="gl_compatibility"
```

Create `../first-odin-scene/odin_godot.gdextension`:

```ini
[configuration]
entry_symbol = "odin_godot_init"
compatibility_minimum = "4.6"

[libraries]
macos.debug = "res://bin/libodin_godot.dylib"
macos.release = "res://bin/libodin_godot.dylib"
linux.debug.x86_64 = "res://bin/libodin_godot.so"
linux.release.x86_64 = "res://bin/libodin_godot.so"
windows.debug.x86_64 = "res://bin/libodin_godot.dll"
windows.release.x86_64 = "res://bin/libodin_godot.dll"
```

The core registers the language and loads your compiled scripts. You do not list
the scripts library in this manifest. The [distribution guide](../distribution.md)
covers prebuilt addons and platform support; use macOS for the primary development path.

## 3. Write the script

Create `../first-odin-scene/scripts/mover.odin`:

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

`//gd:extends Node2D` selects the Godot base class. The `owner` field has the
matching engine handle type, `gd.Node2d`. The `mover_` prefix connects procedures
to `Mover`; `_ready` runs once and `_process` receives elapsed seconds each frame.

The field tag exposes **Speed** with a default of 120. Multiplying it by `delta`
makes motion 120 pixels per second rather than per rendered frame.

## 4. Attach it to a visible node

Create `../first-odin-scene/main.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/mover.odin" id="1"]

[node name="Main" type="Node2D"]

[node name="Mover" type="Node2D" parent="."]
position = Vector2(80, 225)
script = ExtResource("1")

[node name="Square" type="Polygon2D" parent="Mover"]
polygon = PackedVector2Array(-16, -16, 16, -16, 16, 16, -16, 16)
color = Color(0.9, 0.4, 0.2, 1)
```

The script moves the parent node; its `Polygon2D` child follows it. Attaching
`mover.odin` through the editor's Script slot produces the same relationship.

## 5. Build and run

```sh
bash build/build_scripts.sh ../first-odin-scene
"$GODOT" --editor --path ../first-odin-scene
```

The build must finish without compiler errors. It writes generated registration
under `scripts/` and the core and scripts libraries under `bin/`. Wait for the
editor's initial import to finish so it discovers the extension and registers
Odin. Press **F6** to run the scene. The game prints `Mover ready` and shows a
square moving right, wrapping to the left edge.

After that first editor import, you can also launch the game directly:

```sh
"$GODOT" --path ../first-odin-scene
```

Select **Mover** and change **Speed** to 240 in the Inspector. Save and run again:
the square takes about half as long to cross the window. This setting belongs to
the scene instance; the script tag supplies the default.

## If something fails

| Symptom | Check |
| --- | --- |
| Godot cannot load the extension or `.odin` script | Build, then open the editor and let its initial import finish; check the manifest's core path |
| The editor cannot find Odin after a save | Launch from the shell, or set `odin_godot/odin_bin` in [editor settings](../workflow.md#editor-settings-reference) |
| The script compiles but the square stays still | Check the script path and `mover_process` spelling; **Speed** must be greater than zero |
| The build cannot find the SDK | Invoke the checkout's build script, or set `ODIN_GODOT_ROOT` to that checkout |

## Next

- Use the [authoring reference](../authoring-guide.md) to add input, signals, and resources.
- Read [Development workflow](../workflow.md) to configure rebuilds and reloads.
- Follow [Kit's two-window tutorial](../kit/quickstart.md) when you need multiplayer.
