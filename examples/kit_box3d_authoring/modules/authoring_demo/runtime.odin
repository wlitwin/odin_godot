package kit_authoring_demo

import base "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:strings"
import gd "godot:godot"
import b "godot:box3d"
import a "godot:box3d/authoring"
import ga "godot:box3d/godot/authoring"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"
import bd "godot:box3d/diagnostics"
import p "godot:kit/physics"
import k "godot:kit/sim"
import n "godot:kit/net"
import s "godot:kit/session"
import ng "godot:kit/netgd"

PROFILE :: 0x4155544844454d31

Failure :: struct {
    site:   string,
    status: k.World_Error,
}

Cleanup :: struct {
    native, wrapper, meter:      u64,
    owners:                      i64,
    owners_before, owners_after: u32,
    owners_observed, observed:   bool,
}

Result :: struct {
    role:                                         string,
    ok:                                           bool,
    target, head, confirmed, final_tick, sampled: u64,
    content_hash:                                 bd.Digest,
    errors:                                       [8]Failure,
    error_count:                                  int,
    cleanup:                                      Cleanup,
}

Demo :: struct {
    sdk:                                                                                                                                                                                              p.SDK_Context,
    allocator:                                                                                                                                                                                        mem.Allocator,
    owners:                                                                                                                                                                                           [5]p.SDK_User_Owner,
    wire_owner:                                                                                                                                                                                       bg.Owner,
    node:                                                                                                                                                                                             gd.Node,
    wire:                                                                                                                                                                                             ng.Session_Wire,
    ses:                                                                                                                                                                                              s.Session,
    lane:                                                                                                                                                                                             k.Lane,
    physics:                                                                                                                                                                                          p.Instance(
        Side,
    ),
    network:                                                                                                                                                                                          p.Network(
        Side,
    ),
    controls:                                                                                                                                                                                         p.Typed_Codec(
        Control,
    ),
    proxy_codec:                                                                                                                                                                                      p.Typed_Codec(
        Proxy,
    ),
    descriptor:                                                                                                                                                                                       n.Entity_Desc,
    baked:                                                                                                                                                                                            a.Baked_Scene,
    built:                                                                                                                                                                                            a.Built_Scene,
    body_names:                                                                                                                                                                                       [35]string,
    body_count:                                                                                                                                                                                       int,
    proxies:                                                                                                                                                                                          [35]Proxy,
    host,
    scripted,
    failed,
    finished,
    closing,
    wire_ready,
    lane_ready,
    model_ready,
    ready_sent,
    ready_pending,
    welcome_sent,
    welcome_ack,
    baseline_ready,
    started,
    lead_applied,
    exported,
    final_ack: bool,
    target,
    baseline,
    scope,
    wait_fresh,
    sampled,
    accepted_through,
    submitted,
    held,
    authority,
    unavailable,
    pulse_rows:                                                                              u64,
    players:                                                                                                                                                                                          [2]n.Player_Id,
    seat:                                                                                                                                                                                             u16,
    peer:                                                                                                                                                                                             s.Peer_Id,
    input:                                                                                                                                                                                            Control,
    pulse_pending:                                                                                                                                                                                    bool,
    content_hash,
    rules:                                                                                                                                                                              bd.Digest,
    finish_after:                                                                                                                                                                                     f64,
    output:                                                                                                                                                                                           string,
    errors:                                                                                                                                                                                           [8]Failure,
    error_count:                                                                                                                                                                                      int,
    owners_before:                                                                                                                                                                                    u32,
    owners_before_observed:                                                                                                                                                                           bool,
    telemetry:                                                                                                                                                                                        Sample_Telemetry,
}

role :: proc(rt: ^Demo) -> string {
    return rt.host ? "host" : "client"
}

hex :: proc(digest: bd.Digest) -> string {
    bytes := make([]u8, 64, context.temp_allocator)
    digits := "0123456789abcdef"

    for byte, i in digest {
        bytes[i * 2] = digits[byte >> 4]
        bytes[i * 2 + 1] = digits[byte & 15]
    }

    return string(bytes)
}

fail :: proc(rt: ^Demo, site: string, status: k.World_Error) {
    if !rt.failed && rt.error_count < len(rt.errors) {
        rt.errors[rt.error_count] = {site, status}
        rt.error_count += 1
    }

    rt.failed = true
}

bind :: proc(rt: ^Demo, index: int, user: rawptr, size: u64) -> bool {
    owner, error := p.sdk_user_owner_create(rt.sdk.memory, rt, u64(size_of(rt^)), user, size)

    if error != .Ok {
        fail(rt, "sdk_user_owner_create", error)
        return false
    }

    rt.owners[index] = owner
    return true
}

owner_snapshot :: proc() -> (u32, bool) {
    contract, status := b.domain_contract_get()

    if status != .Ok {
        return 0, false
    }

    ledger, ls := b.host_ledger_get(contract.cookie)
    return ledger.owner_count, ls == .Ok
}

demo_create :: proc(node: gd.Node) -> ^Demo {
    owners_before, owners_observed := owner_snapshot() // BEFORE any Sample Context/user.
    sdk, error := p.sdk_context_create()

    if error != .Ok {
        return nil
    }

    allocator := bm.allocator(sdk.memory)
    context.allocator = allocator
    rt := new(Demo, allocator)
    rt.sdk = sdk
    rt.allocator = allocator
    rt.node = node
    rt.owners_before = owners_before
    rt.owners_before_observed = owners_observed
    selected := gd.env_string("BOX3D_SAMPLE_ROLE", "host")

    if selected != "host" && selected != "client" {
        fail(rt, "BOX3D_SAMPLE_ROLE", .Unsupported)
        return rt
    }

    rt.host = selected == "host"
    rt.scripted = gd.env_int("BOX3D_SAMPLE_SCRIPTED", 0) == 1
    ticks := gd.env_int("BOX3D_SAMPLE_TICKS", rt.scripted ? 120 : 0)
    port := gd.env_int("BOX3D_SAMPLE_PORT", 43125)
    target_limit := rt.scripted ? 216000 : 3600

    if ticks < 0 || ticks > target_limit || (rt.scripted && ticks < 12) || port < 1 || port > 65535 {
        fail(rt, "BOX3D_SAMPLE_TICKS/PORT", .Invalid)
        return rt
    }

    rt.target = u64(ticks)
    rt.output = gd.env_string("BOX3D_SAMPLE_OUTPUT", "", allocator)

    if rt.scripted && (len(rt.output) == 0 || rt.output[0] != '/') {
        fail(rt, "BOX3D_SAMPLE_OUTPUT_absolute", .Invalid)
        return rt
    }

    if !bind(rt, 0, rt, u64(size_of(rt^))) ||
       !bind(rt, 1, &rt.physics, u64(size_of(rt.physics))) ||
       !bind(rt, 2, &rt.network, u64(size_of(rt.network))) ||
       !bind(rt, 3, &rt.controls, u64(size_of(rt.controls))) ||
       !bind(rt, 4, &rt.proxy_codec, u64(size_of(rt.proxy_codec))) {
        return rt
    }

    source := gd.get_node(node, "AuthoredWorld")
    scene, diagnostic := ga.extract(source, allocator)
    defer ga.diagnostic_destroy(&diagnostic)

    if diagnostic.error != .None {
        fail(rt, "AuthoredWorld.extract", .Invalid)
        return rt
    }

    rt.baked = scene
    rt.content_hash = scene.content_hash
    built, error_bake := a.build(&rt.baked, PROFILE)
    rt.built = built

    if error_bake.error != .None {
        fail(rt, "AuthoredWorld.build", .Step_Failed)
        return rt
    }

    rt.body_count = len(rt.built.bodies)

    if rt.body_count != 4 || len(rt.built.joints) != 1 {
        fail(rt, "shared_world.body_joint_count", .Incompatible)
        return rt
    }

    for body, i in rt.baked.data.bodies {
        rt.body_names[i] = strings.clone(body.stable_key, allocator)
    }

    rules, re := bd.hash_descriptors(
        "kit-authored-sample-v1",
        []bd.Descriptor {
            {"callbacks", transmute([]u8)#load("model.odin")},
            {"content", rt.content_hash[:]},
            {"missing_control", transmute([]u8)string("Neutral; pulse_not_repeated; wire5bytes")},
        },
    )

    if re != .None {
        fail(rt, "rules.identity", .Invalid)
        return rt
    }

    rt.rules = rules
    lease, ls := bm.block_lease(sdk.memory, rt, u64(size_of(rt^)), &rt.wire, u64(size_of(rt.wire)))

    if ls != bg.OK {
        fail(rt, "wire.data_lease", .Invalid)
        return rt
    }

    rt.wire_owner, error = p.sdk_owner_create(true, lease)

    if error != .Ok {
        fail(rt, "wire.owner", error)
        return rt
    }

    if ng.wire_configure(
           &rt.wire,
           {
               allocator = allocator,
               owner = rt.wire_owner,
               user_data = &rt.wire,
               allocator_owner = sdk.detached,
               allocator_data = allocator.data,
           },
       ) !=
       .Ok {
        fail(rt, "wire.configure", .Invalid)
        return rt
    }

    rt.wire_ready = true
    rt.ses.allocator = allocator
    s.session_configure(&rt.ses, {tick_hz = 60, max_players = 2})
    mp := gd.node_get_multiplayer(node)
    gd.scene_multiplayer_set_server_relay_enabled(cast(gd.Scene_Multiplayer)mp, false)
    gd.release_ref(mp)
    ng.wire_attach(&rt.wire, node, &rt.ses, 0)

    if ng.wire_listen(&rt.wire, "on_packet", "on_peer_left", "on_net_up", "on_net_down") != .Ok {
        fail(rt, "wire.listen", .Invalid)
        return rt
    }

    s.session_app_route(&rt.ses, 4, rt, control_packet)
    opened :=
        rt.host ? ng.transport_host(&rt.wire, &ng.ENET, {port = port, max_peers = 2}, "Authored Kit", token = 101) : ng.transport_join(&rt.wire, &ng.ENET, {addr = "127.0.0.1", port = port}, "Authored Kit client", 202)

    if !opened {
        fail(rt, "transport.open", .Invalid)
    }

    return rt
}

s_roster :: proc(rt: ^Demo) -> bool {
    players := s.session_roster(&rt.ses, rt.allocator)
    defer delete(players, rt.allocator)
    count := 0

    for player in players {
        if player.connected && !player.spectator && !player.dedicated {
            if count == 2 {
                fail(rt, "roster.more_than_two", .Capacity)
                return false
            }

            rt.players[count] = player.id
            count += 1

            if player.id != rt.ses.me {
                rt.peer = player.peer
            }
        }
    }

    if count != 2 {
        return false
    }

    if rt.players[0] > rt.players[1] {
        rt.players[0], rt.players[1] = rt.players[1], rt.players[0]
    }

    for player, i in rt.players {
        if player == rt.ses.me {
            rt.seat = u16(i + 1)
        }
    }

    return rt.seat != 0
}

send_signature :: proc(rt: ^Demo, kind: u8, tick: u64) {
    signature, status := k.lane_world_confirmed_signature(&rt.lane, tick)

    if status != .Ok {
        fail(rt, "confirmed.signature", status)
        return
    }

    bytes: [bd.SIGNATURE_BYTES]u8
    _, error := bd.signature_encode(signature, bytes[:])

    if error != .None {
        fail(rt, "signature.encode", .Invalid)
        return
    }

    w := s.session_app_begin(&rt.ses, 4)
    n.write_u8(w, kind)
    n.write_bytes(w, bytes[:])
    s.session_app_flush(&rt.ses, s.HOST_PEER, .Reliable)
}

control_packet :: proc(user: rawptr, from: n.Player_Id, peer: s.Peer_Id, r: ^n.Reader) {
    rt := cast(^Demo)user

    if rt.closing {
        return
    }

    kind := n.read_u8(r)

    if !rt.host {
        if !rt.model_ready {
            return
        }

        if peer == s.HOST_PEER && kind == 4 {
            version := n.read_u32(r)
            epoch := n.read_u64(r)

            if version == 1 &&
               epoch == k.lane_world_epoch(&rt.lane) &&
               !r.err &&
               len(n.reader_remaining(r)) == 0 &&
               rt.baseline_ready {
                rt.started = true
            }
        }

        return
    }

    player, found := s.session_player(&rt.ses, from)

    if !found || !player.connected || player.peer != peer || from == rt.ses.me {
        return
    }

    if kind == 1 {
        bytes := n.read_bytes_limited(r, 32)
        target := n.read_u64(r)

        if r.err || len(bytes) != 32 || len(n.reader_remaining(r)) != 0 || target != rt.target {
            return
        }

        for byte, i in bytes {
            if byte != rt.content_hash[i] {
                fail(rt, "peer.content_identity", .Incompatible)
                return
            }
        }

        rt.ready_pending = true
        return
    }

    if kind == 2 || kind == 3 {
        if !rt.model_ready {
            return
        }

        bytes := n.read_bytes_limited(r, bd.SIGNATURE_BYTES)

        if r.err || len(bytes) != bd.SIGNATURE_BYTES || len(n.reader_remaining(r)) != 0 {
            return
        }

        signature, se := bd.signature_decode(bytes)

        if se != .None {
            return
        }

        if kind == 2 && signature.tick != rt.target {
            return
        }

        local, status := k.lane_world_confirmed_signature(&rt.lane, signature.tick)

        if status != .Ok || bd.compare(local, signature) != .Match {
            return
        }

        if kind == 2 {
            first_ack := !rt.final_ack
            rt.final_ack = true

            if first_ack {
                telemetry_final_ack(rt, signature, u64(from), u64(peer))
            }
        } else if rt.welcome_sent && !rt.started {
            rt.welcome_ack = true
            rt.started = true
            w := s.session_app_begin(&rt.ses, 4)
            n.write_u8(w, 4)
            n.write_u32(w, 1)
            n.write_u64(w, k.lane_world_epoch(&rt.lane))
            s.session_app_flush(&rt.ses, peer, .Reliable)
        }
    }
}

ready_log :: proc(rt: ^Demo) {
    images := native_image_count()

    if images != 1 {
        fail(rt, "native.image_count", .Incompatible)
        return
    }

    current, current_observed := owner_snapshot()
    row := struct {
        framework, role, content_sha256, mode: string,
        native_images:                         int,
        owners_before, owners_after:           u32,
        owners_observed:                       bool,
        owners_scope:                          string,
    } {
        "kit",
        role(rt),
        hex(rt.content_hash),
        "host_client",
        images,
        rt.owners_before,
        current,
        rt.owners_before_observed && current_observed,
        "pre_sample_context_baseline_and_ready_raw",
    }
    bytes, error := json.marshal(row)

    if error != nil {
        fail(rt, "ready.json", .Allocation_Failed)
        return
    }

    defer delete(bytes, rt.allocator)
    fmt.printf("SAMPLE_READY %s\n", string(bytes))
}

accepted_summary :: proc(rt: ^Demo) {
    confirmed := k.lane_world_confirmed(&rt.lane)

    for rt.accepted_through < confirmed {
        rt.accepted_through += 1

        for player in rt.players {
            bytes, origin, _, status := k.lane_world_accepted_input(&rt.lane, rt.accepted_through, player, 0)

            if status != .Ok || len(bytes) != size_of(Control) {
                rt.unavailable += 1
                continue
            }

            #partial switch origin {
            case .Submitted:
                rt.submitted += 1
            case .Held:
                rt.held += 1
            case .Authority:
                rt.authority += 1
            case:
                rt.unavailable += 1
            }

            value: Control
            copy((cast([^]u8)&value)[:size_of(value)], bytes)

            if value.pulse {
                rt.pulse_rows += 1
            }
        }
    }
}

pending_ingress :: proc(rt: ^Demo) -> bool {
    network := rt.lane.world.network
    return network.queue_count != 0 || network.completed_count != 0 || network.applying
}

demo_frame :: proc(rt: ^Demo, delta: f64) {
    rt.telemetry.frames += 1
    defer telemetry_frame_end(rt, delta)
    context.allocator = rt.allocator

    if rt.failed || rt.closing {
        return
    }

    if math.is_nan(delta) || math.is_inf(delta) || delta < 0 {
        fail(rt, "frame.delta", .Invalid)
        return
    }

    now := n.now_s()
    ng.transport_service(&rt.wire)
    ng.wire_pump(&rt.wire, now)
    _, _ = s.session_tick(&rt.ses, delta, now)

    for {
        event, ok := s.session_poll(&rt.ses)

        if !ok {
            break
        }

        #partial switch payload in event {
        case s.Ev_Host_Left:
            if rt.model_ready {
                _ = k.lane_world_protocol_peer_disconnected(&rt.lane, s.HOST_PEER)
            }

            if !rt.exported {
                fail(rt, "session.host_left", .Invalid)
            }
        case:
        }
    }

    if rt.failed {
        return
    }

    if ng.wire_status(&rt.wire).error != .Ok {
        fail(rt, "wire.status", .Invalid)
        return
    }

    if !rt.model_ready {
        if !model_create(rt) {
            return
        }

        if rt.host {
            ready_log(rt)
        }
    }

    if rt.host && rt.ready_pending && !rt.welcome_sent {
        if status := k.lane_world_send_checkpoint(&rt.lane, rt.peer, .Welcome); status != .Ok {
            fail(rt, "send_welcome", status)
            return
        }

        rt.welcome_sent = true
    }

    if !rt.host && !rt.ready_sent {
        w := s.session_app_begin(&rt.ses, 4)
        n.write_u8(w, 1)
        n.write_bytes(w, rt.content_hash[:])
        n.write_u64(w, rt.target)
        s.session_app_flush(&rt.ses, s.HOST_PEER, .Reliable)
        rt.ready_sent = true
    }

    _ = k.lane_frame(&rt.lane, 0) // Existing single public ingress before caller time.

    if k.lane_world_needs_resync(&rt.lane) {
        if status := k.lane_world_request_reset(&rt.lane); status != .Ok {
            fail(rt, "hold.request_reset", status)
        }

        return
    }

    if !k.lane_world_network_status(&rt.lane).ready {
        return
    }

    protocol := k.lane_world_protocol_status(&rt.lane)

    if !rt.host {
        if protocol.bootstrap_sequence != rt.scope {
            signature, se := k.lane_world_confirmed_signature(&rt.lane, rt.lane.world.network.last_signature.tick)

            if se != .Ok || bd.compare(signature, rt.lane.world.network.last_signature) != .Match {
                return
            }

            if rt.scope != 0 {
                rt.wait_fresh = signature.tick
            }

            rt.scope = protocol.bootstrap_sequence
            rt.lead_applied = false
            telemetry_validated_scope(rt, signature)
        }

        if !rt.baseline_ready {
            rt.baseline = rt.lane.ticker.tick
            rt.accepted_through = rt.baseline
            rt.baseline_ready = true
            send_signature(rt, 3, rt.baseline)
            ready_log(rt)
        }
    }

    if !rt.started {
        return
    }

    if !rt.host && !rt.lead_applied {
        if rt.wait_fresh > 0 &&
           (protocol.matched_signature_tick <= rt.wait_fresh ||
                   protocol.accepted_through < protocol.matched_signature_tick ||
                   protocol.pending_signature_tick != 0) {
            return
        }

        head, cf := rt.lane.ticker.tick, k.lane_world_confirmed(&rt.lane)

        if head < cf {
            fail(rt, "bootstrap.head_confirmed", .Invalid)
            return
        }

        room := 8 - min(u64(8), head - cf)
        remaining := rt.target == 0 ? u64(8) : rt.target - min(rt.target, head)
        dt, scale, acc := rt.lane.ticker.dt, rt.lane.ticker.scale, rt.lane.ticker.acc

        if pending_ingress(rt) ||
           room < 4 ||
           remaining < 4 ||
           acc + (4.0 / 60) * scale > f64(min(room, remaining)) * dt {
            return
        }

        before_seq := rt.lane.world.network.received_sequence
        returned := k.lane_frame(&rt.lane, 4.0 / 60)
        receipt := rt.lane.ticker.acc - acc + f64(returned) * dt

        if rt.lane.world.network.received_sequence != before_seq ||
           rt.lane.ticker.scale != scale ||
           rt.lane.ticker.tick - head != u64(returned) {
            fail(rt, "bootstrap.boundary", .Invalid)
            return
        }

        if abs(receipt - (4.0 / 60) * scale) <= 1e-12 {
            rt.lead_applied = true
            rt.wait_fresh = 0
        } else if returned != 0 || receipt != 0 {
            fail(rt, "bootstrap.receipt", .Invalid)
            return
        } else {
            return
        }
    }

    head := rt.lane.ticker.tick
    cf := k.lane_world_confirmed(&rt.lane)
    dt := rt.lane.ticker.dt
    scale := rt.lane.ticker.scale

    if dt != 1.0 / 60 || math.is_nan(scale) || math.is_inf(scale) || scale < 0.98 || scale > 1.02 || head < cf {
        fail(rt, "caller.domain", .Unsupported)
        return
    }

    room := u64(2)

    if !rt.host {
        room = min(room, 8 - min(u64(8), head - cf))
    }

    if rt.target > 0 {
        room = min(room, rt.target - min(rt.target, head))
    }

    offered := min(min(delta, 2 * dt), max(f64(0), f64(room) * dt - rt.lane.ticker.acc) / scale)

    if !rt.host && pending_ingress(rt) {
        offered = 0
    }

    _ = k.lane_frame(&rt.lane, offered)

    if k.lane_world_needs_resync(&rt.lane) {
        return
    }

    if status := k.lane_world_status(&rt.lane); status != .Ok {
        fail(rt, "lane_frame", status)
        return
    }

    accepted_summary(rt)

    if rt.target > 0 && k.lane_world_confirmed(&rt.lane) >= rt.target {
        if !rt.exported {
            if !write_final(rt) {
                return
            }

            rt.exported = true
        }

        if !rt.host {
            send_signature(rt, 2, rt.target)

            if rt.finish_after == 0 {
                rt.finish_after = now + 0.25
            }
        } else if rt.final_ack && rt.finish_after == 0 {
            rt.finish_after = now + 0.6
        }

        if rt.finish_after > 0 && now >= rt.finish_after {
            rt.finished = true
        }
    }
}

Part_File :: struct {
    file, sha256: string,
}

write_final :: proc(rt: ^Demo) -> bool {
    frame: k.World_Diagnostic_Frame
    status := k.lane_world_diagnostic_frame(&rt.lane, rt.target, &frame)

    if status != .Ok {
        fail(rt, "final.complete_view", status)
        return false
    }

    defer k.world_diagnostic_frame_destroy(&frame)

    if rt.output == "" {
        return !rt.scripted
    }

    if !os.is_dir(rt.output) {
        make_error := os.make_directory_all(rt.output)

        if make_error != nil && !os.is_dir(rt.output) {
            fail(rt, "output.directory", .Invalid)
            return false
        }
    }

    if !os.is_dir(rt.output) {
        fail(rt, "output.directory", .Invalid)
        return false
    }

    parts: [bd.Part]Part_File

    for part in bd.Part {
        name := fmt.aprintf("%v.bin", part)
        path := fmt.aprintf("%s/%s", rt.output, name)
        written := os.write_entire_file(path, frame.view.parts[part])
        delete(path, rt.allocator)

        if written != nil {
            delete(name, rt.allocator)
            fail(rt, "output.part", .Invalid)
            return false
        }

        parts[part] = {name, hex(bd.hash_bytes(frame.view.parts[part]))}
    }

    defer for part in parts {
        delete(part.file, rt.allocator)
    }

    signature: [bd.SIGNATURE_BYTES]u8
    _, se := bd.signature_encode(frame.signature, signature[:])

    if se != .None {
        fail(rt, "output.signature", .Invalid)
        return false
    }

    sigpath := fmt.aprintf("%s/Signature.bin", rt.output)
    sigerror := os.write_entire_file(sigpath, signature[:])
    delete(sigpath, rt.allocator)

    if sigerror != nil {
        fail(rt, "output.signature_file", .Invalid)
        return false
    }

    metadata := struct {
        epoch, tick:    u64,
        content_sha256: string,
        signature:      Part_File,
        parts:          struct {
            Solver, Game, Side, Observations, Occurrences: Part_File,
        },
    } {
        frame.view.epoch,
        frame.view.tick,
        hex(rt.content_hash),
        {"Signature.bin", hex(bd.hash_bytes(signature[:]))},
        {parts[.Solver], parts[.Game], parts[.Side], parts[.Observations], parts[.Occurrences]},
    }
    bytes, je := json.marshal(metadata)

    if je != nil {
        fail(rt, "output.metadata_json", .Allocation_Failed)
        return false
    }

    defer delete(bytes, rt.allocator)
    path := fmt.aprintf("%s/final-frame.json", rt.output)
    error := os.write_entire_file(path, bytes)
    delete(path, rt.allocator)

    if error != nil {
        fail(rt, "output.metadata_file", .Invalid)
        return false
    }

    // Evidence only: plain typed values at the actual target. Unavailable output
    // omits counts; no pointer/any serialization or invented zero evidence.
    published, side_available := p.read(&rt.physics)
    at_target := side_available && published.tick == rt.target && frame.view.tick == rt.target

    if at_target {
        input_row := struct {
            framework, role:                                           string,
            epoch, tick:                                               u64,
            available:                                                 bool,
            published_tick:                                            u64,
            nonzero_by_seat, pulse_by_seat:                            [2]u64,
            submitted, held, authority, unavailable, accepted_through: u64,
        } {
            "kit",
            role(rt),
            frame.view.epoch,
            frame.view.tick,
            true,
            published.tick,
            published.controls_applied,
            published.pulses,
            rt.submitted,
            rt.held,
            rt.authority,
            rt.unavailable,
            rt.accepted_through,
        }
        input_bytes, input_error := json.marshal(input_row)

        if input_error != nil {
            fmt.println("SAMPLE_INPUTS {\"framework\":\"kit\",\"available\":false,\"error\":\"typed.json.encoding\"}")
        } else {
            fmt.printf("SAMPLE_INPUTS %s\n", string(input_bytes))
            delete(input_bytes, rt.allocator)
        }
    } else {
        input_row := struct {
            framework, role: string,
            epoch, tick:     u64,
            available:       bool,
            error:           string,
        }{"kit", role(rt), frame.view.epoch, frame.view.tick, false, "published.Side unavailable or wrong target"}
        input_bytes, input_error := json.marshal(input_row)

        if input_error != nil {
            fmt.println(
                "SAMPLE_INPUTS {\"framework\":\"kit\",\"available\":false,\"error\":\"unavailable.json.encoding\"}",
            )
        } else {
            fmt.printf("SAMPLE_INPUTS %s\n", string(input_bytes))
            delete(input_bytes, rt.allocator)
        }
    }

    return true
}

demo_close :: proc(rt: ^Demo, result: ^Result) -> bool {
    context = base.default_context()

    if rt == nil {
        return true
    }

    context.allocator = rt.allocator
    rt.closing = true
    result^ = {
        role         = role(rt),
        ok           = !rt.failed && (!rt.scripted || (rt.exported && (rt.host ? rt.final_ack : true))),
        target       = rt.target,
        content_hash = rt.content_hash,
        sampled      = rt.sampled,
        errors       = rt.errors,
        error_count  = rt.error_count,
    }

    if rt.model_ready {
        result.head = rt.lane.ticker.tick
        result.confirmed = k.lane_world_confirmed(&rt.lane)
    }

    if rt.exported {
        result.final_tick = rt.target
    }

    if rt.wire_ready {
        if ng.wire_detach(&rt.wire) != .Ok {
            result.ok = false
            return false
        }

        rt.wire_ready = false
    }

    if rt.network.instance != nil {
        if p.network_destroy(&rt.network) != .Ok {
            result.ok = false
            return false
        }
    }

    if p.codec_destroy(&rt.controls) != .Ok ||
       p.codec_destroy(&rt.proxy_codec) != .Ok ||
       p.detach(&rt.physics) != .Ok {
        result.ok = false
        return false
    }

    if rt.lane_ready {
        k.lane_destroy(&rt.lane)
    }

    s.session_destroy(&rt.ses)

    if a.built_destroy(&rt.built) != .Ok {
        result.ok = false
        return false
    }

    a.destroy(&rt.baked)

    for name in rt.body_names[:rt.body_count] {
        delete(name, rt.allocator)
    }

    delete(rt.output, rt.allocator)
    sdk, allocator, owners, wire_owner := rt.sdk, rt.allocator, rt.owners, rt.wire_owner
    owners_before, baseline_observed := rt.owners_before, rt.owners_before_observed
    free(rt, allocator)
    success := true

    for &owner in owners {
        if p.sdk_user_owner_destroy(&owner) != .Ok {
            success = false
        }
    }

    if wire_owner.user != nil && wire_owner.drop(wire_owner.user) != bg.OK {
        success = false
    }

    if p.sdk_context_destroy(&sdk) != .Ok {
        success = false
    }

    context = base.default_context()
    engine, es := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    meter, ms := bm.category_stats(bg.CATEGORY_KIT_CORE)
    contract, cs := b.domain_contract_get()
    ledger, ls := b.host_ledger_get(contract.cookie)
    owner_observed := baseline_observed && cs == .Ok && ls == .Ok
    result.cleanup = {
        native          = engine.live_bytes,
        wrapper         = wrapper.live_bytes,
        meter           = meter.live_bytes,
        owners          = i64(ledger.owner_count) - i64(owners_before),
        owners_before   = owners_before,
        owners_after    = ledger.owner_count,
        owners_observed = owner_observed,
        observed        = es == .Ok && ws == .Ok && ms == bg.OK && owner_observed,
    }
    result.ok =
        result.ok &&
        success &&
        result.cleanup.observed &&
        result.cleanup.native == 0 &&
        result.cleanup.wrapper == 0 &&
        result.cleanup.meter == 0 &&
        result.cleanup.owners == 0
    // Runtime storage has been consumed. A later owner/ledger error is a failed
    // result, never permission for the Node to retry through a freed pointer.
    return true
}

print_result :: proc(result: Result) {
    result := result
    context = base.default_context()
    row := struct {
        framework, role:                     string,
        ok:                                  bool,
        target, head, confirmed, final_tick: u64,
        errors:                              []Failure,
        cleanup:                             Cleanup,
        content_sha256:                      string,
        sampled:                             u64,
    } {
        "kit",
        result.role,
        result.ok,
        result.target,
        result.head,
        result.confirmed,
        result.final_tick,
        result.errors[:result.error_count],
        result.cleanup,
        hex(result.content_hash),
        result.sampled,
    }
    bytes, error := json.marshal(row)

    if error != nil {
        fmt.println("SAMPLE_RESULT {\"framework\":\"kit\",\"ok\":false,\"errors\":[\"result.json\"]}")
        return
    }

    defer delete(bytes)
    fmt.printf("SAMPLE_RESULT %s\n", string(bytes))
}
