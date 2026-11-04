package replay_godot_storage

import "core:fmt"
import gd "godot:godot"
import "godot:gdext"
import net "godot:replay/net"
import bg "godot:box3d/godot"

Storage_Error :: enum {
    None,
    Invalid_Path,
    Open,
    Read,
    Write,
    Rename,
    Size,
    Codec,
    Identity,
}

Storage_Result :: struct {
    error:   Storage_Error,
    network: net.Error,
}

checkpoint_write :: proc(
    cp: ^net.Checkpoint($S, $C, $A, $N),
    model: net.Model(S, C, A, $E, N),
    path: string,
    codec: ^net.Checkpoint_Codec = nil,
    allocator := context.allocator,
) -> Storage_Result {
    owned, err := net.checkpoint_encode_owned(cp, model, allocator, codec)
    defer net.complete_data_destroy(&owned)
    bytes := owned.bytes

    if err != .None {
        return {.Codec, err}
    }

    return {error = storage_write(path, bytes)}
}

checkpoint_read :: proc(
    cp: ^net.Checkpoint($S, $C, $A, $N),
    model: net.Model(S, C, A, $E, N),
    path: string,
    content: u64,
    allocator := context.allocator,
) -> Storage_Result {
    bytes, err := storage_read(path, net.MAX_CHECKPOINT_BYTES, allocator)
    defer delete(bytes, allocator)

    if err != .None {
        return {error = err}
    }

    if err := net.checkpoint_decode(cp, bytes, model, content, allocator); err != .None {
        return {.Codec, err}
    }

    return {}
}

// One writer per profile/path. A failed write/flush leaves the previous archive
// intact. A staged file is closed before rename replaces the destination. This
// is a process-crash save boundary, not a portable power-loss/fsync guarantee.
STORAGE_LIMIT :: 16 * 1024 * 1024

storage_write :: proc(path: string, bytes: []u8, limit: int = net.MAX_CHECKPOINT_BYTES) -> Storage_Error {
    if len(path) == 0 || len(path) > 4096 {
        return .Invalid_Path
    }

    if limit < 1 || limit > STORAGE_LIMIT || len(bytes) == 0 || len(bytes) > limit {
        return .Size
    }

    destination := gd.new_string(path)
    staged := gd.new_string(fmt.tprintf("%s.pending", path))
    defer gd.free_string(destination)
    defer gd.free_string(staged)
    file := gd.file_access_open(staged, .Write)

    if file == nil {
        return .Open
    }

    defer if gd.ref_counted_unreference(file) {
        gdext.object_destroy(file)
    }

    packet := gd.new_packed_byte_array()
    defer gd.free_packed_byte_array(packet)

    if gd.packed_byte_array_resize(&packet, gd.Int(len(bytes))) != 0 {
        gd.file_access_close(file)
        return .Size
    }

    copy(gd.packed_byte_array_view(&packet), bytes)
    ok := gd.file_access_store_buffer(file, packet)
    gd.file_access_flush(file)
    ok = ok && gd.file_access_get_error(file) == .Ok && gd.file_access_get_length(file) == u64(len(bytes))
    gd.file_access_close(file)

    if !ok {
        return .Write
    }

    if gd.dir_access_rename_absolute(staged, destination) != .Ok {
        return .Rename
    }

    return .None
}

// Reads an exact bounded file, returning owned bytes. Oversized files are rejected
// before requesting a PackedByteArray or allocating the destination.
storage_read :: proc(path: string, limit: int, allocator := context.allocator) -> ([]u8, Storage_Error) {
    if len(path) == 0 || len(path) > 4096 {
        return nil, .Invalid_Path
    }

    if limit < 1 || limit > STORAGE_LIMIT {
        return nil, .Size
    }

    gpath := gd.new_string(path)
    defer gd.free_string(gpath)
    file := gd.file_access_open(gpath, .Read)

    if file == nil {
        return nil, .Open
    }

    defer if gd.ref_counted_unreference(file) {
        gdext.object_destroy(file)
    }

    defer gd.file_access_close(file)
    size := gd.file_access_get_length(file)

    if size < 1 || size > u64(limit) {
        return nil, .Size
    }

    packet := gd.file_access_get_buffer(file, gd.Int(size))
    defer gd.free_packed_byte_array(packet)
    view := gd.packed_byte_array_view(&packet)

    if len(view) != int(size) || gd.file_access_get_error(file) != .Ok {
        return nil, .Read
    }

    bytes := make([]u8, len(view), allocator)
    copy(bytes, view)
    return bytes, .None
}

// The profile is a local reconnect credential, separate from shared checkpoints.
// An unreadable/malformed existing file fails; it never silently changes identity.
session_profile :: proc(path: string) -> (net.Token, Storage_Error) {
    if len(path) == 0 || len(path) > 4096 {
        return {}, .Invalid_Path
    }

    gpath := gd.new_string(path)
    defer gd.free_string(gpath)

    if gd.file_access_file_exists(gpath) {
        bytes, err := storage_read(path, 16)
        defer delete(bytes)

        if err != .None {
            return {}, err
        }

        if len(bytes) != 16 {
            return {}, .Identity
        }

        token: net.Token
        copy(token[:], bytes)
        bits := u8(0)

        for b in token {
            bits |= b
        }

        if bits == 0 {
            return {}, .Identity
        }

        return token, .None
    }

    token := session_token()
    bits := u8(0)

    for b in token {
        bits |= b
    }

    if bits == 0 {
        return {}, .Identity
    }

    if err := storage_write(path, token[:]); err != .None {
        return {}, err
    }

    return token, .None
}

@(private)
managed_physics :: proc(model: net.Model($S, $C, $A, $E, $N)) -> bool {
    return model.complete_state && bg.module_profile() != 0
}
