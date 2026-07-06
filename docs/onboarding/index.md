# The onboarding series

You have shipped Godot games in GDScript or C#. This series is the bridge from
there to here: writing your gameplay in compiled Odin, and structuring it so
multiplayer is a property of your code instead of a feature bolted onto it.

It is deliberately not a reference (that's the [Authoring Guide](../authoring-guide.md))
and not a recipe (that's [Build a game in a day](../kit/build-a-game-in-a-day.md)).
It is the *why* — each post takes one mental-model shift, shows what it buys
you, and leaves you with something running. Read it in order; each post leans
on the one before.

1. **[What if your scripts were compiled?](01-what-if-your-scripts-were-compiled.md)**
   — what stays exactly the same (almost everything), what changes (your `.gd`
   files), and why the trade is worth examining at all. Ends with a moving node.
2. **[Thinking in structs](02-thinking-in-structs.md)** — the reflex map. Every
   GDScript habit (`@export`, `@onready`, signals, inheritance, autoloads) has a
   direct counterpart; this post translates them one by one, including the one
   trap everyone hits (`self` vs `self.owner`).
3. **[State, not messages](03-state-not-messages.md)** — the multiplayer
   mental-model shift. Stop thinking "which peer do I send this to"; start
   thinking "this field replicates." A hosted, joinable game in one `ready()`.
4. **[Verbs, not RPCs](04-verbs-not-rpcs.md)** — player actions as predicted
   commands: single-player-looking procs with zero role branches, where races,
   rejection, and cheating are handled by the pipeline instead of by you.
5. **[The two timelines](05-the-two-timelines.md)** — the deepest shift: your
   screen and a remote screen do not show the same moment. Why effects fire
   "too early" or "too late", and the one-boolean discipline that fixes every
   case.
6. **[The shape of a shippable game](06-the-shape-of-a-shippable-game.md)** —
   what you get for free once the model holds: reconnects, drop-in joins,
   saves, host migration, Steam — and the testing habit that keeps it all true.

**Who this is for:** Godot developers comfortable with the editor, scenes, and
nodes. No Odin experience assumed — the language is small enough to learn from
the code in front of you. No netcode experience assumed either; in fact the
less RPC muscle memory you have, the easier post 3 lands.
