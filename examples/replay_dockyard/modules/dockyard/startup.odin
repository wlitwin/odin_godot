package dockyard_duo

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:encoding/json"
import "core:strings"
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
import view "godot:replay/view"

error_set :: proc(self: ^DockyardDuo, text: string) {
    if self.error_count == 0 {
        self.error_count = copy(self.error_text[:], transmute([]u8)text)
    }

    self.failed = true
}

startup :: proc(self: ^DockyardDuo) -> bool {
    self.owners_before, self.owners_before_observed = owner_count_observe()

    if !self.owners_before_observed {
        error_set(self, "cleanup.owner_baseline unavailable")
        return false
    }

    self.role = "host"
    role := gd.launch_param("BOX3D_SAMPLE_ROLE", "role", "")
    online := role == ""

    switch role {
    case "", "host", "Host":
        self.hosting = true
    case "client", "Client":
        self.role = "client"
    case:
        error_set(self, "config.ROLE must be host or client")
        return false
    }

    self.scripted = launch_int("BOX3D_SAMPLE_SCRIPTED", "scripted", 0) != 0
    ticks := launch_int("BOX3D_SAMPLE_TICKS", "ticks", self.scripted ? 120 : 0)
    port := launch_int("BOX3D_SAMPLE_PORT", "port", 49742)

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
    state.session = &state.room.session
    profile_mode := launch_int("DOCKYARD_PROFILE", "profile", 0)
    state.qualification.enabled = profile_mode == 1 || profile_mode == 2 || profile_mode == 3 || profile_mode == 4
    state.qualification.buffered = profile_mode == 2
    state.qualification.phase_detail = profile_mode == 3
    state.qualification.counter_detail = profile_mode == 4

    if state.qualification.counter_detail {
        pointer, allocation_error := mem.alloc(
            128 * size_of(Qualification_Counter_Row),
            align_of(Qualification_Counter_Row),
            allocator,
        )

        if allocation_error != .None || pointer == nil {
            error_set(self, "qualification.counter allocation")
            return false
        }

        state.qualification.counter_rows = (cast([^]Qualification_Counter_Row)pointer)[:128]
    }

    if state.qualification.buffered {
        pointer, allocation_error := mem.alloc(
            65536 * size_of(Qualification_Row),
            align_of(Qualification_Row),
            allocator,
        )

        if allocation_error != .None || pointer == nil {
            error_set(self, "qualification.buffer allocation")
            return false
        }

        state.qualification.buffered_rows = (cast([^]Qualification_Row)pointer)[:65536]
    }

    state.output = gd.env_string("BOX3D_SAMPLE_OUTPUT", "", allocator = allocator)
    state.address = strings.clone_to_cstring(gd.env_string("DOCKYARD_HOST", "127.0.0.1"), allocator)

    if state.address == nil {
        error_set(self, "config.HOST address")
        return false
    }

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

    if !online {
        session_lease, session_status := meter.block_lease(
            scope,
            state,
            size_of(Runtime),
            state.session,
            size_of(state.session^),
        )

        if session_status != bg.OK {
            error_set(self, "SDK.session.lease")
            return false
        }

        state.session_owner, var_error = ph.owner_context_create(
            session_lease,
            user_data = state.session,
            require_live_instance = false,
        )

        if var_error != .None {
            error_set(self, "SDK.session.owner")
            return false
        }
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
        error_set(self, "authoring.DockyardDuo19 bodies/8 assets/one hinge")
        return false
    }

    job := launch_int("DOCKYARD_JOB", "job", 0)

    if job < 0 || job > 2 || !prepare_initial_round(state.built.world, &game, u8(job)) {
        error_set(self, "Dockyard.job must be0..2")
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

    state.initial = checkpoint

    if a.built_destroy(&state.built) != .Ok {
        error_set(self, "authoring.built_destroy retained owner")
        return false
    }

    a.destroy(&state.baked)
    gd.node_queue_free(source) // Runtime retains only detached authored/native values.
    contract, contract_status := b.domain_contract_get()
    service := bg.service_get()
    observed :=
        contract_status == .Ok &&
        contract.cookie == service.domain.cookie &&
        contract.build == service.domain.build &&
        contract.target == service.domain.target

    if !observed {
        error_set(self, "Backend.actual_domain mismatch")
        return false
    }

    images: json.Value = json.Null(nil)

    when !gd.IS_WEB {
        count := native_image_count()

        if count != 1 {
            error_set(self, "Native.loaded_images must equal1")
            return false
        }

        images = json.Integer(count)
    }

    self.ready = true

    if online {
        success := online_init(self)
        log_json("DOCKYARD_LOBBY", struct {
            version:    u32,
            cohort:     string,
            configured: bool,
        }{1, fmt.tprintf("%016x", state.online.content), state.online.configured})
        return success
    }

    return direct_open(self, u16(port))
}

session_options :: proc(self: ^DockyardDuo, port: u16) -> rgd.Session_Options {
    state := self.state
    options := rgd.SESSION_OPTIONS
    options.role = self.hosting ? .Host : .Client
    options.port = u16(port)
    options.address = state.address
    options.network = net.physics_config_default()
    options.network.snapshot_every = 1
    // Optional simulated network conditions for local testing. Each process
    // delays what it RECEIVES, so set them on both roles: latency=50 on host
    // and client is a 100 ms round trip. Loss applies to unreliable packets.
    // Native: DOCKYARD_LATENCY/JITTER/LOSS (launch.py --latency/--jitter/--loss);
    // browser: ?latency=&jitter=&loss= query parameters.
    options.latency_ms = u32(clamp(launch_int("DOCKYARD_LATENCY", "latency", 0), 0, 5000))
    options.jitter_ms = u32(clamp(launch_int("DOCKYARD_JITTER", "jitter", 0), 0, 1000))
    options.loss_permyriad = u32(clamp(launch_int("DOCKYARD_LOSS", "loss", 0), 0, 5000))
    // Optional input delay (ticks, 0..6) once the joined round trip passes
    // 100 ms: steadier remote robots and shallower corrections for that much
    // local input lag. Off by default. DOCKYARD_INPUT_DELAY / ?input_delay=.
    options.network.input_delay_max = u32(
        clamp(launch_int("DOCKYARD_INPUT_DELAY", "input_delay", 0), 0, net.INPUT_DELAY_MAX),
    )
    options.network.input_delay_ping_ms = 100

    when gd.IS_WEB {
        options.backend = .Rtc
        options.rtc = {
            url           = gd.launch_param("DOCKYARD_SIGNAL", "signal"),
            room          = gd.launch_param("DOCKYARD_ROOM", "room"),
            host          = self.hosting,
            ice_json      = `{"iceServers":[]}`,
            wait_for_host = !self.hosting,
        }
    }

    options.replication.transport.egress_per_second = 8 * 1024 * 1024
    options.replication.transport.egress_per_pump = 1024 * 1024
    options.replication.transport.burst_bytes = 1024 * 1024
    // Existing application lane, same sample terminal envelope as replay_box3d.
    // It cannot acknowledge or alter any framework input/physics packet.
    options.replication.application_handles = proc(_: rawptr, _: tr.Peer_Id, _: tr.Channel, bytes: []u8) -> bool {
        return len(bytes) == 512 && string(bytes[:8]) == "RB3TAIL1"
    }
    options.token[0] = self.hosting ? u8(101) : u8(202)
    return options
}

direct_open :: proc(self: ^DockyardDuo, port: u16) -> bool {
    state := self.state
    allocator := meter.allocator(self.scope)
    options := session_options(self, port)
    ownership := rgd.Session_Ownership {
        allocator        = {state.image_owner.owner, allocator.data},
        container        = {state.session_owner.owner, state.session},
        allocation_base  = state,
        allocation_bytes = size_of(Runtime),
    }
    session_error: net.Error

    if self.hosting {
        session_error = rgd.session_open_complete(
            state.session,
            &state.initial,
            model(&state.codec),
            options,
            allocator = allocator,
            ownership = ownership,
        )
    } else {
        session_error = rgd.session_open(
            state.session,
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

    if r.complete_checkpoint_destroy(&state.initial) != .None {
        error_set(self, "Replay.initial.destroy")
        return false
    }

    return game_session_ready(self)
}

game_session_ready :: proc(self: ^DockyardDuo) -> bool {
    state := self.state
    allocator := meter.allocator(self.scope)

    if state.delivery_route_ready {
        return true
    }

    self.hosting = state.session.authority
    self.observing = state.session.role == .Observer
    self.role = self.observing ? "observer" : self.hosting ? "host" : "client"
    epoch := self.hosting ? state.session.server.cfg.epoch : state.session.client.cfg.epoch

    if !view.cue_route_init(&state.delivery_route, epoch, 2, proc(event: net.Net_Event(Event)) -> (u32, bool) {
            return event.value.count, event.kind == .Gameplay && event.value.kind == 2
        }, policy = .Confirmed, capacity = 4, history = 128, per_tick = 4, allocator = allocator) {
        error_set(self, "delivery.presentation.route")
        return false
    }

    state.delivery_route_ready = true

    if !view.cue_route_init(&state.boost_route, epoch, 1, proc(event: net.Net_Event(Event)) -> (u32, bool) {
            return u32(event.value.seat), event.kind == .Gameplay && event.value.kind == 1
        }, policy = .Confirmed, capacity = 4, history = 128, per_tick = 4, allocator = allocator) {
        error_set(self, "boost.presentation.route")
        return false
    }

    state.boost_route_ready = true
    self.go = self.hosting && !self.scripted && !state.online.enabled
    contract, _ := b.domain_contract_get()
    images: json.Value = json.Null(nil)

    when !gd.IS_WEB {
        images = json.Integer(native_image_count())
    }

    log_json("SAMPLE_READY", struct {
        framework, role, content_sha256, mode: string,
        native_images:                         json.Value,
        backend_observed:                      bool,
        domain_cookie_hex, build, target:      string,
    } {
        "Replay",
        self.role,
        hash_hex(self.content),
        self.scripted ? "scripted" : "interactive",
        images,
        true,
        fmt.tprintf("%016x", contract.cookie),
        hash_hex(contract.build),
        hash_hex(contract.target),
    })
    return true
}

dockyard_duo_ready :: proc(self: ^DockyardDuo) {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)

    if !startup(self) {
        finish(self)
    }
}
