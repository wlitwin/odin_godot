//gd:extends Node
//gd:class SamplingProbe
package replay_public_sampling_test

import "core:fmt"
import "core:mem"
import gd "godot:godot"
import b "godot:box3d"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import ph "godot:replay/physics"
import r "godot:replay"
import net "godot:replay/net"
import rg "godot:replay/godot"
import rec "godot:replay/recovery"
import view "godot:replay/view"
import rt "godot:runtime"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import auth "godot:replay/authority"
import common "godot:examples/box3d_common"
import adapter "godot:examples/replay_box3d/shared/adapter"

Actor :: struct {
    scope:                                                    ^meter.Context,
    session:                                                  rg.Session(
        common.Game,
        common.Control,
        common.Action,
        common.Event,
        2,
    ),
    codec:                                                    adapter.Codec,
    catalog:                                                  b.Recovery_Catalog,
    allocator_owner, codec_owner, session_owner, lease_owner: ph.Owner_Context,
    lease:                                                    auth.Lease,
}

Sampling_Case :: enum {
    Regression,
    Observer,
    No_Catchup,
    Later_Welcome,
    Delay_Owned,
    Delay_Zero,
    Delay_Retired,
    Delay_Legacy,
}

SamplingProbe :: struct {
    owner:                                                             gd.Node,
    legacy:                                                            ^rg.Session(u32, u8, u8, u8, 1),
    held_wire:                                                         r.Owned_Context,
    retired_now:                                                       u64,
    mode:                                                              Sampling_Case,
    control_ok:                                                        bool,
    start_head, start_catchups, start_serial:                          u64,
    host, client:                                                      ^Actor,
    frames, stage, window, sampled, published, catchups, wait, target: u64,
    finished:                                                          bool,
}

actor_open :: proc(host: bool, observer: bool = false, delayed: bool = false) -> (^Actor, bool) {
    scope, status := meter.create(bg.service_get(), bg.CATEGORY_REPLAY_PROVIDER)

    if status != bg.OK {
        return nil, false
    }

    allocator := meter.allocator(scope)
    a, allocation_error := new(Actor, allocator)

    if allocation_error != .None {
        meter.destroy(&scope)
        return nil, false
    }

    a.scope = scope
    committed := false

    defer if !committed {
        actor_close(&a)
    }

    error: r.Error
    a.allocator_owner, error = ph.owner_context_create(
        meter.data_lease(scope),
        allocator_data = allocator.data,
        require_live_instance = false,
    )

    if error != .None {
        return nil, false
    }

    codec_lease, cs := meter.block_lease(scope, a, size_of(Actor), &a.codec, size_of(a.codec))

    if cs != bg.OK {
        return nil, false
    }

    a.codec_owner, error = ph.owner_context_create(codec_lease, user_data = &a.codec, require_live_instance = false)

    if error != .None {
        return nil, false
    }

    session_lease, ss := meter.block_lease(scope, a, size_of(Actor), &a.session, size_of(a.session))

    if ss != bg.OK {
        return nil, false
    }

    a.session_owner, error = ph.owner_context_create(
        session_lease,
        user_data = &a.session,
        require_live_instance = false,
    )

    if error != .None {
        return nil, false
    }

    config := b.recovery_config_default()
    config.profile = common.PROFILE
    assets := common.assets()
    native_status: b.Status
    a.catalog, native_status = b.recovery_catalog_create(config, assets[:])

    if native_status != .Ok {
        return nil, false
    }

    provider := adapter.config(&a.catalog, 4)

    if ph.network_codec_init(
           &a.codec,
           &a.catalog,
           provider,
           adapter.rules(4, 1),
           allocator,
           a.allocator_owner,
           a.codec_owner,
       ) !=
       .None {
        return nil, false
    }

    options := rg.SESSION_OPTIONS
    options.role = host ? rg.Session_Role.Host : rg.Session_Role.Client

    if observer {
        options.role = .Observer
    }

    options.port = 49818
    options.network = net.physics_config_default()
    options.network.snapshot_every = 1
    options.replication.transport.egress_per_second = 8 * 1024 * 1024
    options.replication.transport.egress_per_pump = 1024 * 1024
    options.replication.transport.burst_bytes = 1024 * 1024

    if delayed {
        options.latency_ms = 10
        options.jitter_ms = 1
    }

    options.token[0] = host ? 101 : 202
    ownership := rg.Session_Ownership {
        allocator        = {a.allocator_owner.owner, allocator.data},
        container        = {a.session_owner.owner, &a.session},
        allocation_base  = a,
        allocation_bytes = size_of(Actor),
    }
    model := adapter.model(&a.codec)
    result: net.Error

    if host {
        world, game, ws := common.world(4, 1)

        if ws != .Ok {
            return nil, false
        }

        cp, ce := ph.checkpoint_make(
            r.Frame(common.Game){state = game},
            net.Net_Event(common.Event),
            world,
            provider,
            allocator = allocator,
            ownership = a.allocator_owner,
        )
        b.world_destroy(&world)

        if ce != .None {
            return nil, false
        }

        result = rg.session_open_complete(&a.session, &cp, model, options, allocator, ownership)
        r.complete_checkpoint_destroy(&cp)
    } else {
        result = rg.session_open(&a.session, r.Frame(common.Game){}, model, options, allocator, ownership)
    }

    if result != .None {
        gd.print_str(fmt.tprintf("SAMPLING_SETUP failed=%v", result))
        return nil, false
    }

    committed = true
    return a, true
}

actor_close :: proc(pointer: ^^Actor) -> bool {
    if pointer == nil || pointer^ == nil {
        return true
    }

    a := pointer^

    if rg.session_close(&a.session) != .None {
        return false
    }

    if a.codec.ready || a.codec.catalog._handle != nil {
        if ph.network_codec_destroy(&a.codec) != .None {
            return false
        }
    }

    b.recovery_catalog_destroy(&a.catalog)
    ph.owner_context_destroy(&a.lease_owner)
    ph.owner_context_destroy(&a.session_owner)
    ph.owner_context_destroy(&a.codec_owner)
    ph.owner_context_destroy(&a.allocator_owner)
    scope, allocator := a.scope, meter.allocator(a.scope)
    mem.free(a, allocator)
    pointer^ = nil
    return meter.destroy(&scope) == bg.OK
}

frame :: proc(a: ^Actor, dt: f64, control: common.Control) -> bool {
    error := rg.session_frame(&a.session, dt, control)
    events: [320]view.Change(net.Net_Event(common.Event))
    rg.session_changes(&a.session, events[:])

    if error != .None {
        gd.print_str(fmt.tprintf("SAMPLING_FRAME failed=%v", error))
        return false
    }

    return true
}

sampling_probe_ready :: proc(self: ^SamplingProbe) {
    mode := gd.env_string("SAMPLING_CASE", "regression")
    self.control_ok = true

    switch mode {
    case "observer":
        self.mode = .Observer
    case "no_catchup":
        self.mode = .No_Catchup
    case "later_welcome":
        self.mode = .Later_Welcome
    case "regression":
        self.mode = .Regression
    case "delay_owned":
        self.mode = .Delay_Owned
    case "delay_zero":
        self.mode = .Delay_Zero
    case "delay_retired":
        self.mode = .Delay_Retired
    case "delay_legacy":
        self.mode = .Delay_Legacy
    case:
        finish(self, false)
        return
    }

    if self.mode == .Delay_Legacy {
        delay_legacy_open(self)
        return
    }

    delayed := self.mode == .Delay_Owned || self.mode == .Delay_Retired
    ok: bool
    self.host, ok = actor_open(true, delayed = delayed)

    if !ok {
        finish(self, false)
        return
    }

    self.client, ok = actor_open(false, self.mode == .Observer, delayed)

    if !ok {
        finish(self, false)
    }
}

sampling_probe_process :: proc(self: ^SamplingProbe, dt: f64) {
    if self.finished {
        return
    }

    self.frames += 1

    if self.frames > 600 {
        finish(self, false)
        return
    }

    if self.mode == .Delay_Legacy {
        delay_legacy_frame(self)
        return
    }

    if self.stage == 0 {
        if !frame(self.host, 1.0 / 60 + 1e-9, {}) || !frame(self.client, 1.0 / 60 + 1e-9, {}) {
            finish(self, false)
            return
        }

        if self.client.session.client.phase == .Running {
            self.stage = 1
            self.start_head = self.client.session.client.timeline.head
            self.start_catchups = self.client.session.client.stats.snapshot_catchups
            self.start_serial = self.client.session.client.serial
        }

        return
    }

    if self.mode == .Delay_Owned || self.mode == .Delay_Zero || self.mode == .Delay_Retired {
        delay_owned_frame(self)
        return
    }

    c := &self.client.session.client

    if self.mode == .No_Catchup || self.mode == .Later_Welcome {
        sampling_controls(self)
        return
    }

    if self.stage == 1 || self.stage == 3 {
        if !frame(self.host, 1.0 / 60 + 1e-9, {}) {
            finish(self, false)
            return
        }

        self.target = self.host.session.server.timeline.head
        self.wait = 0
        self.stage += 1
        return
    }

    // Queue genuine ENet packets via the public Link pump without applying a
    // Client snapshot early. Client Session.frame remains the only consumer.
    if !frame(self.host, 0, {}) ||
       !rec.link_pump(rg.session_link(&self.client.session), u64(gd.time_get_ticks_msec(gd.singleton_time()))) {
        finish(self, false)
        return
    }

    self.wait += 1

    if self.wait < 2 {
        return
    }

    before, confirmed, catchups := c.timeline.head, c.timeline.confirmed, c.stats.snapshot_catchups
    control := common.Control{}

    if self.stage == 4 {
        control.x = 100
    }

    if !frame(self.client, 1.0 / 60 + 1e-9, control) {
        finish(self, false)
        return
    }

    delta := c.stats.snapshot_catchups - catchups

    if self.stage == 2 {
        self.stage = delta > 0 ? 3 : 1
        return
    }

    self.stage = 3
    self.window += 1
    self.catchups += delta

    if self.mode == .Observer && (c.timeline.head != c.timeline.confirmed || self.client.session.control_consumed) {
        self.control_ok = false
    }

    consumed := self.client.session.control_consumed
    actual_x := i16(0)

    if consumed {
        input, found := r.read_input(&c.timeline, c.timeline.head)

        if !found {
            finish(self, false)
            return
        }

        actual_x = input.controls[c.seat - 1].x

        if actual_x == 100 {
            self.sampled += 1
        }
    }

    for tick := self.target; tick <= self.target; tick += 1 {
        accepted, found := net.server_accepted_input(&self.host.session.server, tick)

        if c.seat != 0 &&
           found &&
           accepted.batch.controls[c.seat - 1].x == 100 &&
           accepted.decisions.origins[c.seat - 1] == .Sample {
            self.published += 1
        }
    }

    gd.print_str(
        fmt.tprintf(
            "REPLAY_SAMPLING_SAMPLE window=%d input=100 prehead=%d precf=%d posthead=%d postcf=%d seen=%d catchups=%d consumed=%v committed_x=%d published100=%d phase=%v facts=%d stalls=%d target=%d",
            self.window,
            before,
            confirmed,
            c.timeline.head,
            c.timeline.confirmed,
            c.authority_tick_seen,
            delta,
            consumed,
            actual_x,
            self.published,
            c.phase,
            c.facts_contiguous,
            c.stats.stalls,
            self.target,
        ),
    )

    if self.window == 32 {
        finish(self, true)
    }
}

finish :: proc(self: ^SamplingProbe, ran: bool) {
    if self.finished {
        return
    }

    self.finished = true

    if !delay_legacy_close(self) {
        self.control_ok = false
    }

    if !r.owner_is_nil(self.held_wire.owner) {
        r.owner_drop(&self.held_wire.owner)
    }

    closed_client := actor_close(&self.client)
    closed_host := actor_close(&self.host)
    engine, es := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    p, ps := meter.category_stats(bg.CATEGORY_REPLAY_PROVIDER)
    k, ks := meter.category_stats(bg.CATEGORY_REPLAY_CORE)
    cb, cs := rt.managed_callable_stats()
    zero :=
        closed_client &&
        closed_host &&
        es == .Ok &&
        ws == .Ok &&
        ps == bg.OK &&
        ks == bg.OK &&
        cs == bg.OK &&
        engine.live_bytes == 0 &&
        wrapper.live_bytes == 0 &&
        p.live_bytes + k.live_bytes == 0 &&
        p.contexts + k.contexts == 0 &&
        cb.live_records == 0
    passed := ran && self.sampled > 0 && self.published > 0 && zero

    if self.mode != .Regression {
        passed = ran && self.control_ok && zero
    }

    gd.print_str(
        fmt.tprintf(
            "REPLAY_SAMPLING_RESULT case=%v ran=%v window=%d catchups=%d sampled100=%d published100=%d cleanup_zero=%v PASS=%v",
            self.mode,
            ran,
            self.window,
            self.catchups,
            self.sampled,
            self.published,
            zero,
            passed,
        ),
    )
    gd.scene_tree_quit(gd.node_get_tree(self.owner), passed ? 0 : 1)
}

sampling_probe_exit_tree :: proc(self: ^SamplingProbe) {
    actor_close(&self.client)
    actor_close(&self.host)
}
