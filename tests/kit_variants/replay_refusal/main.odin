package main

import "core:fmt"
import "core:os"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import ksim "godot:kit/sim"
import kboot "godot:kit/boot"

// Run with assertions disabled: an incompatible replay request must still
// refuse reuse, even when the development diagnostic is compiled out.
main :: proc() {
    body: f32
    session: ksess.Session
    ksess.session_client_start(&session, 123, "client")
    defer ksess.session_destroy(&session)
    lane: ksim.Lane
    ksim.lane_init(&lane, &session, 1)
    defer ksim.lane_destroy(&lane)
    fields := [?]knet.Field_Desc{{size = 4, flags = {.Predicted}, lerp = .F32}}
    desc := knet.Entity_Desc {
        fields = fields[:],
    }
    set := ksim.Sim_Set {
        entity_desc = &desc,
        tick = proc(entity: rawptr, input: rawptr, lane: ^ksim.Lane, owner: knet.Player_Id) {},
    }
    lane.cmd_exec_seq = 7
    provisional := ksim.lane_spawn_predicted(&lane, &body, &set, knet.PLAYER_ID_INVALID, 1, 2)
    _, _, matched := ksim.lane_spawn_match(&lane, 10, knet.PLAYER_ID_INVALID, 1, 2)
    if !matched {os.exit(4)}
    boot := kboot.Boot {
        lane = &lane,
    }
    entity, id := kboot.boot_spawn_predicted(&boot, 1, knet.PLAYER_ID_INVALID, 2)
    if entity != &body || id != 10 {os.exit(1)}
    entity, id = kboot.boot_spawn_predicted(&boot, 1, knet.PLAYER_ID_INVALID, 3)
    if entity != nil || id != 0 {os.exit(2)}
    entity, id = kboot.boot_spawn_predicted(&boot, 2, knet.PLAYER_ID_INVALID, 2)
    if entity != nil || id != 0 {os.exit(3)}
    fmt.println("KIT_VARIANT_REPLAY_REFUSAL_OK")
}
