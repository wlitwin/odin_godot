# Add pickups and inventory transfers

Build an interaction in which taking an item changes the shared world and the
correct player's inventory. This guide assumes a working [Kit](../../kit/quickstart.md)
or [Replay](../../replay/quickstart.md) project. Use a chest with five items and
two nearby players as the first case.

The useful rule to establish is conservation: after a successful transfer, the
items have moved to an allowed destination. Contention, retries, and correction
must not create another copy or silently discard an overflow.

## 1. Separate the prompt from permission

A local distance check can decide when to show “Take.” It improves feedback
without settling the interaction. By the time the authority receives a request,
the player may have moved, the chest may be empty, or the destination may be
full.

An interaction request should identify the target and the requested operation.
The authority derives the acting player from its admitted connection or seat
and checks the relevant state. A player ID inside the request cannot grant
access to another player's bag.

Define the predicates before adding animation:

- the target still exists with the expected lifetime;
- the acting player can reach or otherwise use it;
- the player is in a phase that permits interaction;
- the source contains the requested item;
- the destination can accept the transfer under the game's stacking rules.

The prompt may be optimistic while these checks are still pending. Keep its
wording and animation separate from an accepted inventory result.

## 2. Choose the mutation boundary

In ordinary Kit replication, commands predict and correct their target entity.
A command procedure may mutate that target; accepted cross-entity consequences belong in its generated
`<verb>_then` procedure on the authority. For a chest, remove the item from the
chest in the target command, return the amount taken, and credit the player's
bag in the accepted authority consequence.

[Kit items](../../kit/items.md) explains this split and the operations that need
the immutable item-definition table. In particular, stacking and growth need
the table; taking from a slot can operate on its value alone. Decide where
unaccepted inventory overflow goes, and keep that decision in authority code.
Do not predict a second entity's bag from inside the chest command.

Kit's complete Box3D mode uses staged game state in `Side` and its accepted
input path, and refuses the ordinary scheduled-verb path. Apply an inventory
transfer inside that supported game-state transaction when using this mode;
follow [Kit Box3D](../../kit/box3d.md) instead of mixing in target-field commands.

Replay can put both inventories and the pickup's membership in one World.
The model validates and changes them in the same replayable operation. When
accepted input changes the winner, replay restores all those dependencies and
runs the transfer again. Use the network runner's action interface for a
discrete player request; its admitted seat and action outcome are different
from a local input-revision experiment.

## 3. Walk through the contested last item

Both players see one remaining item and request it before receiving the other's
result:

| Stage | Player one | Player two | Authority |
| --- | --- | --- | --- |
| Request | May predict taking it | May predict taking it | Has not settled either request |
| First accepted operation | Receives the accepted result if chosen | Still waiting or predicting | Moves the item once |
| Conflicting operation | Keeps accepted inventory | Corrects the unsuccessful prediction if not chosen | Rejects because the item is gone |

The game needs an ordering rule. Kit's ordinary chest-command pattern processes
requests in authority arrival order. The local Replay Loot example uses stable
seat order inside an input batch. Neither rule implies that the first player to
click according to their own clock must win.

Choose the game's order deliberately and make the rejection understandable.
“Already taken” is a gameplay outcome. It should not cause a disconnect or
leave the inventory UI permanently waiting for a success event.

## 4. Present the result from state and identified effects

Draw inventory contents from accepted or explicitly predicted state. Use a
pending highlight when an operation is waiting, and clear it on the relevant
settled result. Reliable state can arrive in separate entity updates in Kit;
do not assume the chest and bag UI always change in one rendered frame.

A pickup sound or floating label is an effect. Decide whether it plays on a
speculative result or after acceptance. Replay presentation can confirm, change,
or cancel an occurrence whose predicted operation changed. Kit provides command
receipts and presentation event paths for choosing feedback timing.

Do not use a sound callback to credit the inventory. A replayed effect,
reconnected screen, or muted audio setting would then change gameplay. See
[Presentation and effects](../concepts/presentation-and-effects.md).

## 5. Keep definitions and membership recoverable

An item ID refers to a definition shared by the participating builds. Keep its
meaning stable within the session's content contract. Sending an integer for
“medkit” does not transmit stack size, healing amount, or eligibility rules.

When a pickup disappears, retain the state that makes its identity stale. Kit's
entity lifecycle and Replay's generational pools help distinguish a current
object from a later occupant of a reused slot. The [lifetime guide](spawning-and-lifetime.md)
explains how to carry those identities into delayed requests.

## Check the behavior

Test an empty source, a full destination, an out-of-range player, simultaneous
requests, and a request for an already removed pickup. Exercise retransmission
through the selected action/command path; a second user request with a new
identity is a separate operation and must still satisfy the gameplay predicates.

Join after the transfer and verify that current state alone explains where the
items went. Disconnect while the result is pending and verify that reconnect
reconciles the UI with the authority rather than replaying a visual click.

Run [Replay Loot](../../replay/quickstart.md) to observe a winner changing under
correction. For a larger Kit implementation, follow
[Cavecrawl's chest](https://github.com/wlitwin/odin_godot/blob/main/examples/cavecrawl/scripts/chest.odin)
alongside [Kit items](../../kit/items.md).
