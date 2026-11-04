package replay_authoring_demo

import "base:runtime"
import "core:fmt"
import gd "godot:godot"
import b "godot:box3d"
import a "godot:box3d/authoring"
import ga "godot:box3d/godot/authoring"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"

error_set :: proc(self: ^ReplayAuthoringDemo, text: string) {
    if self.error_count == 0 {
        self.error_count = copy(self.error_text[:], transmute([]u8)text)
    }

    self.failed = true
}

startup :: proc(self: ^ReplayAuthoringDemo) -> bool {
    self.owners_before, self.owners_before_observed = owner_count_observe()

    if !self.owners_before_observed {
        error_set(self, "cleanup.owner_baseline unavailable")
        return false
    }

    self.role = "host"
    role := gd.env_string("BOX3D_SAMPLE_ROLE", "host")

    switch role {
    case "host", "Host":
        self.hosting = true
    case "client", "Client":
        self.role = "client"
    case:
        error_set(self, "config.ROLE must be host or client")
        return false
    }

    self.scripted = gd.env_int("BOX3D_SAMPLE_SCRIPTED", 0) != 0
    ticks := gd.env_int("BOX3D_SAMPLE_TICKS", self.scripted ? 120 : 0)
    port := gd.env_int("BOX3D_SAMPLE_PORT", 49742)

    if ticks < 0 || ticks > 216000 || (self.scripted && ticks == 0) || port < 1 || port > 65535 {
        error_set(self, "config.TICKS/PORT")
        return false
    }

    self.target = u64(ticks)
    self.frame_budget = 36000

    if self.target > 120 {
        self.frame_budget += 4 * (self.target - 120)
    }

    scope, status := meter.create(bg.service_get(), bg.CATEGORY_REPLAY_PROVIDER)

    if status != bg.OK {
        error_set(self, "SDK.meter.create")
        return false
    }

    self.scope = scope
    allocator := meter.allocator(scope)
    state := new(Runtime, allocator)

    if state == nil {
        error_set(self, "SDK.Runtime.allocate")
        return false
    }

    self.state = state
    state.output = gd.env_string("BOX3D_SAMPLE_OUTPUT", "", allocator = allocator)
    var_error: r.Error
    state.image_owner, var_error = ph.owner_context_create(
        meter.data_lease(scope),
        allocator_data = allocator.data,
        require_live_instance = false,
    )

    if var_error != .None {
        error_set(self, "SDK.image_owner")
        return false
    }

    codec_lease, codec_status := meter.block_lease(scope, state, size_of(Runtime), &state.codec, size_of(Codec))

    if codec_status != bg.OK {
        error_set(self, "SDK.codec.lease")
        return false
    }

    state.codec_owner, var_error = ph.owner_context_create(
        codec_lease,
        user_data = &state.codec,
        require_live_instance = false,
    )

    if var_error != .None {
        error_set(self, "SDK.codec.owner")
        return false
    }

    session_lease, session_status := meter.block_lease(
        scope,
        state,
        size_of(Runtime),
        &state.session,
        size_of(state.session),
    )

    if session_status != bg.OK {
        error_set(self, "SDK.session.lease")
        return false
    }

    state.session_owner, var_error = ph.owner_context_create(
        session_lease,
        user_data = &state.session,
        require_live_instance = false,
    )

    if var_error != .None {
        error_set(self, "SDK.session.owner")
        return false
    }

    source := gd.get_node(self.owner, "AuthoredWorld")

    if source == nil {
        error_set(self, "authoring.AuthoredWorld missing")
        return false
    }

    problem: ga.Diagnostic
    state.baked, problem = ga.extract(source, allocator)
    defer ga.diagnostic_destroy(&problem)

    if problem.error != .None {
        error_set(self, fmt.tprintf("authoring.extract:%v:%s", problem.error, problem.bake_diagnostic.field))
        return false
    }

    self.content = state.baked.content_hash
    config, config_error := ph.authoring_config(&state.baked)

    if config_error != .None {
        error_set(self, "Replay.authoring_config")
        return false
    }

    build_problem: a.Diagnostic
    state.built, build_problem = a.build(&state.baked, PROFILE)

    if build_problem.error != .None {
        error_set(self, fmt.tprintf("authoring.build:%v:%s", build_problem.error, build_problem.field))
        return false
    }

    game, valid := initial_game(&state.baked, &state.built)

    if !valid {
        error_set(self, "authoring.shared_schema ground/pendulum/player/sensor +onejoint")
        return false
    }

    native_status: b.Status
    state.catalog, native_status = b.recovery_catalog_clone(&state.built.catalog)

    if native_status != .Ok {
        error_set(self, "Native.catalog.clone")
        return false
    }

    if ph.network_codec_init(
           &state.codec,
           &state.catalog,
           config,
           rules(),
           allocator = allocator,
           ownership = state.image_owner,
           context_ownership = state.codec_owner,
       ) !=
       .None {
        error_set(self, "Replay.complete_codec.init")
        return false
    }

    options := rgd.SESSION_OPTIONS
    options.role = self.hosting ? .Host : .Client
    options.port = u16(port)
    options.address = "127.0.0.1"
    options.network = net.physics_config_default()
    options.network.snapshot_every = 1
    options.replication.transport.egress_per_second = 8 * 1024 * 1024
    options.replication.transport.egress_per_pump = 1024 * 1024
    options.replication.transport.burst_bytes = 1024 * 1024
    // Existing application lane, same sample terminal envelope as replay_box3d.
    // It cannot acknowledge or alter any framework input/physics packet.
    options.replication.application_handles = proc(_: rawptr, _: tr.Peer_Id, _: tr.Channel, bytes: []u8) -> bool {
        return len(bytes) == 512 && string(bytes[:8]) == "RB3TAIL1"
    }
    options.token[0] = self.hosting ? u8(101) : u8(202)
    ownership := rgd.Session_Ownership {
        allocator        = {state.image_owner.owner, allocator.data},
        container        = {state.session_owner.owner, &state.session},
        allocation_base  = state,
        allocation_bytes = size_of(Runtime),
    }
    session_error: net.Error

    if self.hosting {
        checkpoint, checkpoint_error := ph.authoring_checkpoint(
            &state.built,
            config,
            r.Frame(Game){state = game},
            net.Net_Event(Event),
            allocator = allocator,
            ownership = state.image_owner,
        )

        if checkpoint_error != .None {
            error_set(self, "Replay.authoring_checkpoint")
            return false
        }

        defer r.complete_checkpoint_destroy(&checkpoint)
        session_error = rgd.session_open_complete(
            &state.session,
            &checkpoint,
            model(&state.codec),
            options,
            allocator = allocator,
            ownership = ownership,
        )
    } else {
        session_error = rgd.session_open(
            &state.session,
            r.Frame(Game){},
            model(&state.codec),
            options,
            allocator = allocator,
            ownership = ownership,
        )
    }

    if session_error != .None {
        error_set(self, fmt.tprintf("Replay.Session.open:%v", session_error))
        return false
    }

    if a.built_destroy(&state.built) != .Ok {
        error_set(self, "authoring.built_destroy retained owner")
        return false
    }

    a.destroy(&state.baked)
    gd.node_queue_free(source) // Runtime retains only detached authored/native values.

    if native_image_count() != 1 {
        error_set(self, "Native.loaded_images must equal1")
        return false
    }

    self.ready = true
    self.go = self.hosting && !self.scripted
    log_json("SAMPLE_READY", struct {
        framework, role, content_sha256, mode: string,
        native_images:                         int,
    }{"Replay", self.role, hash_hex(self.content), self.scripted ? "scripted" : "interactive", native_image_count()})
    return true
}

replay_authoring_demo_ready :: proc(self: ^ReplayAuthoringDemo) {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)

    if !startup(self) {
        finish(self)
    }
}
