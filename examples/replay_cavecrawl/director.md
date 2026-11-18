# Wave pacing and compatibility

The active-floor director follows the original game's timing at 20 Hz. A new floor
starts with wave zero. Its first active tick announces wave one; spawning starts
on the following tick, one dweller per tick. Completing a wave means both all
scheduled spawns and all live dwellers are gone. The last actual death starts the
authored rest, including the final wave's rest. The next wave is announced when
that deadline is reached and begins spawning on the following tick.

An empty wave has no death to start a rest, so it advances on the next director
call. A started director continues if players temporarily disconnect. A direct
server with no started party waits for its first connected player before announcing
wave one. Each new floor resets den selection to Den1 and alternates thereafter.

Before C4, Replay waited 20 ticks for its first spawn, then ten
ticks between spawns, invented rest periods for empty waves, paused the running
director when everyone left and carried the den cursor across floors. Those
behaviors did not match the original `kit/ai` director and Cavecrawl host wiring.
Replay's implementation remains independent of Kit; only the oracle imports Kit.

## Values, rollback and capacity

The director stays wholly inside `World`. Its existing `next_spawn` field also
retains a pending deadline imported from an older save. The corrected pacing emits one
spawn per invocation; the game calls the director once per simulation tick.
Announcement/remaining/live counts, rest deadlines, entity generations and den
selection all participate in replay. A death near u64 exhaustion cannot wrap its
rest deadline: it aborts the staged step, preserving the prior committed world.

The fixed dweller pool still holds 16 living entities. If it is full, a pending
spawn stays pending until space is freed. The original uses dynamic entities, so
custom waves that exceed this simultaneous population do not have identical spawn
pacing. Definition limits, collision/AI behavior and unrelated combat rules are
unchanged by the director timing change.

## Existing saves

Current content is C9. Retained director checkpoints use the current contract,
with live dwellers, wave/den progress and scheduled spawn/rest deadlines preserved.
Tests verify the pending spawns at ticks 20/21 and the rest transition at 41/42.
The current rules govern later execution; loading does not reset saved deadlines.

Fifteen ordinary-profile fixtures resume in fresh native Godot processes with
exact frame hashes and a newer epoch. The [migration receipt](../../docs/replay/results/usability-legacy-2026-11-16/cavecrawl/receipt.json) preserves
provenance; no old schema decoder is needed by those checks.

## Comparison scope

The oracle executes the unchanged original director beside Replay's real director
and rock-death handling. Six named scenarios plus 256 generated wave/rest/death
plans compare announcement, spawn ticks, pending/live counts, active rest time,
completion and den counts for 1,000 ticks each. The same corpus runs natively and
in freestanding WASM. Unit tests cover pool saturation, floor den reset, death/rest
input revision and overflow rollback. Normal/faulted full-game campaigns still
require 12 slain dwellers, eight gems, both death paths, two floors and a common
victory-frame hash.

This is director timing evidence, not full-game parity. C5 fixes the previously
recorded avatar-vitals/cooldown discrepancy and C6 corrects relic floor lifetime.
Navigation, owner-streamed movement and broader visual/human comparisons remain
separate work.
