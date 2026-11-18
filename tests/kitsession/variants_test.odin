package kit_session_test

import "core:testing"
import knet "godot:kit/net"
import ksess "godot:kit/session"

BLUE_VARIANT :: ksess.Scene_Variant(0x213489ab)
RED_VARIANT :: ksess.Scene_Variant(0x453789cd)

variant_make :: proc(
    user: rawptr,
    type: ksess.Entity_Type,
    id: knet.Net_Id,
    owner: knet.Player_Id,
    variant: ksess.Scene_Variant,
) -> (
    rawptr,
    ^knet.Command_Set,
) {
    if variant != ksess.DEFAULT_SCENE_VARIANT && variant != BLUE_VARIANT && variant != RED_VARIANT {return nil, nil}
    entity, set := box_make_entity(user, type, id, owner, ksess.DEFAULT_SCENE_VARIANT)
    if entity != nil {(cast(^Peer_Box)user).made_variants[id] = variant}
    return entity, set
}

variant_box :: proc(box: ^Peer_Box, peer: ksess.Peer_Id) {
    box_make(box, peer)
    ksess.session_set_factory(&box.s, box, variant_make, box_free_entity)
}

write_variant_tuple :: proc(
    w: ^knet.Writer,
    type: ksess.Entity_Type,
    variant: ksess.Scene_Variant,
    id: knet.Net_Id,
    hp: i32,
) {
    knet.write_u16(w, u16(type))
    knet.write_u32(w, u32(variant))
    knet.write_net_id(w, id)
    knet.write_player_id(w, 1)
    knet.write_u16(w, 8)
    knet.write_i32(w, hp)
    knet.write_f32(w, 0)
    knet.write_u32(w, 0) // blob version
    knet.write_u32(w, 0) // blob length
}

@(test)
scene_variants_survive_world_paths_and_refuse_identity_changes :: proc(t: ^testing.T) {
    host, alice, late, replay, resumed: Peer_Box
    variant_box(&host, 1)
    variant_box(&alice, 100)
    variant_box(&late, 200)
    variant_box(&replay, 300)
    variant_box(&resumed, 1)
    defer {
        box_destroy(&host); box_destroy(&alice); box_destroy(&late)
        box_destroy(&replay); box_destroy(&resumed)
    }
    boxes := []^Peer_Box{&host, &alice, &late}
    ksess.session_host_start(&host.s, "host")
    ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
    ksess.session_record_start(&alice.s)
    ksess.session_client_join(&alice.s)
    pump(boxes)
    first, blue := ksess.session_spawn_make(&host.s, BOT_TYPE, variant = BLUE_VARIANT)
    (cast(^Bot)first).hp = 30
    ksess.session_spawn_send(&host.s, blue)
    ksess.session_start_replicating(&host.s)
    world_tag := host.out[len(host.out) - 1].data[0]
    pump(boxes) // initial world snapshot
    second, red := ksess.session_spawn_make(&host.s, BOT_TYPE, variant = RED_VARIANT)
    (cast(^Bot)second).hp = 40
    ksess.session_spawn_send(&host.s, red)
    spawn_tag := host.out[len(host.out) - 1].data[0]
    pump(boxes) // live spawn
    testing.expect_value(t, alice.made_variants[blue], BLUE_VARIANT)
    testing.expect_value(t, alice.made_variants[red], RED_VARIANT)
    ksess.session_client_start(&late.s, TOKEN_BOB, "late")
    ksess.session_client_join(&late.s)
    pump(boxes)
    testing.expect_value(t, late.made_variants[blue], BLUE_VARIANT)
    testing.expect_value(t, late.made_variants[red], RED_VARIANT)
    original := alice.bots[blue]

    ksess.session_set_interest(&host.s, 100, 10, nil, bot_locate)
    ksess.session_set_focus(&host.s, alice.s.me, 1000, 0)
    now := 1.0
    step(boxes, &now)
    host.bots[blue].hp = 99
    step(boxes, &now)
    testing.expect_value(t, alice.bots[blue].hp, i32(30))
    ksess.session_set_focus(&host.s, alice.s.me, 0, 0)
    step(boxes, &now) // existing-ID interest resync, same node/variant
    testing.expect(t, alice.bots[blue] == original)
    testing.expect_value(t, original.hp, i32(99))
    for event in drain(&alice.s) {
        if resync, ok := event.(ksess.Ev_Resynced); ok && resync.id == blue {
            testing.expect_value(t, resync.variant, BLUE_VARIANT)
        }
    }

    ksess.session_client_start(&replay.s, TOKEN_ALICE, "alice")
    testing.expect(t, ksess.session_replay(&replay.s, ksess.session_recording(&alice.s)) > 0)
    testing.expect_value(t, replay.made_variants[blue], BLUE_VARIANT)
    testing.expect_value(t, replay.made_variants[red], RED_VARIANT)
    testing.expect_value(t, replay.bots[blue].hp, i32(99))
    writer := knet.writer_make()
    defer knet.writer_destroy(&writer)
    ksess.session_snapshot(&host.s, &writer)
    testing.expect(t, ksess.session_host_resume(&resumed.s, alice.s.me, "heir", knet.writer_bytes(&writer)))
    testing.expect_value(t, resumed.made_variants[blue], BLUE_VARIANT)
    testing.expect_value(t, resumed.made_variants[red], RED_VARIANT)

    // Known IDs cannot swap their type or scene, even with equal field widths.
    identity_mutations := [2]bool{false, true}
    for wrong_type in identity_mutations {
        knet.writer_reset(&writer)
        knet.write_u8(&writer, spawn_tag)
        write_variant_tuple(
            &writer,
            wrong_type ? ksess.Entity_Type(999) : BOT_TYPE,
            wrong_type ? BLUE_VARIANT : RED_VARIANT,
            blue,
            -100,
        )
        reader := knet.reader_make(knet.writer_bytes(&writer))
        ksess.session_handle_packet(&alice.s, ksess.HOST_PEER, &reader)
        testing.expect(t, reader.err)
        testing.expect(t, alice.bots[blue] == original)
        testing.expect_value(t, original.hp, i32(99))
        variant, exists := ksess.session_scene_variant(&alice.s, blue)
        testing.expect(t, exists && variant == BLUE_VARIANT)
    }
    knet.writer_reset(&writer)
    knet.write_u8(&writer, world_tag)
    knet.write_u16(&writer, 2)
    write_variant_tuple(&writer, BOT_TYPE, ksess.Scene_Variant(123), 999, -100) // unknown: skip, never Default
    write_variant_tuple(&writer, BOT_TYPE, BLUE_VARIANT, blue, 77)
    reader := knet.reader_make(knet.writer_bytes(&writer))
    ksess.session_handle_packet(&alice.s, ksess.HOST_PEER, &reader)
    testing.expect(t, !reader.err && alice.bots[999] == nil)
    testing.expect_value(t, original.hp, i32(77))
    _, draft := ksess.session_spawn_make(&host.s, BOT_TYPE, variant = RED_VARIANT)
    ksess.session_despawn(&host.s, draft)
    _, exists := ksess.session_scene_variant(&host.s, draft)
    testing.expect(t, !exists)
    ksess.session_despawn(&host.s, blue)
    pump(boxes)
    _, exists = ksess.session_scene_variant(&alice.s, blue)
    testing.expect(t, !exists && alice.bots[blue] == nil)
}
