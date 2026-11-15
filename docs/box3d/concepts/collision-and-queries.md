# Collisions, sensors, and queries

Use collision response for objects that must push against each other, sensors
for overlap observations, and queries for questions asked by gameplay. These
mechanisms can share geometry while serving different rules.

A warehouse game illustrates the distinction. A crate rests on the floor, a
delivery zone observes which crate entered it, and a robot's magnet checks what
lies along its reach. Treating all three as a generic collision callback makes
it difficult to control filtering, replay, and the timing of effects.

## Choose how the interaction is observed

| Mechanism | What it contributes | Warehouse example |
| --- | --- | --- |
| Contact response | Solver constraints that affect body motion | A crate rests on a ramp and collides with another crate |
| Sensor overlap | Begin/end observations without solid contact response | A delivery zone detects cargo inside its volume |
| Query | Copied results from an explicit request against a world | A magnet checks reach and obstruction |

Material settings shape solid contact response. Friction resists sliding along
the contact, while restitution affects bounce. Body damping affects motion even
without contact. If a crate keeps sliding, inspect its contact materials and
the game rule that writes its velocity. Replacing velocity every tick can
override the response you are trying to tune.

A sensor entering a crate's volume does not by itself award money or complete
a delivery. The game decides whether the crate is eligible, whether it remained
inside long enough, and whether a player is still holding it. Those values
belong in gameplay state so correction can restore the decision.

Similarly, a query does not establish that a client's requested interaction is
authorized. The authority must apply the game's rules to the result from the
appropriate simulation state. A ray drawn by a client can help aim while the
accepted interaction still uses the authority's world.

## Design filters as a policy

A shape's category bits describe what it is. Its mask bits describe which
categories it accepts. Normal shape filtering requires both sides to accept
the other category. Setting only the player's mask can leave a desired
interaction disabled by the crate's mask.

For example, a game could assign the following categories:

| Category | Bit | Intended role |
| --- | --- | --- |
| World | 1 | Floors and walls |
| Player | 2 | Physical player proxies |
| Cargo | 4 | Movable loads |
| Delivery zone | 8 | Sensor volumes |

Cargo might accept World, Player, Cargo, and Delivery zone. A delivery sensor
can accept Cargo while ignoring player bodies. The category names are game
definitions; Box3D supplies the bit fields rather than a built-in warehouse
layer scheme.

Equal nonzero shape group indices override the category/mask decision: a
positive shared index enables the shape-filter match and a negative shared
index disables it. Other rules still matter, including body types and whether
connected bodies may collide. A shared negative group can be useful for parts
of one mechanism that must avoid self-contact. Giving unrelated mechanisms the
same group accidentally changes their interaction too.

Queries have their own category and mask fields. A query's category must also
be accepted by the target shape's mask. In the example above, a magnet query
using the Player category can see Cargo that accepts Player. The motion query
filter also chooses whether to include sensors and can exclude the querying
body. Self-exclusion matters when a ray begins near the robot's own collision.

## Match the query to the question

An axis-aligned bounding-box query finds overlapping bounds. It is useful for
collecting candidates in a region; the result may still require a more precise
geometry or gameplay test. A ray has no thickness and follows a displacement.
Its translation argument is the complete displacement, so a direction vector
of length one describes a different reach from one of length ten.

A capsule overlap asks about a volume at a position. A capsule cast asks about
that volume along a displacement. A volume cast is often a better fit than a
thin ray when a character or thick object must fit through a space. It also
costs different work, so use the shape the decision requires.

For a magnet, choosing the intended cargo from copied poses and checking its
reach are separate decisions. The nearest cargo can be behind a wall. A game
can retain the chosen target while the button stays held, then use the native
query to decide whether the pull currently succeeds. This keeps target
selection predictable without granting a pull through an obstruction. The
[Dockyard source](https://github.com/wlitwin/odin_godot/tree/main/examples/replay_dockyard)
separates presentation controls from its simulation rule in this way.

## Consume complete results deliberately

The motion query family provides complete, bounded results with stable sorting.
Ray and cast results order by hit fraction with stable identity and geometry
ties. An undersized output returns a capacity error without publishing a
partial prefix. Check status before choosing a target from that buffer.

The lower-level legacy query and sensor-read APIs have different buffer
contracts; some copy the prefix that fits and return the total available count.
Choose a query family deliberately and read its contract. Treating an overflow
as “no obstacle” can turn a busy scene into a gameplay exploit.

Results identify native shapes and bodies through allocation keys. Resolve
those through the game's current mapping before using them as gameplay
identities. A key from a different world construction or an obsolete entity
lifetime cannot establish that today's crate is the same object.

## Keep observations and effects at their own times

Supported primitive and convex sensor interactions require sensor events
enabled on both the sensor and visitor shapes. Meshes and heightfields are
static, non-sensor collision, and require their sensor-event flags disabled.
See [authoring constraints](../reference.md) when choosing geometry.

The framework adapters retain physics observations with their complete state.
When a corrected tick changes an overlap, gameplay and the resulting event
must follow that corrected state. Playing a delivery sound directly from each
execution of a sensor branch can repeat it during resimulation. Record the
gameplay result, then let [presentation and effects](../../multiplayer/concepts/presentation-and-effects.md)
handle its visible lifetime.

When an interaction fails, compare the intended categories, both masks, query
filter, self-exclusion, event flags, and returned status against one concrete
pair of objects. That gives a smaller problem to inspect than changing every
filter until the scene appears to work.
