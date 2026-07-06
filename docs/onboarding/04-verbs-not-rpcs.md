# 4 · Verbs, not RPCs

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

Count the problems. Two code paths for the same action (host vs client), so
they *will* drift. The client's screen does nothing until the round trip
finishes, so the game feels like the network. Two players taking the last
item both pass their local checks and the resolution is whatever race the
RPCs happen to run — and every new verb repeats all of it.

The toolkit's position: this entire shape is boilerplate around one idea —
*a player wants to run a mutation, and the host decides if it's true.* So
that idea gets a name — a **command** — and the pipeline is generated.

## A verb is a proc that can say no

```odin
@(gd_command = "predict")
chest_take :: proc(self: ^Chest, slot: u8, count: u16, px, py: f32) -> bool {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	taken := kitems.take(self.slots[:], int(slot), count)
	if taken.count == 0 {return false}
	self.last_take = taken   // scratch for the hook, below
	return true
}
```

Read it again: there is no networking in it. No `is_server()`, no sender ID,
no sync call. It's single-player code that validates and mutates its entity,
returning whether it happened. The attribute generates `chest_take_cmd`, and
calling that does the right thing *wherever it's called*:

- **On the host:** run it. `true` → the mutation stands and the changed
  fields ride the ordinary delta walk to everyone (post 3 — no sync step,
  the state machinery *is* the sync step).
- **On a client:** run it **immediately** — the item appears in the
  prediction the same frame the player clicked — and send the intent to the
  host, which runs *the same proc* as the authority. If the host also says
  `true`, the client's prediction was right and nothing more happens.
- **If the host says no** — out of range on the host's truth, item already
  gone — the client's predicted mutation **reverts automatically**, and the
  rejection carries the authoritative state back with it.

Now run the race that broke the RPC version: two players grab the last item
in the same instant. Both predict success — both screens show the grab,
instantly, which is what a good game *should* show. The host runs the two
commands in arrival order: first one wins, second returns `false`, the
loser's screen quietly puts the item back a beat later. You wrote a range
check and an inventory op. Conflict resolution wasn't code you added — it
was the pipeline being a pipeline.

This is why the tutorial's promise — **gameplay code has zero role
branches** — is achievable at all. The roles differ in *when the proc runs
and what its return is allowed to mean*, and that's precisely the part
that's generated.

## The rules that keep it honest

The pipeline works because command procs accept three constraints:

**A command mutates only its target.** `chest_take` touches the chest,
period. It runs speculatively on clients and authoritatively on the host —
if it also credited your bag, sent chat, and played a sound, all of that
would run twice, or on the wrong machine, or before it was true.

**Cross-entity consequences go in the hook.** "The loot lands in MY bag" is
the host's job, once, after the verdict:

```odin
game_command_hook :: proc(user: rawptr, player: knet.Player_Id,
                          entity: knet.Net_Id, cmd: u16, ok: bool) {
	if !ok {return}
	switch cmd {
	case CHEST_CMD_TAKE: /* credit player's bag from chest.last_take */
	}
}
```

The hook fires on the authority for every executed command — a client's or
the host's own — so there's exactly one place where consequences happen,
instead of an "authority half" pasted beside every call site.

**Gate before you issue.** A predicted command that will obviously fail
(no stamina, dead, on cooldown) should be checked before calling
`chest_take_cmd` at all — a refused prediction still crosses the wire, and
the proc's own `false` is your safety net, not your UX.

Everything inside the proc must also be **deterministic and revertible** —
which is why the kit's item/inventory ops (`kitems.take`, grid packing,
stacking) are plain functions over plain data. That style pays for itself
here.

## What prediction feels like

Wire it up and play with the built-in latency shim (every kit game exposes
it as an env knob — 120ms of injected lag):

- Your clicks land **now**. Chests open, items move, doors unlock on your
  screen the frame you act.
- Truth arrives a tenth of a second later and — almost always — agrees.
- When it disagrees, the revert is small and honest: the item you "took"
  fades back because someone else was faster. Players read that instantly.

Compare that to the RPC version, where every interaction waits the round
trip, or to trusting clients, where the fast kid with Cheat Engine owns your
economy. Prediction with host verdicts is the only shape that's both
responsive and honest — and here it costs one attribute.

One special case rounds out the action story: some verbs transfer *control*
rather than items. Puttputt's entire golf mechanic is a strike command whose
hook hands the ball's ownership to the striker — the ball becomes theirs to
simulate (post 3's owner-streamed fields) until someone else putts. Grabbing,
carrying, mounting, possession: all the same three lines. Ownership is just
state, and by now that sentence should sound familiar.

There's one loose thread. The loser's item "fades back a beat later." A
remote player's pickup effect — when should *your* screen play it? You'd
think "when the state changes." You'd be wrong in a subtle way that makes
games feel cheap, and it's the last mental-model shift in the series.

*Next: [The two timelines →](05-the-two-timelines.md)*
