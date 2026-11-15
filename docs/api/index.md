---
outline: [2, 2]
---

# API reference

Look up public types, functions, aliases, constants, and variables by name or
package. Each package page contains a declaration index, source signatures,
member notes, overloads, related declarations, and links to the implementation.

<ApiSearch />

## Browse packages

[Open the complete package index](generated/index.md). Packages follow the same
layers as the guides: the Odin and Godot bridge, Kit, Replay, Box3D, and libraries.

- [Godot helpers](generated/godot.md): engine calls, typed signals, strings, and Variants.
- [Kit replication](generated/kit/net.md) and [sessions](generated/kit/session.md).
- [Kit simulation](generated/kit/sim.md): ticks, inputs, and prediction.
- [Replay core](generated/replay.md), [networking](generated/replay/net.md), and [Godot integration](generated/replay/godot.md).
- [Box3D](generated/box3d.md) and [world authoring](generated/box3d/authoring.md).
- [Events](generated/events.md), [sequences](generated/flow.md), and [gameplay components](generated/play.md).

## Read a declaration

The signature preserves the source's parameter and result types, defaults,
generic constraints, field tags, and calling convention. Types show their full
declaration and any member comments. Overload groups show their available
signatures. The source link points to the declaration's file and line.

Conditions identify declarations inside `when` branches or files with build
tags. This reference includes those source variants; a particular build selects
the ones allowed by its platform and configuration. Private declarations, tests,
and internal packages are excluded.

The generated Godot engine-class wrappers follow
[Godot's class reference](https://docs.godotengine.org/en/stable/classes/index.html).
This reference covers the SDK's authored helper layer rather than duplicating
the engine manual.

## Use the guides alongside the reference

For setup, ownership, and frame-loop ordering, use the
[scripting](../scripting/index.md), [Kit](../kit/index.md),
[Replay](../replay/index.md), and [Box3D](../box3d/index.md) guides.
A declaration's visibility does not establish support for every platform or
multiplayer configuration; the corresponding support guide describes those limits.

The API pages are generated during the website build. To browse the complete
reference outside a local preview, open the
[online API reference](https://wlitwin.github.io/odin_godot/api/).
