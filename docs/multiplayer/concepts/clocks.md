# Simulation ticks and display time

A multiplayer game has several useful notions of time. Understanding which one
an operation uses helps explain delayed motion, corrections, repeated input,
and effects that seem to happen before their visible cause. This page applies
to both Kit and Replay.

The simulation's tick number describes a step in game history. A monotonic
clock measures elapsed time outside that history. A rendered frame describes
a chance to update the screen. They do not advance in a one-to-one relationship.

## Give each clock a job

| Clock or position | What it means | Typical work |
| --- | --- | --- |
| Simulation tick | One fixed-duration transition in gameplay history | Movement, cooldowns, collision, and rules |
| Accepted authority state | The state the authority has produced for a tick | Validation and correction |
| Predicted head | The newest speculative tick the client has simulated | Responsive local control |
| Confirmation frontier | The latest tick settled under the runtime's authority or commit protocol | Settling occurrences and protecting committed history |
| Display time | The state time selected for drawing or playing effects | Interpolation, animation, and camera presentation |
| Monotonic elapsed time | Time passing outside simulation history | Connection timeouts, retries, and frame scheduling |

A weapon cooldown normally belongs to simulation ticks. It should return to its
earlier value during replay. A connection timeout belongs outside that history:
restoring an old frame must not reset the network's elapsed-time measurement.
Calendar time can jump when a machine adjusts its clock; use the runtime's
monotonic timing contract for elapsed-time scheduling and timeouts.

## Packets arrive at uneven times

**Latency** is the time an operation spends traveling through a path. One-way
network latency measures travel in one direction. **Round-trip time**, or RTT,
measures the journey to another endpoint and back. Halving RTT does not prove
the actual delay in either direction; the paths can be asymmetric, and an
observed action response can include processing and scheduling time too.

**Jitter** is variation in arrival timing. A sender can produce a snapshot every
20 ms while the receiver sees gaps of 15, 40, and 5 ms. Drawing directly on each
arrival exposes those gaps as uneven motion. Interpolation buffering trades
additional display delay for more regular samples to draw between.

A lost packet supplies no new sample. Reordering can make an older sample
arrive after a newer one, and retries can produce duplicate delivery. Those
conditions require appropriate protocol behavior: tick identity, stale-data
handling, action identity, and baseline recovery. Increasing interpolation alone
cannot recover an action the authority never accepted.

## A frame can contain several ticks

A renderer might run at 144 frames per second while a simulation runs at 60
ticks per second. Some rendered frames will have no new simulation result. A
long rendered frame can require more than one fixed step to catch up, within
the runner's configured work bounds.

At 60 ticks per second, one tick represents about 16.7 milliseconds. A cooldown
of 30 ticks represents half a second of simulated time. These numbers illustrate
the relationship; use the rate configured for your runner. Box3D's current
framework profile specifically requires 60 Hz and four native substeps per tick.
Those substeps are internal physics work, rather than four gameplay ticks.

Movement rules should use a fixed step consistent with that configuration.
Reading each rendered frame's delta inside a historical tick makes the same
input produce a different result when the renderer has a different workload.
Replay reconstructs simulation ticks, including ticks that occur between two
visible frames.

The outer runtime owner controls the pump. A Replay Room already drives its
Session, and the Session drives its selected runner. Pumping an inner owner
again adds work outside the intended schedule. Similarly, a framework-owned
Box3D world must not receive a second manual step from Godot's physics callback.
See [physics ownership](../../box3d/ownership.md).

## Different screens can display different ticks

Suppose an authority has reached tick 100. A client may already predict its
local player at 104 while drawing a remote opponent from received history at
97. Those positions are illustrative, not SDK defaults:

| Value on one client screen | Selected time | Reason |
| --- | --- | --- |
| Local player's movement | Predicted tick 104 | Respond before a round trip |
| Remote opponent's movement | Watched tick 97 | Interpolate between received samples |
| Accepted score | Latest received authority value | Report the settled game result |

Watching slightly older state gives interpolation two samples to blend between
and absorbs some arrival jitter. Drawing the newest packet immediately makes
packet timing visible as uneven motion. More buffering can improve continuity
while increasing the delay between an accepted movement and its display.

Prediction and interpolation solve different problems. Prediction computes a
possible future from available inputs. Interpolation chooses a value between
known samples. Increasing an interpolation delay does not make a local input
more responsive, and predicting a remote player's unknown input adds uncertainty.

## Put visible consequences on the cause's clock

Imagine a watched opponent collecting a pickup. The authority's “taken” state
can arrive while the opponent is still visibly approaching it on the delayed
clock. Hiding the pickup immediately makes the collection appear to happen at
a distance.

The gameplay state should accept the authority result. Presentation can
schedule the disappearance and associated effect when the watched player reaches
the collection time. A local predicted pickup can display its feedback earlier
and revise it if rejected. A chat message has no moving cause and generally
does not need that spatial delay.

Kit supplies different presentation models for owner streams, predicted local
entities, watched entities, and contested objects. A presentation claim selects
which view of an object to show; it does not transfer gameplay authority. Replay
supplies copied frames and occurrence changes, with presentation selecting a
display time. See [Kit timelines](../../kit/timelines.md) and
[presentation and effects](presentation-and-effects.md).

## An input timestamp needs a policy

Sampling a device, sending a packet, receiving it, and applying it to a tick are
separate moments. The runtime must define which sample belongs to which tick
and what happens when it arrives late.

Input delay deliberately schedules local controls farther ahead. That gives
inputs more time to arrive before their simulation tick, trading local response
delay for less speculative work. Prediction uses estimated or held inputs when
the required samples are unavailable. Different runners expose different
controls and bounds for this tradeoff.

Replay's P2P runner retains a captured future input even while simulation waits.
A second rendered frame must not replace a sample already sent to peers. Its
capture result tells the device layer when an edge has been consumed. The
[P2P contract](https://github.com/wlitwin/odin_godot/blob/main/replay/p2p/README.md)
describes that distinction.

Historical hit judgment is another explicit policy. It reconstructs eligible
target state for the shooter's supported view time, within authority bounds.
It does not authorize arbitrary backdated requests or rewind every operation
in the game. The [weapon guide](../recipes/weapons-and-damage.md) connects view
time to hit validation.

## Read timing symptoms before tuning

A pickup disappearing ahead of a remote player suggests mixed display times.
A cooldown changing with frame rate suggests a render-time dependency in the
rules. Movement continuing during a loss burst may follow the configured held
input policy. A stalled prediction can mean the runner has reached its allowed
horizon and needs more accepted information.

Record tick numbers and the selected display time alongside those observations.
Elapsed milliseconds alone cannot show whether two values describe the same
simulation moment. Continue with [prediction and correction](prediction.md)
before changing history, lead, or interpolation settings.
