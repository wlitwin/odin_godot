// Detached versioned authoring envelope. No Native layout, pointer or Godot value
// is serialized: exact source JSON + checked shared-bake identity only.
package box3d_authoring

import "core:mem"
import "core:encoding/json"
import bd "godot:box3d/diagnostics"

ARTIFACT_VERSION :: 1
IMPORT_VERSION :: 1
ARTIFACT_HEADER_BYTES :: 200
MAX_IMPORT_METADATA_BYTES :: 16384
MAX_ARTIFACT_BYTES :: ARTIFACT_HEADER_BYTES + MAX_IMPORT_METADATA_BYTES + MAX_DEFINITION_BYTES

Import_Metadata :: struct {
    importer:                    string,
    importer_version:            u32,
    source_uri, source_revision: string,
}

Owned_Artifact :: struct {
    scene:                         Baked_Scene,
    metadata:                      Import_Metadata,
    encoded:                       []u8,
    definition_json:               []u8, // read-only view owned by encoded; never delete separately
    source_hash, shared_bake_hash: bd.Digest,
    allocator:                     mem.Allocator,
}

Artifact_Error :: enum {
    None,
    Capacity,
    Version,
    Truncated,
    Corrupt,
    Shared_Bake,
    Metadata,
    Definition,
    Allocation,
}

Artifact_Diagnostic :: struct {
    error:      Artifact_Error,
    field:      string,
    definition: Diagnostic,
}

import_metadata :: proc(source_uri: string = "memory://definition", source_revision: string = "") -> Import_Metadata {
    return {"ogb3.authoring", IMPORT_VERSION, source_uri, source_revision}
}

// Bind the actual shared schema/geometry implementation, not the editor UI or
// a manually maintained label. Artifact versions are separate from scene schema.
shared_bake_identity :: proc() -> bd.Digest {
    digest, error := bd.hash_descriptors(
        "ogb3.shared.authoring.bake.v1",
        []bd.Descriptor {
            {"bake", transmute([]u8)#load("bake.odin")},
            {"motion", transmute([]u8)#load("motion.odin")},
            {"types", transmute([]u8)#load("types.odin")},
        },
    )
    assert(error == .None)
    return digest
}

@(private)
artifact_problem :: proc(error: Artifact_Error, field: string) -> Artifact_Diagnostic {
    return {error = error, field = field}
}

@(private)
metadata_valid :: proc(metadata: Import_Metadata) -> bool {
    if metadata.importer != "ogb3.authoring" ||
       metadata.importer_version != IMPORT_VERSION ||
       len(metadata.source_uri) == 0 ||
       len(metadata.source_uri) > 2048 ||
       len(metadata.source_revision) > 128 {
        return false
    }

    for text in ([3]string{metadata.importer, metadata.source_uri, metadata.source_revision}) {
        for c in text {
            if c < 32 || c == 127 {
                return false
            }
        }
    }

    return true
}

@(private)
artifact_u32 :: proc(bytes: []u8, at: int, value: u32) {
    for i in 0 ..< 4 {
        bytes[at + i] = u8(value >> uint(i * 8))
    }
}

@(private)
artifact_u64 :: proc(bytes: []u8, at: int, value: u64) {
    for i in 0 ..< 8 {
        bytes[at + i] = u8(value >> uint(i * 8))
    }
}

@(private)
artifact_read32 :: proc(bytes: []u8, at: int) -> u32 {
    value: u32

    for i in 0 ..< 4 {
        value |= u32(bytes[at + i]) << uint(i * 8)
    }

    return value
}

@(private)
artifact_read64 :: proc(bytes: []u8, at: int) -> u64 {
    value: u64

    for i in 0 ..< 8 {
        value |= u64(bytes[at + i]) << uint(i * 8)
    }

    return value
}

@(private)
artifact_digest :: proc(bytes: []u8, at: int) -> bd.Digest {
    value: bd.Digest
    copy(value[:], bytes[at:at + 32])
    return value
}

artifact_destroy :: proc(artifact: ^Owned_Artifact) {
    if artifact == nil {
        return
    }

    destroy(&artifact.scene)
    delete(artifact.metadata.importer, artifact.allocator)
    delete(artifact.metadata.source_uri, artifact.allocator)
    delete(artifact.metadata.source_revision, artifact.allocator)
    delete(artifact.encoded, artifact.allocator)
    artifact^ = {}
}

artifact_create :: proc(
    definition_json: []u8,
    metadata: Import_Metadata,
    allocator := context.allocator,
) -> (
    Owned_Artifact,
    Artifact_Diagnostic,
) {
    if len(definition_json) == 0 || len(definition_json) > MAX_DEFINITION_BYTES {
        return {}, artifact_problem(.Capacity, "source.bytes")
    }

    if !metadata_valid(metadata) {
        return {}, artifact_problem(.Metadata, "import/source.metadata")
    }

    serialized, error := json.marshal(metadata)

    if error != nil {
        return {}, artifact_problem(.Allocation, "metadata.json")
    }

    defer delete(serialized)

    if len(serialized) > MAX_IMPORT_METADATA_BYTES {
        return {}, artifact_problem(.Capacity, "metadata.bytes")
    }

    candidate := Owned_Artifact {
        allocator = allocator,
    }
    published := false

    defer if !published {
        artifact_destroy(&candidate)
    }

    scene, problem := parse_and_bake(definition_json, allocator)

    if problem.error != .None {
        return {}, {error = .Definition, field = "source.definition", definition = problem}
    }

    candidate.scene = scene
    ok := false
    candidate.encoded, ok = allocate(u8, ARTIFACT_HEADER_BYTES + len(serialized) + len(definition_json), allocator)

    if !ok {
        return {}, artifact_problem(.Allocation, "artifact.bytes")
    }

    candidate.metadata.importer, ok = copy_key(metadata.importer, allocator)

    if !ok {
        return {}, artifact_problem(.Allocation, "metadata.importer")
    }

    candidate.metadata.importer_version = metadata.importer_version
    candidate.metadata.source_uri, ok = copy_key(metadata.source_uri, allocator)

    if !ok {
        return {}, artifact_problem(.Allocation, "metadata.source_uri")
    }

    candidate.metadata.source_revision, ok = copy_key(metadata.source_revision, allocator)

    if !ok {
        return {}, artifact_problem(.Allocation, "metadata.source_revision")
    }

    candidate.source_hash = bd.hash_bytes(definition_json)
    candidate.shared_bake_hash = shared_bake_identity()
    bytes := candidate.encoded
    copy(bytes[:8], transmute([]u8)string("OGB3ART1"))
    artifact_u32(bytes, 8, ARTIFACT_VERSION)
    artifact_u32(bytes, 12, ARTIFACT_HEADER_BYTES)
    artifact_u32(bytes, 16, scene.data.schema_version)
    artifact_u32(bytes, 20, IMPORT_VERSION)
    artifact_u32(bytes, 24, u32(len(definition_json)))
    artifact_u32(bytes, 28, u32(len(serialized)))
    artifact_u64(bytes, 32, u64(len(serialized) + len(definition_json)))
    copy(bytes[40:72], candidate.source_hash[:])
    copy(bytes[72:104], scene.content_hash[:])
    metadata_hash := bd.hash_bytes(serialized)
    copy(bytes[104:136], metadata_hash[:])
    copy(bytes[168:200], candidate.shared_bake_hash[:])
    copy(bytes[ARTIFACT_HEADER_BYTES:], serialized)
    source_at := ARTIFACT_HEADER_BYTES + len(serialized)
    copy(bytes[source_at:], definition_json)
    payload_hash := bd.hash_bytes(bytes[ARTIFACT_HEADER_BYTES:])
    copy(bytes[136:168], payload_hash[:])
    candidate.definition_json = bytes[source_at:]
    published = true
    return candidate, {}
}

// Reconstruct only through the shared parser/baker. Hashes detect corruption,
// not authenticity; arbitrary untrusted geometry still has normal bake limits.
artifact_load :: proc(encoded: []u8, allocator := context.allocator) -> (Owned_Artifact, Artifact_Diagnostic) {
    if len(encoded) < ARTIFACT_HEADER_BYTES {
        return {}, artifact_problem(.Truncated, "header")
    }

    if len(encoded) > MAX_ARTIFACT_BYTES {
        return {}, artifact_problem(.Capacity, "artifact.bytes")
    }

    if string(encoded[:8]) != "OGB3ART1" {
        return {}, artifact_problem(.Corrupt, "magic")
    }

    if artifact_read32(encoded, 8) != ARTIFACT_VERSION ||
       artifact_read32(encoded, 12) != ARTIFACT_HEADER_BYTES ||
       !schema_supported(artifact_read32(encoded, 16)) ||
       artifact_read32(encoded, 20) != IMPORT_VERSION {
        return {}, artifact_problem(.Version, "artifact/schema/import.version")
    }

    source_length, metadata_length := artifact_read32(encoded, 24), artifact_read32(encoded, 28)

    if source_length == 0 ||
       source_length > MAX_DEFINITION_BYTES ||
       metadata_length == 0 ||
       metadata_length > MAX_IMPORT_METADATA_BYTES {
        return {}, artifact_problem(.Capacity, "source/metadata.length")
    }

    payload_length := u64(source_length) + u64(metadata_length)

    if artifact_read64(encoded, 32) != payload_length ||
       u64(len(encoded)) != u64(ARTIFACT_HEADER_BYTES) + payload_length {
        return {}, artifact_problem(.Truncated, "exact.length_no_trailing")
    }

    source_at := ARTIFACT_HEADER_BYTES + int(metadata_length)
    source := encoded[source_at:]
    serialized := encoded[ARTIFACT_HEADER_BYTES:source_at]

    if artifact_digest(encoded, 168) != shared_bake_identity() {
        return {}, artifact_problem(.Shared_Bake, "shared_bake.sha256")
    }

    if artifact_digest(encoded, 40) != bd.hash_bytes(source) ||
       artifact_digest(encoded, 104) != bd.hash_bytes(serialized) ||
       artifact_digest(encoded, 136) != bd.hash_bytes(encoded[ARTIFACT_HEADER_BYTES:]) {
        return {}, artifact_problem(.Corrupt, "source/metadata/payload.sha256")
    }

    scratch, error := mem.alloc_bytes(MAX_IMPORT_METADATA_BYTES * 4, allocator = allocator)

    if error != .None {
        return {}, artifact_problem(.Allocation, "metadata.scratch")
    }

    defer delete(scratch, allocator)
    arena: mem.Arena
    mem.arena_init(&arena, scratch)
    metadata: Import_Metadata

    if json.unmarshal(serialized, &metadata, allocator = mem.arena_allocator(&arena)) != nil ||
       !metadata_valid(metadata) {
        return {}, artifact_problem(.Metadata, "metadata.fields")
    }

    candidate, problem := artifact_create(source, metadata, allocator)

    if problem.error != .None {
        return {}, problem
    }

    if candidate.scene.data.schema_version != artifact_read32(encoded, 16) ||
       candidate.scene.content_hash != artifact_digest(encoded, 72) {
        artifact_destroy(&candidate)
        return {}, artifact_problem(.Corrupt, "shared_rebake.identity")
    }

    if len(candidate.encoded) != len(encoded) {
        artifact_destroy(&candidate)
        return {}, artifact_problem(.Corrupt, "canonical.metadata")
    }

    for byte, i in candidate.encoded {
        if byte != encoded[i] {
            artifact_destroy(&candidate)
            return {}, artifact_problem(.Corrupt, "canonical.envelope")
        }
    }

    return candidate, {}
}
