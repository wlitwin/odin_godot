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
the [owner-motion companion](../replay_cavecrawl_owned/README.md) has separate
implementation and comparison evidence.

## Existing saves

Current content is C9. Retained relic fixtures were migrated before removing old
readers. Resting position, carrier and version remain saved values; current rules
apply only as simulation advances. A previously lost carrier cannot be inferred.
[Originals and receipts](../../docs/replay/results/usability-legacy-2026-11-16/cavecrawl/receipt.json) remain historical evidence.

The [acceptance runner](../../tests/replay_cave_relic/README.md) checks placement,
version 7 through descent, carried attachment, and release in place with version 8
on restart. Isolated Godot processes inspect those transition frames. Multiplayer
campaigns separately exercise carry/move/set-down under normal and faulted delivery.
