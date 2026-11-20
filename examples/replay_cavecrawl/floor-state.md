# Player state across floor transitions

C5 separates three floor-entry operations. Each rebuilds floor-local objects and
resets director/den state, while avatar fields follow the corresponding rule:

| Field | Initial start | Descent | Another run |
| --- | --- | --- | --- |
| Position | Spawn position | New floor's spawn position | Spawn position |
| HP / stamina | Full | Retained after ordinary tick updates | Full |
| Rock / heal cooldowns | Cleared | Retained after ordinary tick updates | Cleared |
| Chill | Cleared | Retained after ordinary tick updates | Retained |
| Bag | Empty | Retained | Empty |
| Names and cumulative ledger | Retained | Retained | Retained |
| Pending respawn deadline | Cleared | Retained for reserved disconnected players | Cleared |

The original `cave_descend` does not rewrite spelunker HP, stamina, cooldowns, bags
or effects. Its `cave_restart` restores vitals and clears bags/cooldowns but leaves
active effects alone. The owner-side depth edge changes position. Replay keeps
its existing seat-based spawn positions and authoritative movement policy; the
field-preservation behavior follows those original rules.

The descent tick still performs ordinary cooldown/chill decay and stamina
regeneration first. Preserving state does not freeze those clocks. A reserved
player who left while dead retains the respawn deadline; returning after it
expires restores them normally, rather than leaving a dead player with no deadline.
That reservation policy is explicit because Replay retains disconnected player
state while the original's entity/session lifecycle differs.

`Floor_Entry` makes the distinction explicit at every start/restart call site.
The default `enter_floor(world)` represents descent. Complete frame ownership
means correcting an earlier door input also restores the corresponding avatar
values and event sequence; no external reset bookkeeping is needed.

## Compatibility

The server-motion profile uses content C10 (`0x4341564552504c3a`). Update peers and
service launchers together; normal loads require the current contract.

Retained fixtures preserve an injured party before descent, the already-healed
state captured after an earlier descent, and an injured end-of-run checkpoint.
Migration preserves saved values; it cannot reconstruct an injury or cooldown
already lost before capture. [Originals and receipts](../../docs/replay/results/usability-legacy-2026-11-16/cavecrawl/receipt.json) remain evidence.

The [acceptance runner](../../tests/replay_cave_floor/README.md) checks exact
current-frame resume, normal updates, restart effects, disconnected respawn and
corrected descent inputs. Native Godot probes inspect the first transition frame.
Spawn-position policy, owner motion and visual/human comparisons have separate
qualification boundaries.
