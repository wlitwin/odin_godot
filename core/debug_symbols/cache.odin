package debug_symbols

import "base:intrinsics"
import "core:mem"
import "core:os"
import "core:sync"

// A registration node is stable until process exit; retired image allocations
// are collected after all readers finish. Exhaustion degrades to module+offset.
MAX_IMAGES :: 4096
MAX_CACHE_BYTES :: 128 * 1024 * 1024

Registration :: struct {
    next:      ^Registration,
    active:    bool,
    released:  bool,
    base:      uintptr,
    image:     Image,
    allocator: mem.Allocator,
    charged:   int,
}

@(private)
nodes: [MAX_IMAGES]Registration
@(private)
used: int
@(private)
head: ^Registration
@(private)
readers: u32
@(private)
charged: int
@(private)
writer: sync.Mutex

// Seq-cst reader entry precedes loading the published head/active flags. The
// writer retires first and frees only with no readers; names stay borrowed until
// read_end. Both functions and cached_lookup are allocation/file/lock free.
read_begin :: proc "contextless" () {
    intrinsics.atomic_add(&readers, 1)
}

read_end :: proc "contextless" () {
    intrinsics.atomic_sub(&readers, 1)
}

cached_lookup :: proc "contextless" (address, module_base: uintptr) -> (cstring, uintptr) {
    node := intrinsics.atomic_load(&head)

    for node != nil {
        if node.base == module_base && intrinsics.atomic_load(&node.active) {
            if name, start := lookup(&node.image, address); name != nil {
                return name, start
            }
        }

        node = node.next
    }

    return nil, 0
}

@(private)
collect :: proc() {
    if intrinsics.atomic_load(&readers) != 0 {
        return
    }

    for &node in nodes[:used] {
        if !intrinsics.atomic_load(&node.active) && !node.released {
            context.allocator = node.allocator
            data := node.image.data
            destroy(&node.image)
            delete(data)
            node.released = true
            charged -= node.charged
        }
    }
}

@(private)
read_file :: proc(path: string, allocator: mem.Allocator) -> ([]u8, bool) {
    file, error := os.open(path)

    if error != nil {
        return nil, false
    }

    defer os.close(file)
    info, stat_error := os.fstat(file, context.temp_allocator)

    if stat_error != nil || info.size < 64 || info.size > MAX_FILE_BYTES {
        return nil, false
    }

    data := make([]u8, int(info.size), allocator)
    count, read_error := os.read_at(file, data, 0)
    extra: [1]u8
    more, _ := os.read_at(file, extra[:], info.size)

    if read_error != nil || count != len(data) || more != 0 {
        delete(data, allocator)
        return nil, false
    }

    return data, true
}

register :: proc(path: string, module_base: uintptr, allocator := context.allocator) -> ^Registration {
    data, read := read_file(path, allocator)

    if !read {
        return nil
    }

    image, valid := parse(data, module_base, allocator)

    if !valid {
        delete(data, allocator)
        return nil
    }

    sync.lock(&writer)
    defer sync.unlock(&writer)
    collect()
    bytes := len(data) + cap(image.functions) * size_of(Function)

    if used == MAX_IMAGES || bytes > MAX_CACHE_BYTES - charged {
        destroy(&image)
        delete(data, allocator)
        return nil
    }

    node := &nodes[used]
    used += 1
    node.image, node.base, node.allocator, node.charged = image, module_base, allocator, bytes
    node.next = intrinsics.atomic_load(&head)
    intrinsics.atomic_store(&node.active, true)
    charged += bytes
    intrinsics.atomic_store(&head, node)
    return node
}

retire :: proc(registration: ^Registration) {
    if registration == nil {
        return
    }

    sync.lock(&writer)
    defer sync.unlock(&writer)
    intrinsics.atomic_store(&registration.active, false)
    collect()
}
