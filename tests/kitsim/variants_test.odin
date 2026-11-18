package kit_sim_test

import "core:testing"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import ksim "godot:kit/sim"

@(test)
predicted_scene_variants_match_and_keep_replay_identity :: proc(t: ^testing.T) {
    session: ksess.Session
    ksess.session_client_start(&session, 123, "client")
    defer ksess.session_destroy(&session)
    lane: ksim.Lane
    ksim.lane_init(&lane, &session, 1)
    defer ksim.lane_destroy(&lane)
    desc := mover_desc()
    set := ksim.Sim_Set {
        entity_desc = &desc,
        tick        = proj_fly_thunk,
    }
    first, second, third: Mover
    A :: ksess.Scene_Variant(1001)
    B :: ksess.Scene_Variant(2002)
    lane.cmd_exec_seq = 10
    first_id := ksim.lane_spawn_predicted(&lane, &first, &set, 2, PROJ_TYPE, A)
    lane.cmd_exec_seq = 11
    second_id := ksim.lane_spawn_predicted(&lane, &second, &set, 2, PROJ_TYPE, B)
    _, _, unknown_matched := ksim.lane_spawn_match(&lane, 50, 2, PROJ_TYPE, ksess.Scene_Variant(3003))
    testing.expect(t, !unknown_matched)
    entity, from, matched := ksim.lane_spawn_match(&lane, 51, 2, PROJ_TYPE, B)
    testing.expect(t, matched && entity == &second && from == second_id)
    testing.expect(t, ksim.lane_tracks(&lane, first_id))
    previous, exists := ksim.lane_spawn_of_exec(&lane)
    testing.expect(t, exists && previous.entity == &second && previous.id == 51)
    testing.expect_value(t, previous.type, PROJ_TYPE)
    testing.expect_value(t, previous.variant, B)
    entity, from, matched = ksim.lane_spawn_match(&lane, 52, 2, PROJ_TYPE, A)
    testing.expect(t, matched && entity == &first && from == first_id)
    testing.expect(t, !ksim.lane_spawn_cancel(&lane, 51)) // already committed
    lane.cmd_exec_seq = 12
    third_id := ksim.lane_spawn_predicted(&lane, &third, &set, 2, PROJ_TYPE, B)
    testing.expect(t, ksim.lane_spawn_cancel(&lane, third_id))
    testing.expect(t, !ksim.lane_tracks(&lane, third_id))
    _, exists = ksim.lane_spawn_of_exec(&lane)
    testing.expect(t, !exists)
}
