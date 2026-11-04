package godot_lifetimes_probe

import "core:fmt"
import gd "godot:godot"

// Signaling opens on native builds without a WebRTC extension. No server or
// remote peer is needed to exercise failed setup and pre-handshake teardown.
webrtc_helper_lifetimes :: proc(owner: gd.Node) -> bool {
    mp := gd.node_get_multiplayer(owner)
    defer gd.release_ref(mp)
    before_peer := gd.multiplayer_api_get_multiplayer_peer(mp)
    defer gd.release_ref(before_peer)
    replacement := gd.new_offline_multiplayer_peer()
    gd.ref_counted_init_ref(replacement)
    defer gd.release_ref(replacement)
    refs_before := gd.ref_counted_get_reference_count(mp)
    objects_before := gd.performance_get_monitor(gd.singleton_performance(), .Object_Count)

    for _ in 0 ..< 32 {
        if !gd.webrtc_host(owner, "ws://127.0.0.1:1") {
            return false
        }

        if gd.webrtc_join(owner, "ws://127.0.0.1:1", "duplicate") {
            return false
        }

        if gd.ref_counted_get_reference_count(mp) != refs_before + 1 {
            return false
        }

        gd.webrtc_close(owner)
        gd.webrtc_close(owner)
        current := gd.multiplayer_api_get_multiplayer_peer(mp)
        preserved := current == before_peer
        gd.release_ref(current)

        if !preserved || gd.ref_counted_get_reference_count(mp) != refs_before {
            return false
        }
    }

    // The socket parser refuses this invalid port synchronously. Suppress only
    // that expected engine diagnostic; restore error reporting before assertions.
    engine := gd.singleton_engine()
    print_errors := gd.engine_get_print_error_messages(engine)
    gd.engine_set_print_error_messages(engine, false)
    opened := gd.webrtc_host(owner, "ws://127.0.0.1:0")
    gd.engine_set_print_error_messages(engine, print_errors)

    if opened || gd.webrtc_session_state(owner) != .Idle || gd.ref_counted_get_reference_count(mp) != refs_before {
        return false
    }

    if gd.performance_get_monitor(gd.singleton_performance(), .Object_Count) != objects_before {
        return false
    }

    if !gd.webrtc_host(owner, "ws://127.0.0.1:1") {
        return false
    }

    gd.multiplayer_api_set_multiplayer_peer(mp, replacement)
    gd.webrtc_close(owner)
    current := gd.multiplayer_api_get_multiplayer_peer(mp)
    preserved := current == replacement
    gd.release_ref(current)
    gd.multiplayer_api_set_multiplayer_peer(mp, before_peer)

    if !preserved {
        return false
    }

    // Changing the node's assigned API must not change which API close releases.
    tree := gd.get_tree(owner)
    path := gd.node_get_path(owner)
    defer gd.free_node_path(path)
    reassigned := gd.new_scene_multiplayer()
    gd.ref_counted_init_ref(reassigned)
    defer gd.release_ref(reassigned)
    gd.multiplayer_api_set_multiplayer_peer(reassigned, replacement)

    if !gd.webrtc_host(owner, "ws://127.0.0.1:1") {
        return false
    }

    gd.scene_tree_set_multiplayer(tree, reassigned, path)
    gd.webrtc_close(owner)
    gd.scene_tree_set_multiplayer(tree, nil, path)
    current = gd.multiplayer_api_get_multiplayer_peer(reassigned)
    preserved = current == replacement
    gd.release_ref(current)
    gd.multiplayer_api_set_multiplayer_peer(reassigned, nil)

    if !preserved || gd.ref_counted_get_reference_count(mp) != refs_before {
        return false
    }

    // A refused connection can still be closed and its owner slot reused.
    if !gd.webrtc_host(owner, "ws://127.0.0.1:1") {
        return false
    }

    deadline := gd.time_get_ticks_msec(gd.singleton_time()) + 1000

    for gd.webrtc_session_state(owner) != .Failed && gd.time_get_ticks_msec(gd.singleton_time()) < deadline {
        gd.webrtc_poll(owner)
    }

    failed := gd.webrtc_session_state(owner) == .Failed
    gd.webrtc_close(owner)
    gd.webrtc_close(owner)
    gd.print_str(
        fmt.tprintf(
            "GODOT_WEBRTC_LIFETIMES failed=%v multiplayer_growth=%d",
            failed,
            gd.ref_counted_get_reference_count(mp) - refs_before,
        ),
    )
    return failed && gd.ref_counted_get_reference_count(mp) == refs_before
}
