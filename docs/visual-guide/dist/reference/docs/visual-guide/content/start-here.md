# Build a game with Odin and Godot

odin_godot adds compiled Odin scripts to Godot. You author scenes in the Godot
editor, attach `.odin` files to nodes, and use typed bindings to call the engine.
The same SDK includes two independent multiplayer frameworks: Kit and Replay.

Start with a running scene. Choose a networking model once the game has state and
an interaction worth synchronizing.

## Choose a starting point

| What you want to build | Start here | What you will have |
| --- | --- | --- |
| Your first Odin script | [Install the SDK](install.md), then [write a script](first-script.md) | A compiled script attached to a Godot node, with an Inspector property and a frame callback |
| Odin gameplay in an existing Godot project | [Add the SDK to your project](existing-project.md) | The addon, scripts library, and editor settings connected to your project |
| A cooperative game with object-based state | [Build a Kit game](kit-game.md) | Two players, owner-streamed movement, and authority-owned shared state |
| A game whose complete simulation can be restored | [Build a Replay game](replay-game.md) | A typed world with recorded input, correction, and detached Godot views |
| A desktop or browser release | [Build and export](shipping.md) | A plan for compiling, packaging, and checking the target build |

## How a script runs

An Odin script has three pieces: a struct holding script state, free procedures
implementing behavior, and an engine node stored in the struct's `owner` field.
The build generates registration and compiles your scripts into a library. The
core GDExtension registers the Odin script language with Godot and loads that
library.

Godot still owns the scene tree, rendering, input devices, animation, and audio.
You decide which gameplay values live in scripts and, when using Replay, which
values belong in the restorable world.

## Learn the scripting surface

The [script model](../../onboarding/02-thinking-in-structs.md) maps Godot concepts
to Odin structs and procedures. The [authoring reference](../../authoring-guide.md)
covers lifecycle callbacks, Inspector properties, signals, methods, resources,
and cross-script calls. Use the [editor workflow](../../workflow.md) for building,
reload-on-save, completion, and debugging.

A single-player game can use these facilities directly. A session or timeline
is needed only when you choose a framework that owns that part of the game.

## Choose a multiplayer model

Kit declares how fields on registered entities are synchronized. Its commands
handle shared interactions. Its simulation lane advances fast state at fixed
ticks, predicts local input, and applies authority corrections.

Replay keeps gameplay in a typed World and steps it from recorded inputs. Each
retained frame captures the World at one tick. The runner owns this history and
applies corrections; Godot nodes display the result without owning simulation
state.
Replay also has cooperative owner streams and a deterministic peer-input runner.
It remains experimental; use its documented support envelope when choosing a
shipping configuration.

Read [choosing a multiplayer model](multiplayer.md) for the tradeoffs. The visual
field guide follows a contested pickup through both designs and lets you inspect
a correction one tick at a time.

## Study a complete game

[Play Scrapyard in your browser](https://itchyitches.itch.io/scrapyard), then use
the [Replay Scrapyard contributor guide](../../../examples/replay_scrapyard/contributor-guide.md)
to follow a feature through authored content, simulation, input, and presentation.
The [examples directory](examples.md) gives smaller starting points for each model.
