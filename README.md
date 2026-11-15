# odin_godot

Write Godot scripts in [Odin](https://odin-lang.org/). Attach `.odin` files to
nodes, expose properties in the Inspector, connect signals, and compile gameplay
to native code or WebAssembly. Godot owns the editor, scenes, rendering, and audio.

**[Documentation](https://wlitwin.github.io/odin_godot/)** ·
[Getting started](docs/getting-started.md) ·
[Install the addon](docs/distribution.md) ·
[Examples](docs/examples/index.md)

## Choose what you need

The scripting bridge works on its own. Kit and Replay are independent multiplayer
frameworks. Box3D supports offline physics and separate integrations with both.

| Layer | What it provides | Start here |
| --- | --- | --- |
| Odin and Godot | Compiled node scripts, typed engine calls, Inspector properties, signals, resources, editor tools, and reload on save | [Scripting](docs/scripting/index.md) |
| Kit | Multiplayer built around script entities: replicated fields, commands, sessions, and optional server-authoritative prediction | [Kit](docs/kit/index.md) |
| Replay | Multiplayer built around a restorable World: frame history, input replay, correction, and separate Godot presentation | [Replay](docs/replay/index.md) |
| Box3D | Explicitly stepped 3D physics, authored collision, characters, joints, and complete physics checkpoints | [Box3D](docs/box3d/index.md) |
| Libraries | Typed events, timed sequences, Godot tween steps, and gameplay helpers | [Libraries](docs/libraries/index.md) |

Start with scripting, then use [Choosing Kit or Replay](docs/multiplayer/index.md)
when you have an interaction to synchronize. Replay and Box3D have configuration
and compatibility limits; read their support pages before choosing a target.

## Run a game

Install [Nix with flakes enabled](https://nixos.org/download/) and Godot 4.7.x.
The development shell pins the compiler and build tools and expects Godot 4.7.1.
On macOS it uses `/Applications/Godot.app/Contents/MacOS/Godot`; set `GODOT` to
your executable on another setup.

```sh
git clone https://github.com/wlitwin/odin_godot.git
cd odin_godot
nix develop
bash build/build_scripts.sh examples/survivors
"$GODOT" --editor --path examples/survivors
```

Wait for the editor import and press **F6**. Arrow keys move; weapons fire automatically. To build your own project, follow
[Your first Odin scene](docs/scripting/first-scene.md).

```odin
//gd:extends Node2D
package scripts

import gd "godot:godot"

Mover :: struct {
    owner: gd.Node2d,
    speed: f32 `gd:"export,default=120"`,
}

mover_process :: proc(self: ^Mover, delta: f64) {
    position := gd.node2d_get_position(self.owner)
    position.x += self.speed * f32(delta)
    gd.node2d_set_position(self.owner, position)
}
```

`self` addresses script state; `self.owner` is the engine node. Generated
registration connects this script to Godot's lifecycle callbacks.

## Platform support

macOS is the bridge's main development platform. Windows has prebuilt cores and
a PowerShell script builder with limited runtime coverage. Linux cores are
build-verified. Browser export uses WebAssembly and requires the serving headers
described in [Exporting](docs/exporting.md).

Framework and physics support depend on the runtime, transport, and target. See
[Replay support](docs/replay/support.md), [Box3D support](docs/box3d/support.md),
and [Distribution](docs/distribution.md).

## Contribute

See [Contributing](docs/contributing/index.md) for source layout, focused checks,
and documentation work. To preview the documentation:

```sh
cd docs
npm ci
npm run dev
```

Run `npm run check` and `npm run build` before submitting documentation changes.
Generated HTML and source snapshots are excluded from Git.

The [API reference](docs/api/index.md) is generated from public declarations.
Documentation builds need Odin or Nix; `nix develop .#docs` provides the pinned
parser toolchain without the game/export dependencies.

## License

[Apache-2.0](LICENSE). The binding generator and C ABI runtime include code from
[`dresswithpockets/odin-godot`](https://github.com/dresswithpockets/odin-godot).
See [NOTICE](NOTICE) and [attribution](bindgen/ATTRIBUTION.md).
