---
layout: home
hero:
  name: Odin + Godot
  text: From your first script to a multiplayer game.
  tagline: Build scenes in Godot. Write gameplay in Odin. Learn the bridge, then choose the frameworks your game needs.
  actions:
    - theme: brand
      text: Write your first script
      link: /scripting/first-scene
    - theme: alt
      text: Explore the examples
      link: /examples/
features:
  - title: Scripting
    details: Attach Odin scripts to Godot nodes. Learn properties, signals, resources, the build loop, and export.
    link: /scripting/
  - title: Kit
    details: Synchronize script entities with replicated fields and commands. Add fixed ticks and prediction where needed.
    link: /kit/
  - title: Replay
    details: Keep gameplay in a restorable World. Learn input history, correction, and Godot presentation.
    link: /replay/
  - title: Box3D
    details: Run 3D physics offline or with either framework. Learn stepping, collision authoring, characters, and joints.
    link: /box3d/
  - title: Libraries
    details: Use typed events, timed sequences, tween steps, and gameplay helpers without adopting every framework.
    link: /libraries/
  - title: Learn by building
    details: Follow working examples from a moving node to co-op, prediction, replayable interactions, and 3D physics.
    link: /learn/
---

## Start with a scene

Looking for a specific topic? [Browse the full site map](site-map.md), or
[look up a type or function](api/index.md).

odin_godot registers Odin as a Godot scripting language. Attach an `.odin` file
to a node and compile it; Godot calls its lifecycle procedures and displays its
exported properties. You can use the bridge for a single-player game.

The [first scene tutorial](scripting/first-scene.md) creates a visible moving
square from an empty project. Already have a project? Use the
[installation guide](getting-started.md) or [drop-in addon instructions](distribution.md).

## Add a framework when you need one

Kit and Replay are alternative ways to organize multiplayer state. Kit starts
from script entities and field declarations. Replay starts from a complete
restorable World. Box3D runs independently or through either framework's physics
adapter. The [framework guide](multiplayer/index.md) explains the choice.

| I want to… | Read |
| --- | --- |
| Understand how multiplayer games work | [Multiplayer concepts](multiplayer/concepts/index.md) |
| Plan movement, pickups, combat, or reconnects | [Feature walkthroughs](multiplayer/recipes/index.md) |
| Learn how Godot calls an Odin script | [Scripting overview](scripting/index.md) |
| Move players in two windows | [Kit multiplayer tutorial](kit/quickstart.md) |
| Add authoritative movement and prediction | [Kit simulation tutorial](kit/quickstart-sim.md) |
| Restore and replay a gameplay interaction | [Replay tutorial](replay/quickstart.md) |
| Add physics without networking | [Box3D offline tutorial](box3d/quickstart.md) |
| Understand bodies, collisions, and solver history | [Box3D concepts](box3d/concepts/index.md) |
| Find a signal or sequencing helper | [Libraries](libraries/index.md) |
| Build a desktop or browser release | [Exporting](exporting.md) |

The tutorials assume you know Godot scenes and can program. Odin-specific
conventions are introduced where you need them. Use guides for tasks and
references to look up APIs and limits.
