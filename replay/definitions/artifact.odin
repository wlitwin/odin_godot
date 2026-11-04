package replay_definitions

import sc "godot:replay/schema"

ARTIFACT_KIND :: u16(0x4446)

// Owned bytes; caller deletes them. Metadata's tick carries a local authoring
// source digest; epoch=1 is a file-format constant, never authority permission.
artifact_export :: proc(store: ^Store($Value), ref: Ref, source: u64 = 0) -> ([]u8, Report) {
    if !store.ready {
        return nil, problem(.Invalid, "$", "definition store is not ready")
    }

    value, found := get(store, ref)

    if !found {
        return nil, problem(.Missing, "$ref", "definition version is unavailable")
    }

    bytes := make([]u8, sc.HEADER_BYTES + store.schema.wire_size)
    report := sc.pack(
        &store.schema,
        value,
        {kind = ARTIFACT_KIND, epoch = 1, tick = source, content = ref.semantic},
        bytes,
    )

    if report.error != .None {
        delete(bytes)
        return nil, problem(.Schema, report.path, "could not encode definition artifact")
    }

    return bytes, {}
}

// Decode into a detached candidate and publish only after the complete contract
// and optional game validation pass. source=0 accepts any authoring-source digest.
artifact_import :: proc {
    artifact_import_basic,
    artifact_import_validated,
}

@(private)
artifact_import_basic :: proc(store: ^Store($Value), bytes: []u8, semantic: u64, source: u64 = 0) -> (Ref, Report) {
    validator: proc(_: Value) -> Report
    return artifact_import_validated(store, bytes, semantic, validator, source)
}

@(private)
artifact_import_validated :: proc(
    store: ^Store($Value),
    bytes: []u8,
    semantic: u64,
    validate: proc(_: Value) -> Report,
    source: u64 = 0,
) -> (
    Ref,
    Report,
) {
    if !store.ready || semantic == 0 {
        return {}, problem(.Invalid, "$", "uninitialized store or missing semantic contract")
    }

    value: Value
    meta, report := sc.unpack(&store.schema, &value, bytes, {kind = ARTIFACT_KIND, epoch = 1, content = semantic})

    if report.error != .None {
        return {}, problem(.Schema, report.path, "artifact schema, content, checksum or value mismatch")
    }

    if source != 0 && source != meta.tick {
        return {}, problem(.Invalid, "$source", "artifact was baked from different source inputs")
    }

    return publish(store, value, semantic, validate)
}
