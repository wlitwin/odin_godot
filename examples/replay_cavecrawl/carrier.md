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

Current content is `0x4341564552504c39`. Convert C1–C8 archives explicitly with
`tools/upgrade_save` and a new destination. C6 conversion preserves the complete
saved frame and peer ledger; it cannot reconstruct a carrier already cleared by
old gameplay. C8 adds authority-observation fields to the world; network/checkpoint envelope
versions are unchanged. Conversion seeds those fields from the validated
checkpoint’s host-seat metadata.

The [acceptance runner](../../tests/replay_cave_carrier/README.md) covers actual
death/revive/respawn, disconnect/rejoin and identity replacement in the model,
complete corrected-input frame/event equality, archived-state conversion, native
retained frames, and carrier movement/release after planned or crashed-host
recovery. The browser variant carries the relic through the existing RTC party,
loot, door, social and handoff story.
