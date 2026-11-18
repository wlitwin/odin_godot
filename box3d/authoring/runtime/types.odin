package box3d_authoring_runtime

import "core:mem"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"

Body_Map :: struct {
    logical_id: u64,
    handle:     b.Body,
    key:        b.Body_Key,
}

Shape_Map :: struct {
    logical_id, body_id: u64,
    asset_id:            u32,
    handle:              b.Shape,
    key:                 b.Shape_Key,
}

Joint_Map :: struct {
    logical_id, body_a_id, body_b_id: u64,
    key:                              b.Joint_Key,
}

Character_Map :: struct {
    logical_id: u64,
    config:     b.Character_Config,
    initial:    b.Character_State,
}

// Local runtime owner, never canonical Game state. Destroy world before catalog.
Built_Scene :: struct {
    world:        b.World,
    catalog:      b.Recovery_Catalog,
    bodies:       []Body_Map,
    shapes:       []Shape_Map,
    joints:       []Joint_Map,
    characters:   []Character_Map,
    content_hash: bd.Digest,
    allocator:    mem.Allocator,
}
