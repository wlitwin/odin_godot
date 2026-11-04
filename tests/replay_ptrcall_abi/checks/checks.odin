package ptrcall_abi_checks
import "core:fmt"
import gd "godot:godot"
import ext "godot:gdext"

require :: proc(value: bool) {
    if !value {
        panic("PTRCALL_ABI_CHECK_FAILED")
    }
}

run :: proc() {
    node := gd.new_node()
    defer ext.object_destroy(node)
    name := gd.new_string_name_cstring("get_child_count", true)
    bind := ext.classdb_get_method_bind(gd.node_name_ref(), &name, 894402480)
    require(bind != nil)
    include_internal := gd.Bool(false)
    args := [1]ext.TypePtr{&include_internal}
    guard: struct #align (8) {
        bytes: [16]u8,
    }
    storage := guard.bytes[:]

    for &b in storage {
        b = 0xa5
    }

    ext.object_method_bind_ptrcall(bind, node, raw_data(args[:]), &storage[0])
    changed := 0

    for b in storage {
        if b != 0xa5 {
            changed += 1
        }
    }

    gd.print_str(
        fmt.tprintf(
            "PTRCALL_ABI_OBSERVED public_i32_bytes=%d engine_return_bytes=%d tail_intact=%v",
            size_of(i32),
            changed,
            storage[8] == 0xa5 && storage[15] == 0xa5,
        ),
    )
    require(changed == 8 && storage[8] == 0xa5 && storage[15] == 0xa5)
    require(gd.node_get_child_count(node, false) == 0)
    gd.node_set_process_priority(node, -1234567)
    require(gd.node_get_process_priority(node) == -1234567)
    gd.node_set_process_mode(node, .Process_Mode_Always)
    require(gd.node_get_process_mode(node) == .Process_Mode_Always)
    mode_name := gd.new_string_name_cstring("get_process_mode", true)
    mode_bind := ext.classdb_get_method_bind(gd.node_name_ref(), &mode_name, 739966102)
    require(mode_bind != nil)

    for &b in storage {
        b = 0xa5
    }

    ext.object_method_bind_ptrcall(mode_bind, node, nil, &storage[0])
    changed = 0

    for b in storage {
        if b != 0xa5 {
            changed += 1
        }
    }

    require(
        changed == 8 &&
        storage[0] == u8(gd.Node_Process_Mode.Process_Mode_Always) &&
        storage[8] == 0xa5 &&
        storage[15] == 0xa5,
    )
    gd.print_str(
        fmt.tprintf(
            "PTRCALL_ABI_ENUM_OK public_enum_bytes=%d engine_return_bytes=%d",
            size_of(gd.Node_Process_Mode),
            changed,
        ),
    )
    buffer := gd.new_stream_peer_buffer()
    gd.ref_counted_init_ref(buffer)

    defer {
        if gd.ref_counted_unreference(buffer) {
            ext.object_destroy(buffer)
        }
    }

    gd.stream_peer_put_8(buffer, -128)
    gd.stream_peer_put_u8(buffer, 255)
    gd.stream_peer_put_16(buffer, -32768)
    gd.stream_peer_put_u16(buffer, 65535)
    gd.stream_peer_put_32(buffer, -2147483648)
    gd.stream_peer_put_u32(buffer, 4294967295)
    gd.stream_peer_buffer_seek(buffer, 0)
    require(gd.stream_peer_get_8(buffer) == -128 && gd.stream_peer_get_u8(buffer) == 255)
    require(gd.stream_peer_get_16(buffer) == -32768 && gd.stream_peer_get_u16(buffer) == 65535)
    require(gd.stream_peer_get_32(buffer) == -2147483648 && gd.stream_peer_get_u32(buffer) == 4294967295)
    gd.print_str("PTRCALL_ABI_VALUES_OK signed_unsigned_8_16_32")
}
