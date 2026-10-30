# Relic lifetime

C6 follows the original's floor lifetime and placement rules:

| Operation | Position | Carrier / version |
| --- | --- | --- |
| Initial run | `(120, 80)` | Unowned; new initial version |
| Carrying | Avatar position plus `(10, -12)` each simulation tick | Retained |
| Descent, resting | Retained | Retained |
| Descent, carried | Attached to the avatar at the new floor spawn in the same frame | Retained |
| Another run | Last simulated relic position | Released; version advances only if it had a carrier |

The original `scripts/world.odin` creates the relic once at `SPAWN_X+40,
SPAWN_Y-40`. Its descent cleanup leaves the relic alone; restart removes its owner
without writing its position. The owning player's `scripts/cavecrawl.odin`
presentation loop applies the `(10, -12)` offset. Replay previously recreated the
relic at `(240, 200)` on every floor entry, discarding ownership and changing its
version. Descent now retains that state as part of the complete replayable world.

Replay still computes carrying on the authority's simulation ticks. Original Kit
streams that position from the owner. C7 [carrier lifecycle rules](carrier.md)
retain ownership through death and ordinary disconnect, park absent carriers’
props, and resume carrying on rejoin. C8 [old-host prop adoption](adoption.md) uses recorded authority observations;
the owner-stream profile remains separate comparison work.

## Existing saves

Current content is `0x4341564552504c39`. Normal loads reject C1–C8 archives; use
`tools/upgrade_save` with a new destination. C8 adds authority observation fields to the world; the network protocol is
unchanged. C5 conversion retains every saved frame and peer field,
including the old relic position and ownership, before applying current rules on
advancement. A relic already reset by an old descent stays as recorded; the
converter cannot recover its former carrier or position. Keep the original file
and use its owning profile/token to resume. Conversion grants no authority.

The [acceptance runner](../../tests/replay_cave_relic/README.md) checks original
placement, floor/restart behavior, complete rollback state/events and real C5
archive conversion. Isolated Godot processes inspect retained transition frames,
and the full multiplayer campaign exercises carry/move/set-down under normal and
faulted network delivery.
