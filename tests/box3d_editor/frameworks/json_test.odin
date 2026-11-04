package box3d_editor_frameworks_test

import "core:strings"
import "core:testing"
import "core:encoding/json"
import "core:mem"
import d "godot:box3d/debugdraw"
import wire "godot:box3d/godot/debugdraw"

Decoded_Frame :: struct {
    version:                                   u32,
    epoch_hex, tick_hex, revision_hex, source: string,
    points:                                    [][3]f32,
    colors:                                    [][4]f32,
}

@(test)
draw_json_preserves_wide_stamps_as_hex_and_copies_finite_line_values :: proc(t: ^testing.T) {
    batch := d.Batch {
        stamp = {epoch = max(u64), tick = u64(9007199254740993), revision = u64(9007199254740995), source = .Observed},
        required = 1,
        count = 1,
    }
    lines := [1]d.Line{{a = {0, 1, 2}, b = {3, 4, 5}, color = {0.25, 0.5, 0.75, 1}}}
    bytes, error := wire.frame_json(batch, lines[:])
    testing.expect_value(t, error, wire.Error.None)

    if error != .None {
        return
    }

    defer delete(bytes)
    text := string(bytes)
    testing.expect(
        t,
        strings.contains(text, "\"epoch_hex\":\"ffffffffffffffff\"") &&
        strings.contains(text, "\"tick_hex\":\"0020000000000001\"") &&
        strings.contains(text, "\"revision_hex\":\"0020000000000003\"") &&
        strings.contains(text, "\"source\":\"Observed\""),
    )
    scratch: [8192]u8
    arena: mem.Arena
    mem.arena_init(&arena, scratch[:])
    decoded: Decoded_Frame
    parse_error := json.unmarshal(bytes, &decoded, allocator = mem.arena_allocator(&arena))
    testing.expect(t, parse_error == nil)

    if parse_error != nil {
        return
    }

    testing.expect(t, len(decoded.points) == 2 && len(decoded.colors) == 1)
    testing.expect(
        t,
        decoded.points[0] == ([3]f32{0, 1, 2}) &&
        decoded.points[1] == ([3]f32{3, 4, 5}) &&
        decoded.colors[0] == ([4]f32{0.25, 0.5, 0.75, 1}),
    )
    lines[0].a = {99, 99, 99}
    testing.expect(t, decoded.points[0] == ([3]f32{0, 1, 2}), "encoded output owns copied values")
}

@(test)
draw_json_rejects_inconsistent_counts_and_invalid_colors_without_payload :: proc(t: ^testing.T) {
    batch := d.Batch {
        stamp = {epoch = 1, source = .Confirmed},
        required = 1,
        count = 1,
    }
    lines := [1]d.Line{{a = {0, 0, 0}, b = {1, 0, 0}, color = {1, 1, 1, 1}}}
    bad := batch
    bad.required = 2
    bytes, error := wire.frame_json(bad, lines[:])
    testing.expect(t, error == .Invalid && len(bytes) == 0)
    delete(bytes)
    lines[0].color[0] = 2
    bytes, error = wire.frame_json(batch, lines[:])
    testing.expect(t, error == .Invalid && len(bytes) == 0)
    delete(bytes)
}
