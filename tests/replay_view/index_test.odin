package replay_view_test

import "core:testing"
import r "godot:replay"
import v "godot:replay/view"

@(test)
bounded_identity_index_preserves_collisions_duplicates_and_capacity :: proc(t: ^testing.T) {
    index: v.Key_Index
    testing.expect(t, v.key_index_init(&index, 256))
    defer v.key_index_destroy(&index)

    for i in 0 ..< 256 {
        testing.expect_value(t, v.key_index_put(&index, u64(i + 1) << 32 | 7, i), v.Index_Error.None)
    }

    for i in 0 ..< 256 {
        value, found := v.key_index_get(&index, u64(i + 1) << 32 | 7)
        testing.expect(t, found && value == i)
        testing.expect_value(t, v.key_index_put(&index, u64(i + 1) << 32 | 7, 999), v.Index_Error.Duplicate)
    }

    testing.expect(t, index.probes > 512) // the workload actually traversed collisions
    testing.expect_value(t, v.key_index_put(&index, 9, 999), v.Index_Error.Capacity)
    testing.expect_value(t, v.key_index_put(&index, 0, 999), v.Index_Error.Invalid)
    _, found := v.key_index_get(&index, 9)
    testing.expect(t, !found && index.count == 256)
    v.key_index_clear(&index)

    for i in 0 ..< 256 {
        _, found = v.key_index_get(&index, u64(i + 1) << 32 | 7)
        testing.expect(t, !found)
    }

    testing.expect_value(t, v.key_index_put(&index, max(u64), -1), v.Index_Error.None)
    v.key_index_clear(&index)
    _, stale := v.key_index_get(&index, max(u64))
    testing.expect(t, !stale)
    testing.expect_value(t, v.key_index_put(&index, max(u64), -1), v.Index_Error.None)
    value, present := v.key_index_get(&index, max(u64))
    testing.expect(t, present && value == -1)
}

@(test)
presentation_handle_key_retains_generation_and_rejects_invalid_handles :: proc(t: ^testing.T) {
    a := r.Handle(i32) {
        index      = 3,
        generation = 1,
    }
    b := a
    b.generation = 2
    testing.expect(t, v.handle_key(a) != v.handle_key(b))
    testing.expect_value(t, v.handle_key(r.Handle(i32){}), u64(0))
    testing.expect_value(t, v.handle_key(r.Handle(i32){index = max(u32), generation = 1}), u64(0))
    testing.expect_value(t, v.handle_key(r.Handle(i32){index = max(u32) - 1, generation = max(u32)}), max(u64))
}
