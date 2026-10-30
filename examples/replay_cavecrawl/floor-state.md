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
field-preservation behavior now follows those original rules.

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

C5 introduced these avatar rules. The server-motion profile uses content C9
(`0x4341564552504c39`), retaining the [relic floor-lifetime rules](relic.md).
Update game peers and service launchers together. Ordinary loads reject older
content rather than converting it silently. C8 introduced authority observation
fields; network/checkpoint protocol versions are unchanged.

The C1–C7 paths in `tools/upgrade_save` convert into a new file using frozen old
descriptors. C8 imports retain their existing authority observation. See the
[current save-conversion guide](authoring.md#existing-replay-saves) for accepted
formats and the command. C4 conversion keeps
every saved frame/session field. Future descents/restarts follow current rules. If an
old save was already healed by a C4 descent, the converter cannot reconstruct its
prior injury or cooldowns; it preserves the saved values. Conversion does not
publish a Room save or grant authority. Keep the source archive and use the same
owning profile when resuming.

Three pre-change C4 fixtures capture an injured party before descent, the old
healed state afterward, and an injured end-of-run checkpoint. Along with C1–C3,
all nine fixture conversions resume exactly in fresh native processes. A separate
Godot gate reads the actual retained frame immediately after descent/restart.

The [acceptance runner](../../tests/replay_cave_floor/README.md) covers normal tick
updates, restart effects/ledger, a disconnected respawn, corrected descent inputs,
conversion, and complete normal/faulted campaigns. Browser handoff and durable
checkpoint publication/restart have separate regression evidence.

This closes the avatar-vitals/cooldown descent gap. Other correspondence work
remains, including spawn-position policy, owner-streamed motion, and broader
visual/human comparisons. C6 separately corrects relic descent/restart behavior.
