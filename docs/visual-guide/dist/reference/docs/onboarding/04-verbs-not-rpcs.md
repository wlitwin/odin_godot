<a id="4--verbs-not-rpcs"></a>

# 4 · Predicted commands

A Kit command requests a change to shared state, such as taking an item,
opening a door, or striking a ball. It can predict the target mutation locally
while the authority decides whether to accept it. This post explains the
generated request handling and the validation procedure supplied by the game.

Consider this RPC implementation of taking an item from a chest:

```gdscript
# An abridged rpc() implementation with separate host and client paths
func try_take(slot: int):
    if multiplayer.is_server():
        _do_take(slot)                      # host takes directly
    else:
        _request_take.rpc_id(1, slot)       # client asks the host

@rpc("any_peer")
func _request_take(slot: int):
    if not multiplayer.is_server(): return  # only the server handles requests
    var sender := multiplayer.get_remote_sender_id()
    if not _can_take(sender, slot): return  # validate
    _do_take_for(sender, slot)
    _sync_chest.rpc(slots)                  # tell everyone
    _grant_item.rpc_id(sender, slot)        # tell the taker
```

The host and client take different code paths, and the client waits for a
round trip before showing the result. Game code separately implements sender
validation, chest synchronization, and inventory credit. Adding local
prediction would also require a result that corrects a client when another
player took the item first.

A command supplies a validation and mutation procedure. Generated code
submits the request, executes it on the authority, and returns the result.

## Writing a command

```odin
@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED) // this chest is a world interaction
chest_take :: proc(self: ^Chest, slot: u8, count: u16, px, py: f32) -> bool {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	taken := kitems.take(self.slots[:], int(slot), count)
	if taken.count == 0 {return false}
	self.last_take = taken   // scratch for the hook, below
	return true
}
```

The procedure validates and mutates its target entity, then returns whether
the change applied. It needs no `is_server()` branch or explicit synchronization
call. The attribute generates `chest_take_cmd`, which handles each role:

- On the host, the wrapper runs the procedure directly. If it returns `true`,
  the mutation stands and ordinary replication sends the changed fields to
  peers, as described in post 3.
- On a client, this predicted policy runs the procedure immediately and sends
  the intent to the host. The host runs the same procedure against authority
  state. Confirmation retains the client's predicted mutation.
- If the host's predicate returns `false`, for example because the item is
  gone, the result includes authoritative entity state to correct the
  prediction. Admission failures restore the client's local capture while
  ordinary replication supplies newer state. The generated
  `<game>_command_rejected` half receives a typed reason such as `.Predicate`,
  `.Stale`, or `.Timeout`; game code does not decode reply packets.

If two players request the last item at the same time, both may predict
success. The host executes their commands in arrival order. The first takes
the item, and the second returns `false`. The rejected client's prediction is
then corrected using the host's state, where the item has already been taken.
The game supplies the range and inventory checks; generated code handles the
request ordering and result delivery.

The target mutation can use the same procedure on both roles. Generated code
controls when it runs and whether its result is predicted or authoritative.

## Command rules

Apply these constraints when writing a command:

**A command mutates only its target.** `chest_take` changes the chest.
It runs speculatively on clients and authoritatively on the host. If it also
credited your bag, sent chat, and played a sound, all of that would run twice,
or on the wrong machine, or before the authority accepted it.

**Cross-entity consequences go in the authority hook.** Credit the player's
bag after the host accepts the chest mutation:

```odin
game_command_hook :: proc(user: rawptr, player: knet.Player_Id,
                          entity: knet.Net_Id, cmd: u16, ok: bool) {
	if !ok {return}
	switch cmd {
	case CHEST_CMD_TAKE: /* credit player's bag from chest.last_take */
	}
}
```

The hook runs on the authority for commands issued by clients and by the host.
The `ok` check restricts the bag mutation to accepted commands. A typed
`<verb>_then` half can handle the same accepted consequence without the command
ID switch; see [command consequences](../kit/net.md#command-consequences).

**Gate before you issue.** A predicted command that local state already rules out (no
stamina, dead, on cooldown) should be checked before calling `chest_take_cmd` at
all: a refused prediction still crosses the wire, and the proc's own `false` is
the authority's validation. Use a local eligibility check to avoid unnecessary
requests and misleading feedback.

Everything inside the proc must also be **deterministic and revertible**. The
kit's item/inventory ops (`kitems.take`, grid packing, stacking) are plain
functions over plain data for this reason.

## Prediction in practice

Use the example’s documented latency setting to observe local prediction and
the later authority result:

- The target changes locally when the predicted command executes.
- The authority's verdict arrives after the simulated delay.
- If another player took the item first, the predicted mutation reverts and
  presentation must reflect the rejected pickup.

The command responds locally before a round trip while retaining authority
validation. A modified client can change its prediction, but the host still
runs the command's checks before accepting the shared mutation.

## Commands that transfer control

Some verbs transfer *control* rather than items. Puttputt's golf mechanic is a
strike command whose hook hands the ball's ownership to the striker: the ball
becomes theirs to simulate (post 3's owner-streamed fields) until someone else
putts. Grabbing, carrying, mounting, and possession can use the same pattern:
validate the command, then transfer network ownership in the authority hook.

Pickup effects also need a display time. A local prediction can appear immediately,
while a remote player’s effect must align with the buffered frame being shown.
The next post explains how to schedule both.

*Next: [The two timelines →](05-the-two-timelines.md)*
