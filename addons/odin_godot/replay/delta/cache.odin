package replay_delta

import "core:mem"
import sc "godot:replay/schema"

// One-owner bounded history of canonical snapshots, keyed by stream-local ID.
// clear at a connection/checkpoint serial boundary. Returned views are borrowed;
// copy a baseline that must survive future cache eviction.
Cache :: struct {
    allocator:   mem.Allocator,
    size, next:  int,
    ids, hashes: []u64,
    data:        []u8,
}

cache_init :: proc(c: ^Cache, size, slots: int, allocator := context.allocator) -> bool {
    if len(c.ids) != 0 || size < 1 || size > 65535 || slots < 2 || slots > 128 {
        return false
    }

    c.allocator, c.size = allocator, size
    c.ids = make([]u64, slots, allocator)
    c.hashes = make([]u64, slots, allocator)
    c.data = make([]u8, slots * size, allocator)
    return true
}

cache_destroy :: proc(c: ^Cache) {
    delete(c.ids, c.allocator)
    delete(c.hashes, c.allocator)
    delete(c.data, c.allocator)
    c^ = {}
}

cache_clear :: proc(c: ^Cache) {
    for &id in c.ids {
        id = 0
    }

    c.next = 0
}

cache_find :: proc(c: ^Cache, id: u64) -> (bytes: []u8, hash: u64, ok: bool) {
    if id == 0 {
        return
    }

    for found, i in c.ids {
        if found == id {
            return c.data[i * c.size:(i + 1) * c.size], c.hashes[i], true
        }
    }

    return
}

cache_note :: proc(c: ^Cache, id: u64, bytes: []u8) -> bool {
    if id == 0 || len(c.ids) == 0 || len(bytes) != c.size {
        return false
    }

    return cache_note_prehashed(c, id, bytes, sc.digest(bytes))
}

// Reuse a digest computed over these exact bytes. This is a trusted local
// optimization, not a checksum validator: never pass an unverified wire hash.
// The copy remains cache-owned and duplicate IDs still require byte equality.
cache_note_prehashed :: proc(c: ^Cache, id: u64, bytes: []u8, digest: u64) -> bool {
    if id == 0 || len(c.ids) == 0 || len(bytes) != c.size {
        return false
    }

    if old, old_hash, found := cache_find(c, id); found {
        if old_hash != digest {
            return false
        }

        for b, i in bytes {
            if b != old[i] {
                return false
            }
        }

        return true
    }

    c.ids[c.next], c.hashes[c.next] = id, digest
    copy(c.data[c.next * c.size:(c.next + 1) * c.size], bytes)
    c.next = (c.next + 1) % len(c.ids)
    return true
}
