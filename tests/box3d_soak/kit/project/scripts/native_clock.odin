// TEST ONLY. No clock call is reachable from functional/structure modes.
package kit_gate_b_project

import gd "godot:godot"
import obs "godot:tests/box3d_soak/native_observe"

Native_Clock_State :: struct {
    singleton:     gd.Time,
    block:         ^obs.Block,
    prewarm_reads: u64,
}

@(private)
native_clock: Native_Clock_State
#assert(size_of(Native_Clock_State) == 24)

native_clock_prepare :: proc(block: ^obs.Block) -> bool {
    if block == nil || (native_clock.block != nil && native_clock.block != block) {
        return false
    }

    singleton := gd.singleton_time()

    if singleton == nil {
        return false
    }

    // Resolve the Godot method binding once, BEFORE the future outer timer.
    // This branch is guarded by profile+explicit grant in prepare, never called
    // by functional OFF/structure verification. No value is used as gameplay.
    _ = gd.time_get_ticks_usec(singleton)
    native_clock = {singleton, block, native_clock.prewarm_reads + 1}
    return true
}

native_clock_read :: proc "c" (user: rawptr, out: ^u64) -> u32 {
    // The actual block has an explicit retained Meter DataLease + origin Owner;
    // stable Core remains OUTSIDE this entire Native callback and return.
    if out == nil || user == nil || user != native_clock.block || native_clock.singleton == nil {
        return 0
    }

    out^ = gd.time_get_ticks_usec(native_clock.singleton)
    return 1
}

native_clock_clear :: proc() {
    native_clock = {}
}
