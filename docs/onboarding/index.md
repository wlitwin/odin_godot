# The onboarding series

This series shows how to write Godot gameplay in compiled Odin and organize
shared state for multiplayer. It assumes you know scenes, nodes, callbacks, and
ordinary game development; it introduces the Odin and Kit conventions as they
appear.

Read the posts in order: each introduces a mechanism used by the next. Keep
the [Authoring Guide](../authoring-guide.md) open for API details, and use
[Build a game in a day](../kit/build-a-game-in-a-day.md) for a step-by-step project.

1. **[Writing compiled Godot scripts](01-what-if-your-scripts-were-compiled.md)**
   covers the scene workflow, the compile step, and the script layout. It ends
   with a moving node.
2. **[Thinking in structs](02-thinking-in-structs.md)** maps the script conventions. Each
   GDScript feature (`@export`, `@onready`, signals, inheritance, autoloads) maps
   to an Odin convention or an explicit alternative. It also distinguishes
   the script struct (`self`) from the engine node (`self.owner`).
3. **[Field replication](03-state-not-messages.md)** introduces the multiplayer
   model: declare which fields replicate and which peer writes them. It builds
   a hosted session from declared scenes, handlers, and a `ready()` setup call.
4. **[Predicted commands](04-verbs-not-rpcs.md)** treats player actions as predicted
   commands. The generated pipeline handles submission and rejection; the
   command supplies the game-specific validation and target mutation.
5. **[The two timelines](05-the-two-timelines.md)** explains why local and remote
   screens show different moments, and how to schedule an effect beside its
   visible cause.
6. **[Identity, recovery, and transport testing](06-the-shape-of-a-shippable-game.md)** covers
   persistent identity, drop-in joins, saves, host migration, and Steam,
   including the setup and integration tests those features need.
7. **[Server-authoritative simulation](07-the-competitive-turn.md)** moves motion authority
   to the server. It introduces local input prediction, correction, and
   presentation for contested objects, using three versions of a soccer game.

Posts 1–6 cover cooperative replication; post 7 adds server-authoritative
simulation. Both use field declarations to select the state policy, so a game
can combine a cooperative lobby with server-authoritative hitboxes. The
references are
[kit/sim](../kit/sim.md) (the full lane) and [timelines](../kit/timelines.md)
(the per-field choosing guide).

**Prerequisites:** familiarity with the Godot editor, scenes, and nodes. The
examples introduce the Odin syntax and networking concepts they use.
