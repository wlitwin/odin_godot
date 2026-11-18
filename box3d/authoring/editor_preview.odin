package box3d_authoring

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import b "godot:box3d/types"
import d "godot:box3d/debugdraw"
import p "godot:box3d/presentation"

// Editor-only fragments. Array positions identify this request's collection
// entries, never authored/runtime identities. No Baked_Scene or artifact is
// published, and completeness is only about drawing, not authoring validity.
EDITOR_PREVIEW_SCOPE :: "EDITOR_PARTIAL_SHAPES_NO_IDS_NO_FRAME"

Editor_Preview_Shape :: struct {
    pose:      Pose_Input,
    body_type: string,
    sensor:    bool,
    shape:     Shape_Input,
}

Editor_Preview_Request :: struct {
    version, max_lines: u32,
    items:              []Editor_Preview_Shape,
}

Editor_Preview_Item :: struct {
    index:                  int,
    available:              bool,
    start, count, required: u32,
    error, field:           string,
}

Editor_Preview_Result :: struct {
    version:                         u32,
    scope:                           string,
    ok, complete, capacity_exceeded: bool,
    omitted_items:                   int,
    error:                           string,
    items:                           []Editor_Preview_Item,
    lines:                           []d.Line,
}

@(private)
editor_preview_depth_valid :: proc(bytes: []u8) -> bool {
    depth := 0
    quoted, escaped := false, false

    for c in bytes {
        if quoted {
            if escaped {
                escaped = false
            } else if c == '\\' {
                escaped = true
            } else if c == '"' {
                quoted = false
            }

            continue
        }

        if c == '"' {
            quoted = true
        } else if c == '{' || c == '[' {
            depth += 1

            if depth > 32 {
                return false
            }
        } else if c == '}' || c == ']' {
            depth -= 1

            if depth < 0 {
                return false
            }
        }
    }

    return !quoted && depth == 0
}

@(private)
editor_preview_shape :: proc(input: Editor_Preview_Shape, out: []d.Line) -> (u32, Error, string) {
    pose, valid := normalize_pose(input.pose)

    if !valid {
        return 0, .Pose, "body.pose"
    }

    kind: b.Body_Type

    switch input.body_type {
    case "static":
        kind = .Static
    case "kinematic":
        kind = .Kinematic
    case "dynamic":
        kind = .Dynamic
    case:
        return 0, .Unsupported, "body.type"
    }

    asset, problem := bake_asset(input.shape, kind, input.sensor, context.allocator)

    if problem.error != .None {
        return 0, problem.error, problem.field
    }

    defer asset_destroy(&asset, context.allocator)
    // A nonzero, request-local draw label is required by debugdraw. It is
    // neither hashed nor exposed as a stable/catalog identifier.
    asset.catalog_id = 1
    vertices: [d.MAX_VERTICES]d.Vec3
    geometry, error := debug_asset_geometry(&asset, vertices[:])

    if error != .None {
        return 0, error == .Capacity ? Error.Capacity : Error.Geometry, "preview.geometry"
    }

    placement := p.Pose {
        {pose.position.x, pose.position.y, pose.position.z},
        {pose.rotation.x, pose.rotation.y, pose.rotation.z, pose.rotation.w},
    }
    color := d.Color{0.45, 0.7, 1, 1}

    if input.sensor || input.shape.is_sensor {
        color = {0.2, 1, 0.4, 1}
    }

    required, draw_error := d.preview_geometry(geometry, placement, color, 16, out)

    if draw_error != .None {
        return required, draw_error == .Capacity ? Error.Capacity : Error.Geometry, "preview.lines"
    }

    return required, .None, ""
}

// Each fragment is counted before it writes. An invalid/oversized shape does
// not erase previous output or consume the budget of a later small shape.
editor_preview_json :: proc(bytes: []u8, allocator := context.allocator) -> []u8 {
    context.allocator = allocator
    result := Editor_Preview_Result {
        version = 1,
        scope   = EDITOR_PREVIEW_SCOPE,
    }
    scratch: []u8
    defer delete(scratch, allocator)
    storage: []d.Line
    defer delete(storage, allocator)
    defer delete(result.items, allocator)
    request: Editor_Preview_Request

    if len(bytes) == 0 || len(bytes) > MAX_DEFINITION_BYTES {
        result.error = "Capacity"
    } else if !editor_preview_depth_valid(bytes) {
        result.error = "Schema"
    } else {
        allocation_error: mem.Allocator_Error
        scratch, allocation_error = mem.alloc_bytes(MAX_DEFINITION_BYTES * 4, allocator = allocator)

        if allocation_error != .None {
            result.error = "Allocation"
        } else {
            arena: mem.Arena
            mem.arena_init(&arena, scratch)

            if json.unmarshal(bytes, &request, allocator = mem.arena_allocator(&arena)) != nil {
                result.error = "Schema"
            } else if request.version != 1 {
                result.error = "Version"
            } else if len(request.items) > MAX_SHAPES || request.max_lines > d.MAX_LINES {
                result.error = "Capacity"
            } else {
                allocated := false
                result.items, allocated = allocate(Editor_Preview_Item, len(request.items), allocator)

                if allocated {
                    storage, allocated = allocate(d.Line, int(request.max_lines), allocator)
                }

                if !allocated {
                    result.error = "Allocation"
                } else {
                    result.ok, result.complete = true, true
                    written: u32

                    for item, index in request.items {
                        record := &result.items[index]
                        record.index = index
                        record.start = written
                        count, error, field := editor_preview_shape(item, storage[written:])
                        record.required = count
                        record.error = fmt.tprintf("%v", error)
                        record.field = field

                        if error == .None {
                            record.available = true
                            record.count = count
                            written += count
                        } else {
                            result.complete = false
                            result.omitted_items += 1
                            result.capacity_exceeded ||= error == .Capacity
                        }
                    }

                    result.lines = storage[:written]
                }
            }
        }
    }

    encoded, error := json.marshal(result, allocator = allocator)

    if error != nil {
        return nil
    }

    return encoded
}
