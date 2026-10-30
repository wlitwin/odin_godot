# Install the SDK

There are two useful starting points: a checkout with the repository's pinned
development tools, or the packaged addon inside your own Godot project. Use a
checkout when learning from the examples or changing the SDK. Use the addon when
you want the extension and build helpers alongside a game's own files.

## Use the repository and its toolchain

Install [Nix with flakes enabled](https://nixos.org/), clone the repository, and
enter the development shell:

```sh
git clone https://github.com/wlitwin/odin_godot.git
cd odin_godot
nix develop
```

The shell supplies Odin, build tools, and the `godot` collection used by imports
such as `"godot:godot"`. It also sets `GODOT` to the engine executable. The
repository currently targets Godot 4.7.x; use the version and toolchain recorded
by the checkout you are building.

If the engine is installed elsewhere, enter the shell with its path:

```sh
GODOT=/absolute/path/to/godot nix develop
```

Build and run a small existing scene before creating a project:

```sh
bash build/build_scripts.sh tests/showcase
"$GODOT" --path tests/showcase
```

This checks that the compiler, extension, and engine agree. If it fails, resolve
the build or loader error before adding your own scripts.

## Use the packaged addon

The distributable contains `addons/odin_godot`, including the core extension,
bindings, build helpers, and templates. Get it from the repository's release
distribution or build it from a checkout with `nix build .#release`.

Copy the addon into your game's `res://addons/` directory. You still need an Odin
compiler on `PATH`: the addon includes a prebuilt core, while your gameplay scripts
are compiled for your project.

Follow [adding Odin to an existing project](existing-project.md) for the scripts
layout and build command. The [distribution reference](../../distribution.md)
describes the package layout, native ABI compatibility, and platform validation.

## Configure the editor

When the editor is launched outside the development shell, set these project
settings to absolute paths:

| Setting | Purpose |
| --- | --- |
| `odin_godot/root` | SDK checkout or installed addon used as the `godot` collection |
| `odin_godot/odin_bin` | Odin compiler used by editor builds |
| `odin_godot/ols_bin` | Language server used for completion |

The shell's `ODIN_GODOT_ROOT` serves the corresponding collection role for build
helpers. Keep the editor and command-line build pointed at the same SDK.

## Continue

Write [your first script](first-script.md), or read the full
[project wiring guide](../../getting-started.md) for manifests, boot registration,
and the two-library native layout.
