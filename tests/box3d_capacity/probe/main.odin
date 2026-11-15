package main

import "core:fmt"
import b "godot:box3d"
import limits "godot:box3d/limits"

EXPECTED_CAPACITY_MATCH :: #config(EXPECTED_CAPACITY_MATCH, true)

main :: proc() {
    status := b.abi_check()

    when EXPECTED_CAPACITY_MATCH {
        assert(status == .Ok)
        world, error := b.world_create(b.world_def_default())
        assert(error == .Ok)
        assert(b.world_destroy(&world) == .Ok)
        fmt.printfln("CAPACITY_MATCH_OK bodies=%d joints=%d", limits.MAX_BODIES, limits.MAX_JOINTS)
    } else {
        assert(status == .Incompatible)
        fmt.println("CAPACITY_MISMATCH_REJECTED before_world_construction=true")
    }
}
