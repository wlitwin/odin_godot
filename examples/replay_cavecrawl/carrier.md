# Carrier death, disconnect and recovery

C7 retains relic ownership through carrier death, revive and automatic respawn.
The relic remains attached to a connected avatar at `(10, -12)`. A disconnected
carrier keeps ownership and version, while the relic stays at its last recorded
position. Rejoining with that reserved identity resumes attachment. Another
player cannot grab the still-owned relic. Restart explicitly releases it.

These rules follow the original carry loop and session departure handling:
`scripts/cavecrawl.odin` attaches without an HP gate, its `player_left` hooks only
report departure, and Kit's `session.mark_left` retains entity ownership. The
original UI prevents a dead player from issuing gameplay controls, as Replay's
action predicate does. Replay previously cleared relic ownership on its first
dead/disconnected tick, including temporary membership loss during recovery.

Replay can explicitly replace a reserved seat with a different identity. Its
`reset_player` releases that seat's relic at the existing position, advancing
the version once. This prevents a new occupant from inheriting a former player's
possession. Ordinary rejoin does not call this identity-reset path.

<a id="what-is-still-different"></a>

## Differences from owner-streamed Kit behavior

Replay computes attachment in the simulation. Original Kit streams owner poses.
A disconnected Replay avatar may move to a new floor under the existing reserved
avatar policy; the parked relic does not follow until the carrier returns.
Original floor progression includes disconnected avatar bodies in its gate.

C8 [adopts the old host’s relic](adoption.md) on a recorded authority change,
matching Kit’s non-avatar orphan sweep. Successor/guest carriers retain ownership.
Owner-streamed pose behavior and the disconnected-body floor gate remain separate
comparison boundaries.

## Compatibility and acceptance

Current content is C10. Current checkpoint fixtures preserve carrier identity,
relic version/position and the peer ledger through death or disconnection. They
were migrated once; [originals and receipts](../../docs/replay/results/usability-legacy-2026-11-16/cavecrawl/receipt.json) remain evidence. Loading
cannot recover ownership already discarded by an earlier game.

The [acceptance runner](../../tests/replay_cave_carrier/README.md) covers death,
respawn, disconnect/rejoin, identity replacement, corrected-input state/events,
exact resume and retained transition frames. Planned/crashed-host recovery and
browser carrying/handoff scenarios remain separate live network checks.
