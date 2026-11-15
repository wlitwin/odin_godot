# Multiplayer concepts

Learn how a multiplayer game decides what happened, responds before a reply,
and recovers when machines disagree or disconnect. These articles assume you
know Godot scenes and can program. They introduce the networking concepts before
connecting them to Kit and Replay.

The frameworks organize state differently, so a shared concept does not imply
a shared API. Use [Choosing Kit or Replay](../index.md) when selecting a model,
then follow that framework's runnable tutorial.

## Build the foundation

Read these in order for a first networked game. Each page follows a concrete
interaction so the terms have a gameplay consequence.

| Page | What you will understand |
| --- | --- |
| [Authority and ownership](authority.md) | Who may submit input, who accepts results, and what a player host is trusted to do |
| [State, input, and actions](state-and-inputs.md) | What peers need to retain and exchange to reproduce an interaction |
| [Ticks and clocks](clocks.md) | Why simulation, packet arrival, confirmation, and display can represent different times |
| [Prediction and correction](prediction.md) | How immediate response works, why correction repeats work, and how to choose its boundary |
| [Determinism and state boundaries](determinism.md) | Which dependencies must be reproducible and where target/build compatibility matters |
| [Presentation and effects](presentation-and-effects.md) | How animations, sound, UI, and node transforms follow a result that may change |

The [feature walkthroughs](../recipes/index.md) apply these ideas to movement,
pickups, combat, object lifetime, joining, and round changes. The
[Kit player tutorial](../../kit/quickstart.md) and
[Replay inventory tutorial](../../replay/quickstart.md) provide small running
projects to use alongside the explanations.

## Make a game usable beyond localhost

| Page | Decision it helps you make |
| --- | --- |
| [Connections and compatibility](connections-and-compatibility.md) | How a reachable process becomes a compatible, admitted player with current state |
| [Bandwidth and relevance](bandwidth-and-relevance.md) | What to send, how often, to whom, and how a recipient catches up |
| [Performance and scale](performance-and-scale.md) | How activity, interactions, correction, and retained history consume resources |
| [Testing and debugging](testing-and-debugging.md) | What to assert under delay/loss and how to find the first differing decision |
| [Recovery and trust](recovery-and-trust.md) | What reconnect, save/resume, and authority replacement must preserve and authorize |

Read a page when its problem appears in your game. A small co-op game still
needs a decision about disconnects, but it may choose to end a match when its
host leaves. A large scene still needs a bandwidth budget, even if most of its
objects change only during interactions.

## Follow the problem in a complete game

[Play Dockyard or Scrapyard](../../examples/index.md) to see a larger game before
opening its source. Choose one feature to trace rather than reading the entire
project: an interaction begins with input, changes accepted state, and reaches
the view through a defined presentation path.

For physics, continue with [Box3D concepts](../../box3d/concepts/index.md). They
explain bodies, queries, constraints, and the solver state that a multiplayer
adapter must retain.
