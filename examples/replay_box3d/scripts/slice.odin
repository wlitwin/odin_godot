//gd:extends Node3D
//gd:class ReplayBox3d
package replay_box3d
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import gd "godot:godot"
import "godot:gdext"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import ph "godot:replay/physics"
import rt "godot:runtime"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import common "godot:examples/box3d_common"
import adapter "../shared/adapter"

Runtime :: struct {
    session:                                 rgd.Session(common.Game, common.Control, common.Action, common.Event, 2),
    codec:                                   adapter.Codec,
    catalog:                                 b.Recovery_Catalog,
    image_owner, codec_owner, session_owner: ph.Owner_Context,
}

Terminal_Obligation :: struct {
    token:             net.Token,
    peer:              tr.Peer_Id,
    epoch, generation: u64,
    seat:              u16,
    spectator, final:  bool,
}

ReplayBox3d :: struct {
    owner:                                                                           gd.Node3d,
    status:                                                                          gd.Label `gd:"onready=HUD/Status"`,
    scope:                                                                           ^meter.Context,
    state:                                                                           ^Runtime,
    hosting, ready, announced, failed, finished, scripted, go, initial_cache_logged: bool,
    expected_observers:                                                              u32,
    required_ticks, end_tick:                                                        u64,
    role_ready, peer_done, peer_final:                                               [16]bool,
    role_generation:                                                                 [16]u64,
    role_tokens:                                                                     [16]net.Token,
    terminal_obligations:                                                            [16]Terminal_Obligation,
    terminal_count:                                                                  int,
    terminal_closing:                                                                bool,
    initial:                                                                         u32,
    timeout_frames:                                                                  u64,
    keys:                                                                            [6]bool,
    target, baseline, last_frame, last_audit, settle, wall_frames, fx:               u64,
    role, actor:                                                                     string,
    output:                                                                          string,
    sent:                                                                            [6]bool,
    planned, planned_original:                                                       [6]u64,
    rebased:                                                                         [6]bool,
    intent_recovery_serial, role_ready_serial:                                       u64,
    final_signature:                                                                 bd.Signature,
    have_final, got_close:                                                           bool,
    tail_frames:                                                                     u64,
    meshes:                                                                          [33]gd.Mesh_Instance3d,
    presentation:                                                                    Slice_Presentation,
    rejoin:                                                                          Rejoin_Sample,
    impairment:                                                                      Scene_Impairment,
}

replay_box3d_ready :: proc(self: ^ReplayBox3d) {
    role := gd.env_string("B3_ROLE", "")
    self.role = "host"
    self.scripted = gd.env_int("B3_SCRIPTED", len(role) == 0 ? 0 : 1) != 0

    switch role {
    case "client":
        self.role = "client"
    case "server", "dedicated":
        self.role = "server"
    case "observer":
        self.role = "observer"
    }

    self.actor = self.role
    actor := gd.env_string("B3_ACTOR", "")

    switch actor {
    case "client1":
        self.actor = "client1"
    case "client2":
        self.actor = "client2"
    }

    self.hosting = self.role == "host" || self.role == "server"
    self.target = u64(gd.env_int("B3_TICKS", self.scripted ? 240 : 0))
    self.required_ticks = self.target
    self.end_tick = u64(gd.env_int("B3_END_TICK", 0))
    self.expected_observers = u32(gd.env_int("B3_EXPECT_OBSERVERS", 0))
    self.timeout_frames = u64(gd.env_int("B3_DEBUG_TIMEOUT_FRAMES", self.scripted ? 3600 : 0))
    self.planned = SLICE_INITIAL_PHASES
    self.planned_original = self.planned
    initial := u32(gd.env_int("B3_BODIES", 4))
    seed := u32(gd.env_int("B3_SEED", 1))
    self.initial = initial

    if !slice_rejoin_options(self) {
        slice_fail(self, "rejoin sample config")
        return
    }

    if !slice_impairment_parse(self) {
        slice_impairment_reject(self, .Invalid)
        return
    }

    options := rgd.SESSION_OPTIONS
    options.role = self.hosting ? .Host : .Client

    if self.role == "server" {
        options.role = .Server
    }

    if self.role == "observer" {
        options.role = .Observer
    }

    options.port = u16(gd.env_int("B3_PORT", 49642))
    options.address = fmt.ctprintf("%s", gd.env_string("B3_ADDRESS", "127.0.0.1"))
    options.network = net.physics_config_default()
    options.network.snapshot_every = 1
    options.replication.transport.egress_per_second = 8 * 1024 * 1024
    options.replication.transport.egress_per_pump = 1024 * 1024
    options.replication.transport.burst_bytes = 1024 * 1024
    options.replication.application_handles = proc(_: rawptr, _: tr.Peer_Id, _: tr.Channel, bytes: []u8) -> bool {
        return len(bytes) == 512 && string(bytes[:8]) == "RB3TAIL1"
    }
    token_text := gd.env_string("B3_TOKEN", self.hosting ? "101" : (self.role == "observer" ? "303" : "202"))
    token_value, token_ok := strconv.parse_u64(token_text)

    if !token_ok || token_value == 0 {
        slice_fail(self, "token config")
        return
    }

    for i in 0 ..< 8 {
        options.token[i] = u8(token_value >> uint(i * 8))
    }

    impaired_options, impairment_error := rgd.physics_impairment_options(options, self.impairment.request)

    if impairment_error != .None {
        slice_impairment_reject(self, impairment_error)
        return
    }

    options = impaired_options
    service := bg.service_get()
    scope, status := meter.create(service, bg.CATEGORY_REPLAY_PROVIDER)

    if status != bg.OK {
        slice_fail(self, "meter")
        return
    }

    self.scope = scope
    alloc := meter.allocator(scope)
    self.output = gd.env_string("B3_OUTPUT", "", allocator = alloc)
    state := new(Runtime, alloc)
    self.state = state
    image_owner, error := ph.owner_context_create(
        meter.data_lease(scope),
        allocator_data = alloc.data,
        require_live_instance = false,
    )

    if error != .None {
        slice_fail(self, "allocator owner")
        return
    }

    state.image_owner = image_owner
    lease, ls := meter.block_lease(scope, state, size_of(Runtime), &state.codec, size_of(adapter.Codec))

    if ls != bg.OK {
        slice_fail(self, "codec lease")
        return
    }

    state.codec_owner, error = ph.owner_context_create(lease, user_data = &state.codec, require_live_instance = false)

    if error != .None {
        slice_fail(self, "codec owner")
        return
    }

    session_lease, sls := meter.block_lease(scope, state, size_of(Runtime), &state.session, size_of(state.session))

    if sls != bg.OK {
        slice_fail(self, "session lease")
        return
    }

    state.session_owner, error = ph.owner_context_create(
        session_lease,
        user_data = &state.session,
        require_live_instance = false,
    )

    if error != .None {
        slice_fail(self, "session owner")
        return
    }

    config := b.recovery_config_default()
    config.profile = common.PROFILE
    assets := common.assets()
    native_status: b.Status
    state.catalog, native_status = b.recovery_catalog_create(config, assets[:])

    if native_status != .Ok {
        slice_fail(self, "catalog")
        return
    }

    provider := adapter.config(&state.catalog, initial)
    codec_error := ph.network_codec_init(
        &state.codec,
        &state.catalog,
        provider,
        adapter.rules(initial, seed),
        allocator = alloc,
        ownership = image_owner,
        context_ownership = state.codec_owner,
    )

    if codec_error != .None {
        gd.print_str(fmt.tprintf("BOX3D_SLICE_ERROR codec=%v", codec_error))
        slice_fail(self, "codec init")
        return
    }

    ownership := rgd.Session_Ownership {
        allocator        = {image_owner.owner, alloc.data},
        container        = {state.session_owner.owner, &state.session},
        allocation_base  = state,
        allocation_bytes = size_of(Runtime),
    }
    model := adapter.model(&state.codec)
    model.step = observed_step
    model.action = observed_action
    result: net.Error

    if self.hosting {
        world, game, ws := common.world(initial, seed)

        if ws != .Ok {
            slice_fail(self, "world")
            return
        }

        checkpoint, ce := ph.checkpoint_make(
            r.Frame(common.Game){state = game},
            net.Net_Event(common.Event),
            world,
            provider,
            allocator = alloc,
            ownership = image_owner,
        )
        b.world_destroy(&world)

        if ce != .None {
            slice_fail(self, "checkpoint")
            return
        }

        result = rgd.session_open_complete(
            &state.session,
            &checkpoint,
            model,
            options,
            allocator = alloc,
            ownership = ownership,
        )
        r.complete_checkpoint_destroy(&checkpoint)
    } else {
        result = rgd.session_open(
            &state.session,
            r.Frame(common.Game){},
            model,
            options,
            allocator = alloc,
            ownership = ownership,
        )
    }

    if result != .None {
        gd.print_str(fmt.tprintf("BOX3D_SLICE_ERROR init=%v", result))
        slice_fail(self, "session open")
        return
    }

    self.ready = true
    slice_impairment_applied(self)
    slice_flow(self, "opened")

    if initial == 4 {
        camera := cast(gd.Node3d)gd.get_node(self.owner, "Camera")
        gd.node3d_set_position(camera, {3.5, 5, 6})
        gd.node3d_look_at(camera, {0, .5, 0}, {0, 1, 0}, false)
    }

    for index in 0 ..< 33 {
        node := gd.new_mesh_instance3d()
        name := gd.new_string_name(fmt.tprintf("Body%d", index))
        gd.node_set_name(cast(gd.Node)node, name)
        gd.free_string_name(name)
        group := gd.new_string_name("box3d_proxy")
        gd.node_add_to_group(cast(gd.Node)node, group, false)
        gd.free_string_name(group)
        gd.add_child(self.owner, node)
        gd.node3d_set_visible(cast(gd.Node3d)node, false)
        self.meshes[index] = node
    }

    gd.print_str(fmt.tprintf("BOX3D_SLICE_STAGE {{\"role\":\"%s\",\"stage\":\"session_open\"}}", self.actor))
}

slice_announce :: proc(self: ^ReplayBox3d, ready: bool) -> bool {
    s := &self.state.session

    if ready && !self.announced {
        self.announced = true
        self.baseline = self.hosting ? s.server.timeline.head : s.client.baseline

        if self.target != 0 {
            self.target = self.end_tick != 0 ? self.end_tick : self.target + self.baseline
        }

        if self.target != 0 && self.baseline + self.required_ticks > self.target {
            slice_fail(self, "baseline target bound")
            return false
        }

        if !slice_initial_identity(self) {
            slice_fail(self, "admitted rejoin identity")
            return false
        }

        if !slice_initial_intents(self) {
            slice_fail(self, "initial intent baseline overflow")
            return false
        }

        slice_ready_log(self)
    }

    return true
}

replay_box3d_process :: proc(self: ^ReplayBox3d, dt: f64) {
    if !self.ready || self.finished {
        return
    }

    self.wall_frames += 1

    if self.timeout_frames != 0 && self.wall_frames > self.timeout_frames {
        slice_fail(self, "timeout")
        return
    }

    s := &self.state.session

    if self.wall_frames % 60 == 0 {
        slice_flow(self, "running")
    }

    if self.wall_frames % 60 == 0 {
        remote_found := false
        remote_seat: u16
        remote_input_newest: u64

        if self.hosting {
            for peer in s.server.peers {
                if peer.phase == .Running && !peer.local && !peer.spectator {
                    remote_found = true
                    remote_seat = peer.seat
                    remote_input_newest = peer.input_newest
                    break
                }
            }
        }

        gd.print_str(
            fmt.tprintf(
                "BOX3D_SLICE_WAIT role=%s phase=%v peers=%d head=%d rx=%d tx=%d rejected=%d client_fields_available=%v client_confirmed=%d authority_tick_seen=%d lead_ticks=%d clock_scale_bits=%d stalls=%d snapshot_catchups=%d timing_samples=%d timing_rejected=%d lead_updates=%d control_consumed_last=%v remote_found=%v remote_seat=%d remote_input_newest=%d host_fields_available=%v host_held_inputs_aggregate=%d host_rejected_inputs_aggregate=%d",
                self.actor,
                s.client.phase,
                len(s.connection.enet.remotes),
                self.hosting ? s.server.timeline.head : s.client.timeline.head,
                self.hosting ? s.server.stats.rx_packets : s.client.stats.rx_packets,
                self.hosting ? s.server.stats.tx_packets : s.client.stats.tx_packets,
                self.hosting ? s.server.stats.rejected_packets : s.client.stats.rejected_packets,
                !self.hosting && s.client.initialized,
                s.client.timeline.confirmed,
                s.client.authority_tick_seen,
                s.client.lead_ticks,
                transmute(u64)s.client.clock_scale,
                s.client.stats.stalls,
                s.client.stats.snapshot_catchups,
                s.client.stats.timing_samples,
                s.client.stats.timing_rejected,
                s.client.stats.lead_updates,
                s.control_consumed,
                remote_found,
                remote_seat,
                remote_input_newest,
                self.hosting && s.server.initialized,
                s.server.stats.held_inputs,
                s.server.stats.rejected_inputs,
            ),
        )
    }

    ready := !self.hosting && s.client.phase == .Running
    bootstrap := false

    if self.hosting {
        drivers, observers := self.role == "host" ? 1 : 0, 0

        for peer in s.server.peers {
            if !peer.local {
                if peer.phase == .Running {
                    if peer.spectator {
                        observers += 1
                    } else {
                        drivers += 1
                    }
                }

                if !self.go && peer.phase == .Pending {
                    bootstrap = true
                }
            }
        }

        ready = self.go || (drivers == 2 && observers == int(self.expected_observers))
    }

    if !slice_announce(self, ready) {
        return
    }

    head := self.hosting ? s.server.timeline.head : s.client.timeline.head
    seat := rgd.session_seat(s)
    control: common.Control

    if self.scripted {
        control = common.scripted_control(head + 1, seat)
    } else {
        control = slice_live_input(self, ready && self.go, seat)
    }

    if self.finished {
        return
    }

    if !self.scripted && self.wall_frames % 30 == 0 {
        gd.print_str(fmt.tprintf("REPLAY_LIVE_CONTROL seat=%d x=%d z=%d", seat, control.x, control.z))
    }

    if seat == 0 {
        control = {}
    }

    if self.scripted && self.go && ready && (self.target == 0 || head < self.target) && seat != 0 {
        for due, index in self.planned {
            if self.sent[index] || head + 1 < due {
                continue
            }

            action := common.scripted_action(self.planned_original[index], seat)

            if action.kind == .None {
                self.planned_original[index] += 240
                self.planned[index] = self.planned_original[index]
                continue
            }

            if head + 1 > due + 8 {
                slice_fail(self, "scripted intent exceeded eight-tick submission bound")
                return
            }

            sampled_authority_tick_seen := s.client.authority_tick_seen

            if !self.hosting && action.kind == .Spawn && sampled_authority_tick_seen < due - 2 {
                continue
            }

            sequence, issue_error := rgd.session_issue(s, action)

            if issue_error == .None {
                self.sent[index] = true
                submitted := head + 1

                if !self.hosting {
                    for queued in s.client.actions[:s.client.action_count] {
                        if queued.sequence == sequence {
                            submitted = queued.tick
                            break
                        }
                    }
                }

                issued_generation, issued_serial := slice_client_scope(self)
                gd.print_str(
                    fmt.tprintf(
                        "BOX3D_SLICE_ISSUED {{\"epoch\":%d,\"requested_tick\":%d,\"original_requested_tick\":%d,\"sampled_head\":%d,\"sampled_tick\":%d,\"submitted_tick\":%d,\"seat\":%d,\"kind\":\"%v\",\"sequence\":%d,\"rebased_before_sampling\":%v,\"recovery_serial\":%d,\"action_timing\":\"Receipt\",\"process_generation\":%d,\"generation\":%d,\"serial\":%d,\"sampled_authority_tick_seen\":%d,\"sampled_authority_tick_seen_available\":%v}}",
                        self.hosting ? s.server.cfg.epoch : s.client.cfg.epoch,
                        due,
                        self.planned_original[index],
                        head,
                        head + 1,
                        submitted,
                        seat,
                        action.kind,
                        sequence,
                        self.rebased[index],
                        self.intent_recovery_serial,
                        self.rejoin.process_generation,
                        issued_generation,
                        issued_serial,
                        sampled_authority_tick_seen,
                        !self.hosting,
                    ),
                )
                self.planned_original[index] += 240
                self.planned[index] = self.planned_original[index]
                self.sent[index] = false
                self.rebased[index] = false
            }
        }
    }

    old_serial, old_baseline := s.client.serial, s.client.baseline
    old_notice_serial := s.client.resync_notice.serial
    error := rgd.session_frame(
        s,
        bootstrap ? f64(1) / 60 + 1e-9 : (self.go && ready && (self.target == 0 || head < self.target) ? dt : f64(0)),
        bootstrap ? common.Control{} : control,
    )

    if !self.hosting {
        notice := s.client.resync_notice

        if notice.serial != 0 && notice.serial != old_notice_serial {
            gd.print_str(
                fmt.tprintf(
                    "BOX3D_SLICE_STATUS {{\"role\":\"client\",\"where\":\"resync_notice\",\"observed_after\":\"session_frame\",\"notice_fields_source\":\"latest_retained_client_resync_notice\",\"notice_serial\":%d,\"prior_notice_serial\":%d,\"notice_serial_advanced\":%v,\"notice_serial_jump\":%v,\"latest_only\":true,\"per_trigger_observation_complete\":false,\"reason_code\":%d,\"reason\":\"%v\",\"head\":%d,\"confirmed\":%d,\"facts\":%d,\"incoming_tick\":%d,\"at_ms\":%d,\"observation_epoch\":%d,\"observation_generation\":%d,\"observation_driver_serial\":%d,\"observation_phase\":\"%v\"}}",
                    notice.serial,
                    old_notice_serial,
                    notice.serial > old_notice_serial,
                    notice.serial > old_notice_serial && notice.serial - old_notice_serial > 1,
                    u8(notice.reason),
                    notice.reason,
                    notice.head,
                    notice.confirmed,
                    notice.facts,
                    notice.incoming_tick,
                    notice.at_ms,
                    s.client.cfg.epoch,
                    s.client.generation,
                    s.client.serial,
                    s.client.phase,
                ),
            )
        }
    }

    if !self.hosting && self.got_close && s.client.phase == .Disconnected {
        slice_finish(self)
        return
    }

    if error != .None {
        gd.print_str(fmt.tprintf("BOX3D_SLICE_ERROR frame=%v", error))
        slice_fail(self, "session frame")
        return
    }

    slice_membership(self)

    // Welcome can complete inside this frame; register its real scope before publication.
    if !slice_announce(self, !self.hosting && s.client.phase == .Running) {
        return
    }

    if !self.hosting &&
       self.announced &&
       old_serial != 0 &&
       s.client.serial > old_serial &&
       s.client.baseline > old_baseline {
        self.intent_recovery_serial = s.client.serial
        gd.print_str(
            fmt.tprintf(
                "BOX3D_SLICE_RECOVERY {{\"epoch\":%d,\"cause\":\"canonical_welcome\",\"old_serial\":%d,\"new_serial\":%d,\"old_baseline\":%d,\"new_baseline\":%d,\"old_head\":%d,\"new_head\":%d,\"view_reset\":%d,\"resyncs\":%d,\"snapshot_catchups\":%d}}",
                s.client.cfg.epoch,
                old_serial,
                s.client.serial,
                old_baseline,
                s.client.baseline,
                head,
                s.client.timeline.head,
                s.client.view_reset,
                s.client.stats.resyncs,
                s.client.stats.snapshot_catchups,
            ),
        )

        for due, index in self.planned {
            if !self.sent[index] && due > head && due <= s.client.timeline.head {
                self.planned[index] = s.client.timeline.head + 1
                self.rebased[index] = true
            }
        }
    }

    changes: [320]v.Change(net.Net_Event(common.Event))
    count := rgd.session_changes(s, changes[:])

    for change in changes[:count] {
        slice_presentation_effect(self, change)
        event := change.occurrence
        value := event.value

        if value.kind != .Gameplay {
            continue
        }

        self.fx += 1
        gd.print_str(
            fmt.tprintf(
                "BOX3D_SLICE_FX {{\"epoch\":%d,\"tick\":%d,\"source\":%d,\"key\":%d,\"phase\":\"%v\",\"confirmed\":%v,\"serial\":%d,\"lifetime\":%d,\"seat\":%d,\"kind\":\"%v\"}}",
                event.id.epoch,
                event.id.tick,
                event.id.source,
                event.id.key,
                change.kind,
                change.confirmed,
                value.value.serial,
                value.value.lifetime,
                value.seat,
                value.value.kind,
            ),
        )
    }

    confirmed := self.hosting ? s.server.timeline.head : s.client.timeline.confirmed

    if self.scripted {
        slice_accepted(self, confirmed)
    } else if self.wall_frames % 30 == 0 {
        entry: net.Accepted_Input(common.Control, common.Action, 2)
        found: bool

        if self.hosting {
            entry, found = net.server_accepted_input(&s.server, confirmed)
        } else {
            entry, found = net.accepted_read(&s.client.physics.accepted, confirmed)
        }

        if found {
            gd.print_str(
                fmt.tprintf(
                    "REPLAY_LIVE_ACCEPTED role=%s tick=%d seat1x=%d seat2x=%d origin2=%v head=%d confirmed=%d seen=%d stalls=%d",
                    self.actor,
                    entry.tick,
                    entry.batch.controls[0].x,
                    entry.batch.controls[1].x,
                    entry.decisions.origins[1],
                    self.hosting ? s.server.timeline.head : s.client.timeline.head,
                    confirmed,
                    s.client.authority_tick_seen,
                    s.client.stats.stalls,
                ),
            )
        }
    }

    slice_presentation_draw(self, dt)

    if self.finished {
        return
    }

    if self.scripted && self.go && self.announced && self.hosting {
        for retained_tick := self.last_frame + 1;
            retained_tick <= confirmed && retained_tick <= self.target;
            retained_tick += 1 {
            slice_frame(self, retained_tick)

            if self.finished {
                return
            }

            self.last_frame = retained_tick
        }
    } else if self.scripted && self.go && self.announced && confirmed > self.last_frame {
        // A canonical catch-up may retain its actual new baseline while older
        // crossed ticks are absent. Export only this real confirmed checkpoint.
        slice_frame(self, min(confirmed, self.target))

        if self.finished {
            return
        }

        self.last_frame = min(confirmed, self.target)
    }

    if slice_interim_exit(self) {
        return
    }

    if self.announced {
        slice_tail(self)

        if self.finished {
            return
        }
    }
}

slice_frame :: proc(self: ^ReplayBox3d, tick: u64) {
    s := &self.state.session
    alloc := meter.allocator(self.scope)
    checkpoint: r.Complete_Checkpoint(common.Game, net.Net_Event(common.Event))
    error: r.Error

    if self.hosting {
        checkpoint, error = r.capture_complete(&s.server.timeline, tick, alloc)
    } else {
        checkpoint, error = r.capture_complete(&s.client.timeline, tick, alloc)
    }

    if error != .None {
        gd.print_str(fmt.tprintf("BOX3D_SLICE_CAPTURE_ERROR tick=%d exact=%v", tick, error))
        slice_fail(self, "confirmed checkpoint")
        return
    }

    defer r.complete_checkpoint_destroy(&checkpoint)

    schemas := self.hosting ? &s.server.physics.schemas : &s.client.physics.schemas
    view, ve := net.complete_view(self.state.codec.value, &checkpoint, &schemas.state, &schemas.occurrence, alloc)

    if ve != .None {
        slice_fail(self, "full view")
        return
    }

    defer net.complete_view_destroy(&view)
    signature, se := bd.sign(view.frame)

    if se != .None {
        slice_fail(self, "signature")
        return
    }

    states: [35]b.Body_State
    cached, cache_error := ph.body_states(&checkpoint, states[:])

    if cache_error != .None {
        slice_fail(self, "evidence cache")
        return
    }

    cached_dynamic := u32(0)

    for body in states[:cached] {
        if body.type == .Dynamic {
            cached_dynamic += 1
        }
    }

    if !self.initial_cache_logged {
        self.initial_cache_logged = true
        gd.print_str(
            fmt.tprintf(
                "BOX3D_SLICE_LIMITS {{\"role\":\"%s\",\"initial_cached_dynamic_bodies\":%d,\"initial_cached_body_count\":%d,\"history\":128,\"hz\":60,\"substeps\":4,\"max_prediction\":8,\"max_repair\":8,\"process_limit_bytes\":67108864}}",
                self.actor,
                cached_dynamic,
                cached,
            ),
        )
    }

    d := process_observations
    gd.print_str(
        fmt.tprintf(
            "BOX3D_SLICE_ENVELOPE {{\"role\":\"%s\",\"epoch\":%d,\"tick\":%d,\"phase\":\"published_cache_and_local_candidate_observation\",\"cached_body_count\":%d,\"cached_dynamic_bodies\":%d,\"native_body_count\":%d,\"native_shape_count\":%d,\"native_contact_count\":%d,\"native_joint_count\":%d,\"peak_body_count\":%d,\"peak_shape_count\":%d,\"peak_contact_count\":%d,\"peak_joint_count\":%d,\"observe_calls\":%d,\"observe_error\":\"%v\"}}",
            self.actor,
            checkpoint.epoch,
            tick,
            cached,
            cached_dynamic,
            d.current.body_count,
            d.current.shape_count,
            d.current.contact_count,
            d.current.joint_count,
            d.peak.body_count,
            d.peak.shape_count,
            d.peak.contact_count,
            d.peak.joint_count,
            d.calls,
            d.last_error,
        ),
    )
    slice_ledger(self, "published_frame")

    if self.announced && tick == self.target {
        self.final_signature = signature
        self.have_final = true
    }

    base := fmt.tprintf("%s/frame-%d-%d", self.output, checkpoint.epoch, tick)

    if len(self.output) != 0 {
        bytes: [bd.SIGNATURE_BYTES]u8
        bd.signature_encode(signature, bytes[:])

        if os.write_entire_file(fmt.tprintf("%s.sig", base), bytes[:]) != nil {
            slice_fail(self, "signature write")
            return
        }

        for part in bd.Part {
            if os.write_entire_file(fmt.tprintf("%s.part%d", base, int(part)), view.frame.parts[part]) != nil {
                slice_fail(self, "part write")
                return
            }
        }
    }

    gd.print_str(
        fmt.tprintf(
            "BOX3D_SLICE_FRAME {{\"role\":\"%s\",\"epoch\":%d,\"tick\":%d,\"head\":%d,\"confirmed\":%d,\"basePath\":\"%s\"}}",
            self.actor,
            checkpoint.epoch,
            tick,
            self.hosting ? s.server.timeline.head : s.client.timeline.head,
            self.hosting ? s.server.timeline.head : s.client.timeline.confirmed,
            base,
        ),
    )
}

slice_finish :: proc(self: ^ReplayBox3d) {
    self.finished = true
    self.ready = false
    slice_flow(self, "before_close")
    slice_ledger(self, "before_close")
    error := slice_close(self)
    slice_ledger(self, "after_cleanup")
    engine, _ := b.engine_allocation_stats()
    wrapper, _ := b.snapshot_allocation_stats()
    stats, _ := meter.category_stats(bg.CATEGORY_REPLAY_PROVIDER)
    core, _ := meter.category_stats(bg.CATEGORY_REPLAY_CORE)
    callbacks, callback_status := rt.managed_callable_stats()
    gd.print_str(
        fmt.tprintf(
            "BOX3D_SLICE_RESULT {{\"role\":\"%s\",\"cleanup\":\"%v\",\"engine_live\":%d,\"wrapper_live\":%d,\"meter_live\":%d,\"owners_live\":%d,\"managed_callbacks_live\":%d,\"callback_status\":%d,\"ok\":%v,\"tick\":%d,\"fx\":%d}}",
            self.actor,
            error,
            engine.live_bytes,
            wrapper.live_bytes,
            stats.live_bytes + core.live_bytes,
            stats.contexts + core.contexts,
            callbacks.live_records,
            callback_status,
            !self.failed && error == .None,
            self.last_frame,
            self.fx,
        ),
    )
    gd.scene_tree_quit(gd.node_get_tree(self.owner), error == .None && !self.failed ? 0 : 1)
}

slice_close :: proc(self: ^ReplayBox3d) -> net.Error {
    if self.state == nil {
        return .None
    }

    state := self.state
    alloc := meter.allocator(self.scope)

    if rgd.session_close(&state.session) != .None {
        return .Wrong_Phase
    }

    if state.codec.ready || state.codec.catalog._handle != nil {
        if ph.network_codec_destroy(&state.codec) != .None {
            return .Wrong_Phase
        }
    }

    b.recovery_catalog_destroy(&state.catalog)
    ph.owner_context_destroy(&state.session_owner)
    ph.owner_context_destroy(&state.codec_owner)
    ph.owner_context_destroy(&state.image_owner)
    mem.free(state, alloc)
    self.state = nil

    if len(self.output) != 0 {
        mem.free(raw_data(self.output), alloc)
        self.output = ""
    }

    return meter.destroy(&self.scope) == bg.OK ? net.Error.None : net.Error.Wrong_Phase
}

slice_fail :: proc(self: ^ReplayBox3d, reason: string) {
    self.failed = true
    gd.print_str(fmt.tprintf("BOX3D_SLICE_ERROR %s", reason))
    slice_finish(self)
}

replay_box3d_exit_tree :: proc(self: ^ReplayBox3d) {
    if self.state != nil {
        slice_close(self)
    }
}

// Only authoritative published records enter APPLIED/INPUT diagnostics. Candidate
// callbacks never print verdicts, so rejection/resimulation cannot fake receipts.
slice_accepted :: proc(self: ^ReplayBox3d, confirmed: u64) {
    s := &self.state.session

    for tick := self.last_audit + 1; tick <= confirmed; tick += 1 {
        entry: net.Accepted_Input(common.Control, common.Action, 2)
        found: bool

        if self.hosting {
            entry, found = net.server_accepted_input(&s.server, tick)
        } else {
            entry, found = net.accepted_read(&s.client.physics.accepted, tick)
        }

        if !found {
            continue
        }

        for control, seat in entry.batch.controls {
            driver := entry.decisions.drivers[seat]
            gd.print_str(
                fmt.tprintf(
                    "BOX3D_SLICE_INPUT {{\"epoch\":%d,\"tick\":%d,\"seat\":%d,\"x\":%d,\"z\":%d,\"origin\":\"%v\",\"generation\":%d,\"serial\":%d,\"incarnation\":%d}}",
                    entry.epoch,
                    entry.tick,
                    seat + 1,
                    control.x,
                    control.z,
                    entry.decisions.origins[seat],
                    driver.generation,
                    driver.serial,
                    driver.incarnation,
                ),
            )

            if !entry.batch.has_action[seat] {
                continue
            }

            gd.print_str(
                fmt.tprintf(
                    "BOX3D_SLICE_APPLIED {{\"epoch\":%d,\"tick\":%d,\"seat\":%d,\"kind\":\"%v\",\"applied\":%v,\"sequence\":%d,\"reason\":\"%v\",\"origin\":\"%v\",\"generation\":%d,\"serial\":%d,\"incarnation\":%d,\"accepted\":true,\"action_timing\":\"Receipt\"}}",
                    entry.epoch,
                    entry.tick,
                    seat + 1,
                    entry.batch.actions[seat].kind,
                    entry.decisions.applied[seat],
                    entry.batch.sequences[seat],
                    entry.decisions.verdicts[seat],
                    entry.decisions.origins[seat],
                    driver.generation,
                    driver.serial,
                    driver.incarnation,
                ),
            )
        }
    }

    self.last_audit = confirmed
}

// Sample termination metadata over the EXISTING application lane. It never
// writes Game, supplies simulation inputs or acknowledges framework packets.
slice_terminal_admit :: proc(self: ^ReplayBox3d, peer_index: int, token: net.Token) -> bool {
    peer := &self.state.session.server.peers[peer_index]
    epoch := self.state.session.server.cfg.epoch

    if peer.local || peer.phase != .Running || token == (net.Token{}) || net.token_hash(token) != peer.token_hash {
        slice_fail(self, "terminal admission scope")
        return false
    }

    for &entry in self.terminal_obligations[:self.terminal_count] {
        if entry.token != token {
            continue
        }

        if entry.epoch == epoch &&
           entry.generation == peer.generation &&
           entry.peer == peer.connection &&
           entry.seat == peer.seat &&
           entry.spectator == peer.spectator {
            return true
        }

        if self.terminal_closing ||
           peer.generation <= entry.generation ||
           entry.seat != peer.seat ||
           entry.spectator != peer.spectator {
            slice_fail(self, "terminal rejoin admission")
            return false
        }

        // Actual monotone same-token admission replaces the old scope; its ACK is
        // not inherited and the old generation is not an extra impossible member.
        entry = {
            token      = token,
            peer       = peer.connection,
            epoch      = epoch,
            generation = peer.generation,
            seat       = peer.seat,
            spectator  = peer.spectator,
        }
        return true
    }

    if self.terminal_closing || self.terminal_count == len(self.terminal_obligations) {
        slice_fail(self, "terminal late admission or roster capacity")
        return false
    }

    self.terminal_obligations[self.terminal_count] = {
        token      = token,
        peer       = peer.connection,
        epoch      = epoch,
        generation = peer.generation,
        seat       = peer.seat,
        spectator  = peer.spectator,
    }
    self.terminal_count += 1
    return true
}

slice_terminal_scope :: proc(self: ^ReplayBox3d, peer_index: int) -> int {
    peer := &self.state.session.server.peers[peer_index]

    for entry, i in self.terminal_obligations[:self.terminal_count] {
        if entry.token == self.role_tokens[peer_index] &&
           entry.peer == peer.connection &&
           entry.epoch == self.state.session.server.cfg.epoch &&
           entry.generation == peer.generation &&
           entry.seat == peer.seat &&
           entry.spectator == peer.spectator {
            return i
        }
    }

    return -1
}

slice_tail :: proc(self: ^ReplayBox3d) {
    s := &self.state.session
    wire := rec.link_application_transport(rgd.session_link(s))
    bytes: [512]u8

    if self.hosting && self.have_final {
        self.terminal_closing = true
    }

    self.tail_frames += 1

    for _ in 0 ..< 16 {
        packet := tr.receive(&wire, bytes[:])

        if packet.state != .Received {
            break
        }

        if packet.count != len(bytes) || string(bytes[:8]) != "RB3TAIL1" {
            continue
        }

        peer_index := -1

        if self.hosting {
            for peer, i in s.server.peers {
                if !peer.local && peer.phase == .Running && peer.connection == packet.from {
                    peer_index = i
                    break
                }
            }
        } else {
            if packet.from != s.client.authority {
                continue
            }
        }

        if self.hosting && peer_index < 0 {
            continue
        }

        if bytes[8] == 4 && self.hosting {
            peer := s.server.peers[peer_index]
            token: net.Token
            copy(token[:], bytes[32:48])

            if net.token_hash(token) != peer.token_hash || sample_read64(bytes[16:24]) != s.server.cfg.epoch {
                continue
            }

            baseline := sample_read64(bytes[24:32])

            if self.target != 0 && baseline + self.required_ticks > self.target {
                slice_fail(self, "role baseline bound")
                return
            }

            if !slice_terminal_admit(self, peer_index, token) {
                return
            }

            if self.role_generation[peer_index] != peer.generation {
                self.peer_done[peer_index] = false
                self.peer_final[peer_index] = false
            }

            self.role_ready[peer_index] = true
            self.role_generation[peer_index] = peer.generation
            self.role_tokens[peer_index] = token
            slice_member_running(self, peer_index)
            continue
        }

        if bytes[8] == 5 && !self.hosting {
            if sample_read64(bytes[16:24]) != s.client.cfg.epoch || !self.announced {
                continue
            }

            if !self.go {
                self.go = true
                gd.print_str(
                    fmt.tprintf(
                        "BOX3D_SLICE_GO {{\"role\":\"%s\",\"epoch\":%d,\"baseline\":%d,\"ready_drivers\":2,\"ready_observers\":%d}}",
                        self.actor,
                        s.client.cfg.epoch,
                        self.baseline,
                        self.expected_observers,
                    ),
                )
            }

            continue
        }

        if self.hosting && self.role_generation[peer_index] != s.server.peers[peer_index].generation {
            continue
        }

        if !self.have_final {
            continue
        }

        signature, error := bd.signature_decode(bytes[32:])

        if error != .None || bd.compare(self.final_signature, signature) != .Match {
            continue
        }

        if self.hosting {
            peer := s.server.peers[peer_index]
            terminal_index := slice_terminal_scope(self, peer_index)

            if terminal_index < 0 {
                slice_fail(self, "terminal ACK scope")
                return
            }

            if bytes[8] == 1 {
                self.peer_done[peer_index] = true
                slice_tail_send(self, &wire, packet.from, 2)
            }

            if bytes[8] == 3 {
                self.terminal_obligations[terminal_index].final = true
                self.peer_final[peer_index] = true
                hex: [32]u8
                digits := "0123456789abcdef"

                for byte, i in self.role_tokens[peer_index] {
                    hex[i * 2] = digits[byte >> 4]
                    hex[i * 2 + 1] = digits[byte & 15]
                }

                gd.print_str(
                    fmt.tprintf(
                        "BOX3D_SLICE_TAIL {{\"role\":\"%s\",\"tick\":%d,\"from_role\":\"%s\",\"from_token_hex\":\"%s\",\"from_peer\":%d,\"from_generation\":%d,\"from_seat\":%d,\"matched\":true,\"confirmed\":true,\"stage\":\"final_received\"}}",
                        self.actor,
                        self.final_signature.tick,
                        peer.spectator ? "observer" : "client",
                        string(hex[:]),
                        u64(peer.connection),
                        peer.generation,
                        peer.seat,
                    ),
                )
            }
        } else if bytes[8] == 2 {
            self.got_close = true
            slice_tail_send(self, &wire, s.client.authority, 3)
        }
    }

    if self.hosting {
        drivers, observers := self.role == "host" ? 1 : 0, 0
        all_ready := true

        for peer, i in s.server.peers {
            if peer.local || peer.phase != .Running {
                continue
            }

            if self.terminal_closing && (!self.role_ready[i] || slice_terminal_scope(self, i) < 0) {
                slice_fail(self, "terminal unadmitted Running peer")
                return
            }

            if peer.spectator {
                observers += 1
            } else {
                drivers += 1
            }

            all_ready = all_ready && self.role_ready[i] && self.role_generation[i] == peer.generation
        }

        cohort := drivers == 2 && observers == int(self.expected_observers)

        if cohort && all_ready && !self.go {
            self.go = true
            gd.print_str(
                fmt.tprintf(
                    "BOX3D_SLICE_GO {{\"role\":\"%s\",\"epoch\":%d,\"baseline\":%d,\"ready_drivers\":%d,\"ready_observers\":%d}}",
                    self.actor,
                    s.server.cfg.epoch,
                    self.baseline,
                    drivers,
                    observers,
                ),
            )
        }

        if self.go && self.tail_frames % 10 == 1 {
            for peer in s.server.peers {
                if !peer.local && peer.phase == .Running {
                    slice_tail_send(self, &wire, peer.connection, 5)
                }
            }
        }

        // Startup counts still gate GO. Terminal obligations are independent of
        // current Running peers: disconnect cannot erase a member or its real ACK.
        terminal_final := self.terminal_count > 0

        for entry in self.terminal_obligations[:self.terminal_count] {
            terminal_final = terminal_final && entry.final && entry.epoch == self.final_signature.epoch
        }

        if self.have_final && self.go && self.terminal_closing && terminal_final {
            slice_finish(self)
            return
        }
    } else if !self.go || (s.client.phase == .Running && self.role_ready_serial != s.client.serial) {
        if self.tail_frames % 10 == 1 {
            slice_tail_send(self, &wire, s.client.authority, 4)
            self.role_ready_serial = s.client.serial
        }
    } else if self.have_final && self.tail_frames % 10 == 1 {
        slice_tail_send(self, &wire, s.client.authority, self.got_close ? 3 : 1)
    }
}

slice_tail_send :: proc(self: ^ReplayBox3d, wire: ^tr.Transport, peer: tr.Peer_Id, kind: u8) {
    bytes: [512]u8
    copy(bytes[:8], "RB3TAIL1")
    bytes[8] = kind

    if kind >= 4 {
        epoch := self.hosting ? self.state.session.server.cfg.epoch : self.state.session.client.cfg.epoch

        for i in 0 ..< 8 {
            bytes[16 + i] = u8(epoch >> uint(i * 8))
            bytes[24 + i] = u8(self.baseline >> uint(i * 8))
        }

        if kind == 4 {
            copy(bytes[32:48], self.state.session.token[:])
        }
    } else {
        for i in 0 ..< 8 {
            bytes[16 + i] = u8(self.final_signature.epoch >> uint(i * 8))
            bytes[24 + i] = u8(self.final_signature.tick >> uint(i * 8))
        }

        _, error := bd.signature_encode(self.final_signature, bytes[32:])

        if error != .None {
            slice_fail(self, "tail signature")
            return
        }
    }

    result := tr.send(wire, peer, .Reliable, bytes[:])

    if result != .Sent && result != .Backpressure && result != .Disconnected {
        slice_fail(self, "tail transport")
    }
}

slice_live_input :: proc(self: ^ReplayBox3d, ready: bool, seat: u16) -> common.Control {
    input := gd.singleton_input()
    result: common.Control

    if gd.input_is_physical_key_pressed(input, .Escape) {
        slice_finish(self)
        return {}
    }

    if !ready || seat == 0 {
        return {}
    }

    if gd.input_is_physical_key_pressed(input, .A) {
        result.x -= 100
    }

    if gd.input_is_physical_key_pressed(input, .D) {
        result.x += 100
    }

    if gd.input_is_physical_key_pressed(input, .W) {
        result.z -= 100
    }

    if gd.input_is_physical_key_pressed(input, .S) {
        result.z += 100
    }

    keys := [6]gd.Key{.Space, .Backspace, .M, .J, .K, .Q}
    kinds := [6]common.Action_Kind{.Spawn, .Remove, .Motor, .Sleep, .Wake, .Query}

    for key, index in keys {
        held := bool(gd.input_is_physical_key_pressed(input, key))

        if held && !self.keys[index] {
            _, error := rgd.session_issue(&self.state.session, common.Action{kind = kinds[index]})

            if error != .None {
                gd.print_str(fmt.tprintf("Replay input held: %v", error))
            }
        }

        self.keys[index] = held
    }

    return result
}

sample_read64 :: proc(bytes: []u8) -> u64 {
    value: u64

    for byte, i in bytes[:8] {
        value |= u64(byte) << uint(i * 8)
    }

    return value
}

slice_flow :: proc(self: ^ReplayBox3d, stage: string) {
    if self.state == nil {
        return
    }

    s := &self.state.session
    link := rgd.session_link(s)
    router := &link.router
    gd.print_str(
        fmt.tprintf(
            "BOX3D_SLICE_FLOW {{\"role\":\"%s\",\"stage\":\"%s\",\"snapshot_every\":%d,\"egress_per_second\":%d,\"egress_per_pump\":%d,\"burst_bytes\":%d,\"bytes_per_lane\":%d,\"packets_per_lane\":%d,\"router_tx_bytes\":%d,\"router_deferred\":%d,\"router_backpressure\":%d,\"net_egress_deferred\":%d,\"received\":%d,\"retired\":%d}}",
            self.actor,
            stage,
            self.hosting ? s.server.cfg.snapshot_every : s.client.cfg.snapshot_every,
            router.cfg.egress_per_second,
            router.cfg.egress_per_pump,
            router.cfg.burst_bytes,
            router.cfg.bytes_per_lane,
            router.cfg.packets_per_lane,
            router.stats.tx_bytes,
            router.stats.deferred,
            router.stats.deferred,
            self.hosting ? s.server.stats.egress_deferred : s.client.stats.egress_deferred,
            router.stats.received,
            router.stats.retired,
        ),
    )
}

digest_hex :: proc(digest: bd.Digest) -> string {
    hex: [64]u8
    digits := "0123456789abcdef"

    for byte, i in digest {
        hex[i * 2] = digits[byte >> 4]
        hex[i * 2 + 1] = digits[byte & 15]
    }

    return fmt.tprintf("%s", string(hex[:]))
}

// Explicit process-local diagnostics only. These counters never enter Game,
// accepted inputs, admission identity or authoritative decisions. Candidate
// observations may include aborted branches and are labelled accordingly.
Process_Observations :: struct {
    calls:         u64,
    current, peak: b.World_Counters,
    last_error:    r.Error,
}

@(private)
process_observations: Process_Observations

observed_step :: proc(
    game: ^common.Game,
    controls: [2]common.Control,
    joins, leaves: u64,
    ctx: ^r.Step(common.Event),
) {
    adapter.step(game, controls, joins, leaves, ctx)
    sample_observe(ctx.execution)
}

observed_action :: proc(game: ^common.Game, seat: u16, action: common.Action, ctx: ^r.Step(common.Event)) -> bool {
    result := adapter.action(game, seat, action, ctx)
    sample_observe(ctx.execution)
    return result
}

sample_observe :: proc(execution: r.Execution) {
    observation, error := ph.observe(execution)
    process_observations.calls += 1
    process_observations.last_error = error

    if error != .None {
        return
    }

    counts := observation.counts
    process_observations.current = counts
    p := &process_observations.peak
    p.body_count = max(p.body_count, counts.body_count)
    p.shape_count = max(p.shape_count, counts.shape_count)
    p.contact_count = max(p.contact_count, counts.contact_count)
    p.joint_count = max(p.joint_count, counts.joint_count)
}

slice_ledger :: proc(self: ^ReplayBox3d, stage: string) {
    contract, cs := b.domain_contract_get()

    if cs != .Ok {
        return
    }

    ledger, status := b.host_ledger_get(contract.cookie)
    gd.print_str(
        fmt.tprintf(
            "BOX3D_SLICE_LEDGER {{\"role\":\"%s\",\"stage\":\"%s\",\"status\":%d,\"engine_live_bytes\":%d,\"snapshot_live_bytes\":%d,\"host_live_bytes\":%d,\"host_reserved_bytes\":%d,\"live_bytes\":%d,\"admitted_bytes\":%d,\"limit_bytes\":%d,\"committed_peak_bytes\":%d,\"ledger_storage_bytes\":%d}}",
            self.actor,
            stage,
            status,
            ledger.engine_live_bytes,
            ledger.snapshot_live_bytes,
            ledger.host_live_bytes,
            ledger.host_reserved_bytes,
            ledger.live_bytes,
            ledger.admitted_bytes,
            ledger.limit_bytes,
            ledger.committed_peak_bytes,
            ledger.ledger_storage_bytes,
        ),
    )
}
