package replay_net_parts_reference

import r "godot:replay"
import sc "godot:replay/schema"

Recipient :: struct {
    seat:      u16,
    spectator: bool,
}

Replica :: struct($S, $C: typeid, $N: int) {
    state: S,
    held:  [N]C,
}

// A server-side transmission policy, distinct from a client's simulation group.
// All callbacks must be pure functions of the supplied historical value/recipient.
Replication :: struct($S, $C, $E: typeid, $N: int) {
    id:      u64,
    project: proc(frame: r.Frame(S), held: [N]C, recipient: Recipient) -> (Replica(S, C, N), bool),
    valid:   proc(replica: Replica(S, C, N), recipient: Recipient) -> bool,
    event:   proc(frame: r.Frame(S), recipient: Recipient, event: r.Occurrence(E)) -> (E, bool),
}

@(private)
replication_config_valid :: proc(policy: Replication($S, $C, $E, $N)) -> bool {
    return(
        policy.id == 0 ? policy.project == nil && policy.valid == nil && policy.event == nil : policy.project != nil && policy.valid != nil && policy.event != nil \
    )
}

@(private)
replica_valid :: proc(model: Model($S, $C, $A, $E, $N), state: S, held: [N]C, who: Recipient) -> bool {
    if int(who.seat) > N || (who.seat == 0) != who.spectator {
        return false
    }

    for control in held {
        if !model.control_valid(control) {
            return false
        }
    }

    return(
        model.replication.id == 0 ? model.state_valid(state) : model.replication.valid(Replica(S, C, N){state, held}, who) \
    )
}

@(private)
replica_project :: proc(
    model: Model($S, $C, $A, $E, $N),
    frame: r.Frame(S),
    held: [N]C,
    who: Recipient,
    codec: ^sc.Schema,
    scratch: []u8,
) -> (
    Replica(S, C, N),
    bool,
) {
    if model.replication.id == 0 {
        return {frame.state, held}, true
    }

    value, ok := model.replication.project(frame, held, who)

    if !ok {
        return {}, false
    }

    // The validator sees exactly the public state representation clients decode,
    // including zeroed authority-only fields, rather than a local secret-bearing copy.
    if codec.excluded_fields > 0 {
        if len(scratch) < codec.wire_size || sc.encode(codec, value, scratch[:codec.wire_size]).error != .None {
            return {}, false
        }

        public: Replica(S, C, N)

        if sc.decode(codec, &public, scratch[:codec.wire_size]).error != .None {
            return {}, false
        }

        value = public
    }

    return value, replica_valid(model, value.state, value.held, who)
}

@(private)
replica_facts :: proc(
    model: Model($S, $C, $A, $E, $N),
    frame: r.Frame(S),
    who: Recipient,
    source: Facts_Packet(E),
) -> Facts_Packet(E) {
    if model.replication.id == 0 {
        return source
    }

    source := source
    out := Facts_Packet(E) {
        generation = source.generation,
        serial     = source.serial,
        tick       = source.tick,
    }

    for occurrence in source.events[:source.count] {
        event := occurrence.value

        if event.kind == .Action_Result {
            if who.spectator || event.seat != who.seat {
                continue
            }
        } else {
            value, include := model.replication.event(frame, who, r.Occurrence(E){occurrence.id, event.value})

            if !include {
                continue
            }

            event = Net_Event(E) {
                kind  = .Gameplay,
                value = value,
                seat  = model.event_owner != nil ? model.event_owner(value) : 0,
            }
        }

        out.events[out.count] = {occurrence.id, event}
        out.count += 1
    }

    return out
}
