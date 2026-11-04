package replay_net

import r "godot:replay"
import sc "godot:replay/schema"
import v "godot:replay/view"

// Initialization reserves schema compilation separately from runtime payloads.
// Compiler metadata, allocator rounding and host transport buffers are reported
// separately; requested owned schema arrays/strings are charged after compilation.
PHYSICS_SCHEMA_RESERVE :: u64(16 * 1024 * 1024)

@(private)
physics_array_bytes :: proc(array: [dynamic]$T) -> u64 {
    return u64(cap(array)) * u64(size_of(T))
}

complete_schema_owned_bytes :: proc(s: ^sc.Schema) -> u64 {
    bytes :=
        physics_array_bytes(s.fields) +
        physics_array_bytes(s.checks) +
        physics_array_bytes(s.validation) +
        physics_array_bytes(s.validation_blocks) +
        physics_array_bytes(s.spans) +
        physics_array_bytes(s.arrays) +
        physics_array_bytes(s.canonical) +
        physics_array_bytes(s.unions) +
        physics_array_bytes(s.guards) +
        u64(len(s.problem.path))

    for field in s.fields {
        bytes += u64(len(field.path))
    }

    for layout in s.unions {
        bytes += u64(len(layout.variant_sizes)) * 8 + u64(len(layout.variant_names)) * size_of(string)

        for name in layout.variant_names {
            bytes += u64(len(name))
        }
    }

    return bytes
}

@(private)
physics_codecs_bytes :: proc(c: ^Codecs) -> u64 {
    bytes: u64

    for schema in ([?]^sc.Schema {
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
        }) {
        bytes += complete_schema_owned_bytes(schema)
    }

    return bytes
}

@(private)
physics_schemas_bytes :: proc(c: ^Physics_Schemas) -> u64 {
    bytes: u64

    for schema in ([?]^sc.Schema{&c.state, &c.occurrence, &c.accepted, &c.decisions, &c.chunk, &c.ack, &c.fact}) {
        bytes += complete_schema_owned_bytes(schema)
    }

    return bytes
}

@(private)
physics_server_payload :: proc($S, $C, $A, $E: typeid, $N: int) -> u64 {
    return(
        u64(size_of(Server(S, C, A, E, N))) +
        u64(MAX_PEERS * PHYSICS_HISTORY) * u64(size_of(Input_Slot(C))) +
        u64(PHYSICS_HISTORY) * u64(size_of(Facts_Packet(E))) +
        u64(MAX_PEERS) * u64(size_of(Welcome_Packet(S, C, N))) +
        2 * 65536 \
    )
}

@(private)
physics_client_payload :: proc($S, $C, $A, $E: typeid, $N: int) -> u64 {
    j: v.Journal(Net_Event(E))
    return(
        u64(size_of(Client(S, C, A, E, N))) +
        u64(PHYSICS_HISTORY) *
            (u64(size_of(Facts_Packet(E))) + u64(size_of(r.Frame(S))) + 1 + 8 + u64(size_of(Input_Sent))) +
        2 * 65536 +
        u64(size_of(Inputs_Packet(C))) +
        u64(PHYSICS_HISTORY) * u64(size_of(j.batches[0])) +
        u64((PHYSICS_HISTORY + 1) * WIRE_EVENTS) * u64(size_of(j.storage[0])) +
        u64((PHYSICS_HISTORY * 2 + 2) * WIRE_EVENTS) * u64(size_of(v.Change(Net_Event(E)))) \
    )
}
