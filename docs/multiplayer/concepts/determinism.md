# Determinism and replayable rules

A replayable rule must compute an appropriate result when the runtime executes
an old tick again. Deterministic peer rollback requires the participating
machines to agree on that result too. This page explains the dependencies behind
both requirements and how they affect Kit, Replay, and Box3D.

Two players receiving the same “fire” input is insufficient. They also need the
same weapon state, target state, accepted ordering, and definitions for what
firing does. Hidden differences can change which target is hit or whether a
projectile exists, even when both players' current positions look similar.

## Define what determines the next frame

A simulation result depends on its starting state, ordered inputs and actions,
immutable content, and the algorithms that execute the step. Every changing
dependency must return to the same historical value when the step is replayed.

| Dependency | A repeatable arrangement | A source of disagreement |
| --- | --- | --- |
| Time | Tick numbers and fixed-step rules | Reading the current wall clock inside an old tick |
| Randomness | RNG state retained with gameplay state | A global generator advanced by unrelated code |
| Entity lifetime | Restorable membership, allocation order, and generations | Assigning a new ID from an external counter on each replay |
| Iteration | Defined order and explicit tie-breaks | Depending on hash-map or pointer order |
| Collision | Historical dynamic state and compatible immutable geometry | Querying today's Godot scene while rebuilding an old tick |
| Content | Versioned weapon, map, and rule definitions | Changing damage or geometry without changing session identity |

Reading from a pointer-free World helps make these dependencies visible. It
does not prove a callback is pure: the procedure can still read a mutable
global or call an engine service. Keep those operations outside simulation and
capture their relevant results through the game's accepted input or state
boundary.

## Make ordering part of the rules

Suppose two enemies are equally close and a turret may choose one target. A
loop that selects the first minimum will choose whichever enemy happens to be
visited first. If container iteration differs across machines or after a restore,
the turret can choose another target and produce a different future.

Give the tie a game-defined answer, such as a stable entity identity. Ensure that
identity's allocation and lifetime are also historical. Sorting by an address
would retain a machine-specific dependency.

The order of state-changing actions matters too. Taking the last item, spending
the last unit of energy, and destroying a platform are operations whose results
can depend on what happened earlier in that tick. Use the selected runner's
accepted action order consistently. Changing the order during replay changes
the rules, even if every individual action is valid.

## Keep randomness with the decisions it affects

Replay supplies `Rng` for frame-owned random state. Retaining its state makes
the next random draw reproducible when the same sequence of rules runs again.
A seed alone does not describe the generator's position after many draws.

Consider projectile spread sharing a generator with cosmetic sparks. Adding a
spark can consume a random value and change the next shot. Cosmetic work should
use its own presentation randomness. Gameplay randomness belongs in historical
state, with a deliberate decision about whether unrelated systems share a
stream or have separate stored streams.

Different accepted input can legitimately produce different random consumption
and a different future. The goal is agreement for the same starting state and
accepted sequence, rather than preserving a predicted outcome after its cause
changes.

## Numerical requirements depend on the runtime

Ordinary Kit simulation is server-authoritative. Its clients can correct
numerical disagreement using authority snapshots, so its contract does not
require bit-exact cross-machine results. The local rule still needs to behave
consistently enough that correction is occasional and useful. Hidden state or
large repeated divergence cannot be repaired by choosing a smoother visual blend.

Replay's authoritative runner also has an accepted state against which clients
can reconcile. Replay's deterministic P2P runner instead expects participants
to reproduce the match from exchanged inputs; it has no state-authority peer
that can supply the winning answer after a mismatch.

The current P2P runner rejects float-bearing state, input, and event schemas,
along with platform-sized integer fields. Its
[`replay/deterministic` package](https://github.com/wlitwin/odin_godot/blob/main/replay/deterministic/README.md)
provides checked Q24.8 arithmetic and integer queries. Fixed-point arithmetic
still needs defined overflow, rounding, iteration, and collision behavior.
Floating intermediates hidden inside the callback also remain the author's
responsibility.

Box3D uses a separate native compatibility contract: exact physics peers require
the same build and target. Debug and Release, scalar and SIMD variants, and
different architectures can have different identities and results. Its snapshot
and recovery support must not be interpreted as cross-target deterministic
physics. See [Box3D support](../../box3d/support.md) before selecting a match's
physics configuration.

## Compare logical state and the first differing tick

Raw struct memory can include padding that has no gameplay meaning. Use the
framework's canonical codecs and logical diagnostics for comparisons instead
of inventing a hash over arbitrary in-process bytes. A wire schema describes
logical representation; it does not establish that two builds use the same
game rules or immutable content.

Replay's audit re-executes retained input without publishing the result and
reports a difference in state or occurrences. This can expose a dependency that
changed between the original step and the audit. The P2P runner also checks
confirmed canonical state and occurrence history; a disagreement enters its
divergence handling rather than choosing a peer's state arbitrarily.

A mismatch is a consistency signal. It does not identify a malicious player or
authenticate a sender. Find the first differing tick, compare the accepted
inputs, then inspect the fields and rules that could change at that transition.
A late rendering difference is often a consequence of an earlier simulation
difference.

For a small model, consider running the same initial frame and recorded input
twice, then repeating from a retained midpoint. Matching results should include
entity membership, cooldowns, RNG, and occurrences as well as positions. Native
and browser targets need their own comparisons before joining the same
deterministic match. Continue with [testing and debugging](testing-and-debugging.md)
and the [Replay P2P contract](https://github.com/wlitwin/odin_godot/blob/main/replay/p2p/README.md).
