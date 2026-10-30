# Wave pacing and compatibility

C4 restores the original active-floor director's timing at 20 Hz. A new floor
starts with wave zero. Its first active tick announces wave one; spawning starts
on the following tick, one dweller per tick. Completing a wave means both all
scheduled spawns and all live dwellers are gone. The last actual death starts the
authored rest, including the final wave's rest. The next wave is announced when
that deadline is reached and begins spawning on the following tick.

An empty wave has no death to start a rest, so it advances on the next director
call. A started director continues if players temporarily disconnect. A direct
server with no started party waits for its first connected player before announcing
wave one. Each new floor resets den selection to Den1 and alternates thereafter.

The previous Replay implementation waited 20 ticks for its first spawn, then ten
ticks between spawns, invented rest periods for empty waves, paused the running
director when everyone left and carried the den cursor across floors. Those
behaviors did not match the original `kit/ai` director and Cavecrawl host wiring.
Replay's implementation remains independent of Kit; only the oracle imports Kit.

## Values, rollback and capacity

The director stays wholly inside `World`. Its existing `next_spawn` field also
retains a pending deadline imported from an older save. Normal C4 pacing emits one
spawn per invocation; the game calls the director once per simulation tick.
Announcement/remaining/live counts, rest deadlines, entity generations and den
selection all participate in replay. A death near u64 exhaustion cannot wrap its
rest deadline: it aborts the staged step, preserving the prior committed world.

The fixed dweller pool still holds 16 living entities. If it is full, a pending
spawn stays pending until space is freed. The original uses dynamic entities, so
custom waves that exceed this simultaneous population do not have identical spawn
pacing. Definition limits, collision/AI behavior and unrelated combat rules are
unchanged by this increment.

## Existing saves

C4 introduced the changed director simulation. Current content C9
(`0x4341564552504c39`) also corrects [avatar transition rules](floor-state.md) and
[relic lifetime](relic.md). C8 adds authority observation fields to the world; network/checkpoint protocol
versions are unchanged. Update both game and
coordinated service before starting a current-content room. Existing C1–C7 files are not silently
loaded as new gameplay.

The existing `tools/upgrade_save` accepts C1–C7 and requires a new
destination. C3 retains every frame and session value, including live dwellers,
current wave, den cursor, and pending spawn/rest deadlines. Once those deadlines
are reached, subsequent spawns use the corrected cadence; a later floor starts
from the corrected fresh-floor state. A waiting lobby starts fresh when Start is
accepted. This does not reproduce the old timing indefinitely, convert original
Kit saves, publish a Room save or grant a new authority lease.

Tests retain real pre-change C3 waiting/pending/spawning/rest archives plus their
producer/model hashes. All six C1/C2/C3 fixture conversions resume in fresh native
Godot processes with exact converted-frame hashes and a newer local epoch.

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
