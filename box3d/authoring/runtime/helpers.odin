package box3d_authoring_runtime

import "core:mem"
import a "godot:box3d/authoring"

@(private)
fail :: proc(error: a.Error, field: string, body: int = -1, shape: int = -1, element: int = -1) -> a.Diagnostic {
    return {error = error, field = field, body = body, shape = shape, element = element}
}

@(private)
allocate :: proc($T: typeid, n: int, a: mem.Allocator) -> ([]T, bool) {
    if n == 0 {
        return {}, true
    }

    bytes, error := mem.alloc_bytes(n * size_of(T), align_of(T), a)

    if error != .None {
        return {}, false
    }

    for &v in bytes {
        v = 0
    }

    return (cast([^]T)raw_data(bytes))[:n], true
}
