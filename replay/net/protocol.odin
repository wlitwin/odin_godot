package replay_net

import "core:mem"
import r "godot:replay"
import sc "godot:replay/schema"

@(private)
Kind :: enum u16 {
    Hello = 1,
    Welcome,
    Reject,
    Inputs,
    Action,
    Facts,
    Snapshot,
    Resync,
    Heartbeat,
    Snapshot_Delta,
    Snapshot_Ack,
    Baseline_Miss,
    Removed,
    Observation,
    Inputs_Compact,
    Features,
    Snapshot_Part,
    Snapshot_Delta_Lz4,
    Recent_Facts,
    Epoch_Query,
    Epoch_Reply,
    Facts_Request,
    Snapshot_Parity,
    Snapshot_Delta_Shuffled,
    Recent_Actions,
    Observation_Compact,
    Recent_Facts_Compact,
    Physics_Part,
    Physics_Ack,
    Physics_Facts,
    Physics_Request,
}

@(private)
Hello_Packet :: struct {
    contract:             u64,
    token:                Token,
    spectator:            bool,
    sent_ms, incarnation: u64,
}

@(private)
Reject_Packet :: struct {
    reason: Reject,
}

@(private)
Removed_Packet :: struct {
    generation, serial: u64,
    reason:             Reject,
}

@(private)
Request_Packet :: struct {
    generation, serial, sequence, sent_ms: u64,
}

@(private)
Control_Sample :: struct($Control: typeid) {
    tick:  u64,
    value: Control,
    view:  View_Stamp,
}

@(private)
Inputs_Packet :: struct($Control: typeid) {
    generation, serial: u64,
    count:              u8,
    samples:            [INPUT_WINDOW]Control_Sample(Control),
}

@(private)
Observation_Packet :: struct($Control: typeid) {
    generation, serial: u64,
    sample:             Control_Sample(Control),
}

@(private)
Action_Packet :: struct($Action: typeid) {
    generation, serial, sequence, tick: u64,
    value:                              Action,
}

@(private)
Welcome_Packet :: struct($State, $Control: typeid, $Seats: int) {
    generation, serial: u64,
    seat:               u16,
    echo_ms:            u64,
    action_settled:     u64,
    action_received:    u64,
    completed_count:    u8,
    completed:          [ACTION_CAPACITY]Action_Outcome,
    frame:              r.Frame(State),
    held:               [Seats]Control,
}

@(private)
Snapshot_Packet :: struct($State, $Control: typeid, $Seats: int) {
    snapshot_id:                                      u64,
    generation, serial, action_settled, input_newest: u64,
    frame:                                            r.Frame(State),
    held:                                             [Seats]Control,
}

@(private)
Snapshot_Ack :: struct {
    generation, serial, id, hash: u64,
}

// Optional protocol-7 extension. Peers advertise support after each Welcome;
// the base contract, existing packet schemas and checkpoint format stay exact.
@(private)
Features_Packet :: struct {
    generation, serial, features: u64,
    part_bytes:                   u16,
}

@(private)
Snapshot_Part_Header :: struct {
    generation, serial, id, digest: u64,
    total:                          u32,
    index, part_bytes:              u16,
}

@(private)
Recent_Facts_Header :: struct {
    generation, serial: u64,
    count:              u8,
}

@(private)
Facts_Request :: struct {
    generation, serial, first: u64,
    missing:                   u32,
}

@(private)
Facts_Header :: struct {
    generation, serial, tick: u64,
    count:                    u16,
}

@(private)
Facts_Packet :: struct($Event: typeid) {
    generation, serial, tick: u64,
    count:                    u16,
    events:                   [WIRE_EVENTS]r.Occurrence(Net_Event(Event)),
}

@(private)
Codecs :: struct {
    hello, reject, request, controls, action_value, event_value, state, replica:   sc.Schema,
    inputs, action, welcome, snapshot, facts:                                      sc.Schema,
    snapshot_ack, fact_header, occurrence:                                         sc.Schema,
    removed, observation:                                                          sc.Schema,
    view_stamp, features, snapshot_part, recent_facts, epoch_query, facts_request: sc.Schema,
}

@(private)
codecs_init :: proc(
    c: ^Codecs,
    $State, $Control, $Action, $Event: typeid,
    $Seats: int,
    allocator: mem.Allocator,
    replication: bool = false,
) -> bool {
    public := sc.DEFAULT_OPTIONS
    public.projection = .Public
    types := [?]typeid{Hello_Packet, Reject_Packet, Request_Packet, Control, Action, Event, State}
    schemas := [?]^sc.Schema{&c.hello, &c.reject, &c.request, &c.controls, &c.action_value, &c.event_value, &c.state}

    for schema, i in schemas {
        options := sc.DEFAULT_OPTIONS

        if i == 6 {
            options = public
        }

        if sc.init(schema, types[i], options, allocator).error != .None {
            return false
        }

        if schema.wire_size + sc.HEADER_BYTES > 65536 {
            return false
        }
    }

    // Pass instantiated generic types directly. This Odin toolchain emits a nil
    // typeid for a generic type expression inside a typeid array literal.
    if replication && sc.init(&c.replica, Replica(State, Control, Seats), public, allocator).error != .None {
        return false
    }

    if sc.init(&c.inputs, Inputs_Packet(Control), allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.action, Action_Packet(Action), allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.welcome, Welcome_Packet(State, Control, Seats), public, allocator).error != .None {
        return false
    }

    if sc.init(&c.snapshot, Snapshot_Packet(State, Control, Seats), public, allocator).error != .None {
        return false
    }

    if sc.init(&c.facts, Facts_Packet(Event), allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.snapshot_ack, Snapshot_Ack, allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.fact_header, Facts_Header, allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.occurrence, r.Occurrence(Net_Event(Event)), allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.removed, Removed_Packet, allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.observation, Observation_Packet(Control), allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.view_stamp, View_Stamp, allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.features, Features_Packet, allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.snapshot_part, Snapshot_Part_Header, allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.recent_facts, Recent_Facts_Header, allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.epoch_query, Epoch_Query, allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.facts_request, Facts_Request, allocator = allocator).error != .None {
        return false
    }

    packets := [?]^sc.Schema{&c.inputs, &c.action, &c.welcome, &c.snapshot, &c.facts}

    for packet in packets {
        if packet.wire_size + sc.HEADER_BYTES > 65536 {
            return false
        }
    }

    return true
}

@(private)
codecs_destroy :: proc(c: ^Codecs) {
    schemas := [?]^sc.Schema {
        &c.hello,
        &c.reject,
        &c.request,
        &c.controls,
        &c.action_value,
        &c.event_value,
        &c.state,
        &c.replica,
        &c.inputs,
        &c.action,
        &c.welcome,
        &c.snapshot,
        &c.facts,
    }
    extra := [?]^sc.Schema {
        &c.snapshot_ack,
        &c.fact_header,
        &c.occurrence,
        &c.removed,
        &c.observation,
        &c.view_stamp,
        &c.features,
        &c.snapshot_part,
        &c.recent_facts,
        &c.epoch_query,
        &c.facts_request,
    }

    for schema in schemas {
        sc.destroy(schema)
    }

    for schema in extra {
        sc.destroy(schema)
    }
}

@(private)
contract_hash :: proc(
    c: ^Codecs,
    cfg: Config,
    seats: int,
    timing: Control_Timing = .Scheduled,
    protocol: u64 = PROTOCOL_VERSION,
    replication: u64 = 0,
    action_timing: Action_Timing = .Scheduled,
    action_schedule: u64 = 0,
    authority_policy: u64 = 0,
) -> u64 {
    values := [?]u64 {
        protocol,
        u64(seats),
        u64(cfg.hz),
        u64(cfg.require_permit),
        u64(cfg.max_rewind),
        u64(cfg.max_view_span),
        u64(cfg.view_slack),
        u64(cfg.watch_delay),
        c.controls.fingerprint,
        c.action_value.fingerprint,
        c.event_value.fingerprint,
        c.state.fingerprint,
        c.inputs.fingerprint,
        c.action.fingerprint,
        c.welcome.fingerprint,
        c.snapshot.fingerprint,
        c.facts.fingerprint,
        c.snapshot_ack.fingerprint,
        c.fact_header.fingerprint,
        c.occurrence.fingerprint,
    }
    h := u64(0xcbf29ce484222325)

    for value in values {
        h = (h ~ value) * 0x100000001b3
    }

    // Preserve the existing scheduled contract and wire/archive layouts. A
    // latest-observation model is a distinct, explicitly negotiated capability.
    if timing != .Scheduled {
        h = (h ~ (0x4f42535600000000 | u64(timing))) * 0x100000001b3
        h = (h ~ c.observation.fingerprint) * 0x100000001b3
    }

    if replication != 0 {
        h = (h ~ 0x5245504c49434131) * 0x100000001b3
        h = (h ~ replication) * 0x100000001b3
    }

    if action_timing != .Scheduled {
        h = (h ~ (0x414354494f4e0000 | u64(action_timing))) * 0x100000001b3
    }

    if action_schedule != 0 {
        h = (h ~ 0x4143545343484431) * 0x100000001b3
        h = (h ~ action_schedule) * 0x100000001b3
    }

    if authority_policy != 0 {
        h = (h ~ 0x41555448504f4c31) * 0x100000001b3
        h = (h ~ authority_policy) * 0x100000001b3
    }

    return h
}
