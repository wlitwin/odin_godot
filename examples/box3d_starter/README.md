# Box3D: a small offline game

A crate falls onto a floor. Press **Space** to make it jump and **R** to restore
its authored position. This starter uses editor-authored collision and ordinary
MeshInstance3D children. It needs neither Kit nor Replay.

## Use the installed SDK

1. Install the SDK's two addon directories, `odin_godot` and `box3d_authoring`,
   in a new project. Copy the **contents** of `addons/odin_godot/template/box3d`
   into the project root. Keep the installed addons in place.
2. Build and select the native Box3D backend once using the SDK's
   [build guide](https://wlitwin.github.io/odin_godot/box3d/building.html).
   Build the project with the ordinary `build/build_scripts.sh` or Windows
   PowerShell helper in `addons/odin_godot`.
3. Open the project and press **F6** with `main.tscn` open, or **F5**. Subsequent
   changes use **Project → Tools → Build Odin Scripts** or rebuild on save.
   The initial build remembers the compiler and backend for Project Manager
   launches.

For collision previews, select a Box3D object and choose **Install tools and
build** in its Inspector. Physics works without the optional editor tool module.

From a source checkout, this convenience command installs the SDK into the
example on its first run, builds/selects the backend, builds the game and opens
Godot:

```sh
nix develop --command bash examples/box3d_starter/play.sh --editor
```

Use `BOX3D_NATIVE_LIBRARY` to select an existing backend. Later runs reuse the
remembered selection. The helper leaves an installed SDK alone; close Godot and
replace its addon directories explicitly when upgrading the framework.

## Change the game in the editor

Open `content/world.tscn`. Move **Crate** higher, rotate it, or edit its shape's
friction, restitution and density. Its **Visual** child supplies appearance;
the shape Resource supplies collision. Keep their dimensions consistent.

Use **Duplicate Box3D selection** to add more crates with new saved IDs, then
move them apart. All authored bodies get physics and visual bindings without
adding code. The Space action targets the original **Crate** node.

`scripts/game.odin` is the whole game loop. `physics.open(World)` captures the
initial content, `physics.step_fixed` advances and presents it, and
`physics.reset` rebuilds from that original content. Reset never rebakes the
positions reached during play. Mesh-child offsets and scales stay untouched.
Moving the containing World moves the presentation frame.

The scene helper owns physics until `finalize`, including temporary tree exit
and re-entry. Do not manually destroy its body handles or reparent bound bodies
into a different body hierarchy or World. Use the lower-level API when adding
runtime bodies or implementing a different ownership model.

The project runs physics at 60 Hz, matching the default Box3D profile. If you
change the SDK timing profile, set the Godot physics rate to the same value;
the helper reports mismatches. Stop and restart Play after changing owned-state
layouts; no empty reload hook is needed.

## Export

Use **Project → Export** with the supplied **macOS arm64** or **Linux x86_64**
preset. The normal Odin exporter rebuilds the game and deploys its selected
backend. Select a backend for that target first. This starter does not add a
custom export path or include a compiler in the exported game.

The macOS preset uses Godot's universal launcher with arm64 SDK libraries. It is
not an Intel build. See the SDK support guide for other targets. The separate
`examples/box3d_offline` tower game demonstrates procedural spawning and a
browser export; the Kit/Replay authored examples demonstrate multiplayer.
