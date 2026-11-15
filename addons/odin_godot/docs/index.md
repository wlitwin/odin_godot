# odin_godot documentation

Start with the addon [README](../README.md) and [Getting started](getting-started.md)
to install Odin and build the included starter. The online
[documentation](https://wlitwin.github.io/odin_godot/) has the same guides with
navigation and search.

## Choose a layer

| Layer | Read | Prerequisite |
| --- | --- | --- |
| Odin and Godot | [Scripting](scripting/index.md) and [authoring reference](authoring-guide.md) | Godot scenes and basic programming |
| Kit multiplayer | [Kit overview](kit/index.md), then [two-player tutorial](kit/quickstart.md) | Working Odin scripts |
| Replay multiplayer | [Replay overview](replay/index.md) and [addon starter](replay.md) | Working Odin scripts; Kit is optional |
| Box3D | [Physics overview](box3d/index.md), [authoring](box3d/authoring.md), and [support](box3d/support.md) | Working Odin scripts; multiplayer is optional |
| Libraries | [Library map](libraries/index.md) | Depends on the selected package |

Some tutorials use example projects from a repository checkout. They say so at
the start; use the addon's packaged templates for a project without a checkout.
Box3D requires its target backend and matching native setup.

## Development and export

- [Workflow](workflow.md): build, reload, editor settings, and completion.
- [Debugging](debugging.md): logging, native breakpoints, and crash reports.
- [Script modules](modules.md): independently built gameplay libraries.
- [Exporting](exporting.md): desktop and browser packaging.
- [Distribution](distribution.md): compiler and platform compatibility.
- [Core and scripts boundary](contributing/native-boundary.md): ABI and ownership.
