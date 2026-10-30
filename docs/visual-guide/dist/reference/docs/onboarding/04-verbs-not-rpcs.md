# 4 · Verbs, not RPCs

A **command** is how a player runs a mutation and lets the host decide whether it's true. You reach for one whenever a player acts on shared state: taking an item, opening a door, striking a ball. This post shows what a command replaces and how to write one.

Here is "take an item from a chest" the way every RPC tutorial teaches it:

```gdscript
# The version you'd write with rpc() — abridged, and already going wrong
func try_take(slot: int):
    if multiplayer.is_server():
        _do_take(slot)                      # host takes directly
    else:
        _request_take.rpc_id(1, slot)       # client asks the host

@rpc("any_peer")
func _request_take(slot: int):
    if not multiplayer.is_server(): return  # trust nothing
    var sender := multiplayer.get_remote_sender_id()
    if not _can_take(sender, slot): return  # validate
    _do_take_for(sender, slot)
    _sync_chest.rpc(slots)                  # tell everyone
    _grant_item.rpc_id(sender, slot)        # tell the taker
```

There are two code paths for the same action (host vs client), so they *will*
drift. The client's screen does nothing until the round trip finishes, so the
game feels like the network. Two players taking the last item both pass their
local checks, and the resolution is whatever race the RPCs happen to run. Every
new verb repeats all of it.

A command replaces that whole shape: a player wants to run a mutation, and the
host decides if it's true. The pipeline around that idea is generated.

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

There is no networking in it: no `is_server()`, no sender ID, no sync call. It's
single-player code that validates and mutates its entity, returning whether it
happened. The attribute generates `chest_take_cmd`, and calling that does the
right thing wherever it's called:

- **On the host:** it runs directly. If it returns `true`, the mutation stands
  and the changed fields ride the ordinary delta walk to everyone (see post 3;
  there is no separate sync step, since the state machinery is the sync step).
- **On a client:** it runs **immediately**, so the item appears in the
  prediction the same frame the player clicked, and the intent is sent to the
  host, which runs *the same proc* as the authority. If the host also says
  `true`, the client's prediction was right and nothing more happens.
- **If the host says no** (out of range according to the host's truth, or the
  item is already gone), the client's predicted mutation **reverts
  automatically**, and the rejection carries the authoritative state back with
  it. A generated `<game>_command_rejected` half receives a typed reason such
  as `.Predicate`, `.Stale`, or `.Timeout`; gameplay never decodes a reply or
  guesses why silence happened.

Run the race that broke the RPC version: two players grab the last item in the
same instant. Both predict success, so both screens show the grab instantly. The
host runs the two commands in arrival order: the first wins, the second returns
`false`, and the loser's screen puts the item back a beat later. You wrote a
range check and an inventory op; the pipeline handles conflict resolution.

This is what lets gameplay code carry **zero role branches**. The roles differ
only in *when the proc runs and what its return is allowed to mean*, and that is
the generated part.

## Command rules

Command procs must accept three constraints.

**A command mutates only its target.** `chest_take` touches the chest, period.
It runs speculatively on clients and authoritatively on the host. If it also
credited your bag, sent chat, and played a sound, all of that would run twice,
or on the wrong machine, or before it was true.

**Cross-entity consequences go in the hook.** "The loot lands in MY bag" is the
host's job, once, after the verdict:

```odin
game_command_hook :: proc(user: rawptr, player: knet.Player_Id,
                          entity: knet.Net_Id, cmd: u16, ok: bool) {
	if !ok {return}
	switch cmd {
	case CHEST_CMD_TAKE: /* credit player's bag from chest.last_take */
	}
}
```

The hook fires on the authority for every executed command (a client's or the
host's own), so there's exactly one place where consequences happen.

**Gate before you issue.** A predicted command that will obviously fail (no
stamina, dead, on cooldown) should be checked before calling `chest_take_cmd` at
all: a refused prediction still crosses the wire, and the proc's own `false` is
your safety net, not your UX.

Everything inside the proc must also be **deterministic and revertible**. The
kit's item/inventory ops (`kitems.take`, grid packing, stacking) are plain
functions over plain data for this reason.

## Prediction in practice

Wire it up and play with the built-in latency shim (every kit game exposes it as
an env knob that injects 120ms of lag):

- Your clicks land **now**. Chests open, items move, doors unlock on your screen
  the frame you act.
- Truth arrives a tenth of a second later and, almost always, agrees.
- When it disagrees, the revert is small and honest: the item you "took" fades
  back because someone else was faster. Players read that instantly.

The RPC version makes every interaction wait the round trip. Trusting the client
instead lets a modified client rewrite your economy. Prediction with host
verdicts is both responsive and honest, and it costs one attribute.

## Commands that transfer control

Some verbs transfer *control* rather than items. Puttputt's golf mechanic is a
strike command whose hook hands the ball's ownership to the striker: the ball
becomes theirs to simulate (post 3's owner-streamed fields) until someone else
putts. Grabbing, carrying, mounting, possession are all the same three lines.
Ownership is just state.

One question is left open. The loser's item "fades back a beat later," and a
remote player's pickup effect has to play on your screen at some point, but
*when*? It is not simply "when the state changes"; the timing is the
mental-model shift the next post covers.

*Next: [The two timelines →](05-the-two-timelines.md)*
