package replay_assets

import "core:mem"
import sc "godot:replay/schema"
import tf "godot:replay/transfer"

BUNDLE_KIND :: u16(0x5401)
BUNDLE_VERSION :: u16(1)
BUNDLE_LIMIT :: 16 * 1024 * 1024
BUNDLE_ROOT_LIMIT :: 1024 * 1024
BUNDLE_ASSETS :: 32

Bundle_Error :: enum {
    None,
    Invalid,
    Codec,
    Integrity,
    Missing,
    Capacity,
    Content,
}

@(private)
Bundle_Header :: struct {
    version, count:         u16,
    root_bytes, body_bytes: u32,
    body_hash:              [32]u8,
}

Bundle_Asset :: struct {
    ref:   Ref,
    bytes: []u8,
}

// Read-only borrows into the supplied file buffer. Do not retain after freeing or
// changing that buffer. Decode and validation do not mutate the destination cache.
Bundle_View :: struct {
    meta:   sc.Envelope_Meta,
    root:   []u8,
    assets: [BUNDLE_ASSETS]Bundle_Asset,
    count:  int,
}

// Reframe a validated bundle around a converted root. Asset records/payloads
// remain byte-identical. The caller validates the new root's application metadata;
// this generic container preserves the old outer epoch/tick/content.
bundle_replace_root :: proc(
    original, new_root: []u8,
    content: u64,
    allocator := context.allocator,
    target_content: u64 = 0,
) -> (
    []u8,
    Bundle_Error,
) {
    view, err := bundle_decode(original, content)

    if err != .None {
        return nil, err
    }

    if len(new_root) < 1 || len(new_root) > BUNDLE_ROOT_LIMIT {
        return nil, .Invalid
    }

    codec: sc.Schema
    defer sc.destroy(&codec)

    if sc.init(&codec, Bundle_Header, allocator = allocator).error != .None {
        return nil, .Codec
    }

    header_size := sc.HEADER_BYTES + codec.wire_size
    assets := original[header_size + len(view.root):]

    if header_size + len(new_root) + len(assets) > BUNDLE_LIMIT {
        return nil, .Capacity
    }

    bytes := make([]u8, header_size + len(new_root) + len(assets), allocator)
    committed := false

    defer if !committed {
        delete(bytes, allocator)
    }

    body := bytes[header_size:]
    copy(body, new_root)
    copy(body[len(new_root):], assets)
    header := Bundle_Header{BUNDLE_VERSION, u16(view.count), u32(len(new_root)), u32(len(body)), tf.hash(body)}
    meta := view.meta

    if target_content != 0 {
        meta.content = target_content
    }

    if sc.pack(&codec, header, meta, bytes[:header_size]).error != .None {
        return nil, .Codec
    }

    committed = true
    return bytes, .None
}

bundle_encode :: proc(
    root: []u8,
    refs: []Ref,
    cache: ^Cache,
    meta: sc.Envelope_Meta,
    allocator := context.allocator,
    limit: int = BUNDLE_LIMIT,
) -> (
    []u8,
    Bundle_Error,
) {
    if cache == nil ||
       !cache.ready ||
       len(root) == 0 ||
       len(root) > BUNDLE_ROOT_LIMIT ||
       meta.epoch == 0 ||
       meta.content == 0 {
        return nil, .Invalid
    }

    if limit < 1 || limit > BUNDLE_LIMIT {
        return nil, .Capacity
    }

    header_codec, ref_codec: sc.Schema
    defer sc.destroy(&header_codec)
    defer sc.destroy(&ref_codec)

    if sc.init(&header_codec, Bundle_Header).error != .None || sc.init(&ref_codec, Ref).error != .None {
        return nil, .Codec
    }

    unique: [BUNDLE_ASSETS]Ref
    count := 0
    total := sc.HEADER_BYTES + header_codec.wire_size + len(root)

    if total > limit {
        return nil, .Capacity
    }

    for ref in refs {
        if ref == (Ref{}) {
            continue
        }

        if !ref_valid(ref) {
            return nil, .Invalid
        }

        duplicate := false

        for prior in unique[:count] {
            if prior == ref {
                duplicate = true
                break
            }
        }

        if duplicate {
            continue
        }

        if count == BUNDLE_ASSETS {
            return nil, .Capacity
        }

        if !cache_has(cache, ref) {
            return nil, .Missing
        }

        if int(ref.bytes) + ref_codec.wire_size > limit - total {
            return nil, .Capacity
        }

        unique[count] = ref
        count += 1
        total += ref_codec.wire_size + int(ref.bytes)
    }

    // A canonical dependency order makes repeated saves independent of discovery.
    for i in 1 ..< count {
        j := i

        for j > 0 && ref_less(unique[j], unique[j - 1]) {
            unique[j], unique[j - 1] = unique[j - 1], unique[j]
            j -= 1
        }
    }

    bytes := make([]u8, total, allocator)
    committed := false

    defer if !committed {
        delete(bytes, allocator)
    }

    header_size := sc.HEADER_BYTES + header_codec.wire_size
    body := bytes[header_size:]
    copy(body, root)
    at := len(root)

    for ref in unique[:count] {
        if sc.encode(&ref_codec, ref, body[at:at + ref_codec.wire_size]).error != .None {
            return nil, .Codec
        }

        at += ref_codec.wire_size

        if cache_read(cache, ref, body[at:at + int(ref.bytes)]) != .None {
            return nil, .Missing
        }

        at += int(ref.bytes)
    }

    header := Bundle_Header{BUNDLE_VERSION, u16(count), u32(len(root)), u32(len(body)), tf.hash(body)}
    envelope := meta
    envelope.kind = BUNDLE_KIND

    if sc.pack(&header_codec, header, envelope, bytes[:header_size]).error != .None {
        return nil, .Codec
    }

    committed = true
    return bytes, .None
}

bundle_decode :: proc(bytes: []u8, content: u64) -> (Bundle_View, Bundle_Error) {
    if len(bytes) > BUNDLE_LIMIT || content == 0 {
        return {}, .Invalid
    }

    header_codec, ref_codec: sc.Schema
    defer sc.destroy(&header_codec)
    defer sc.destroy(&ref_codec)

    if sc.init(&header_codec, Bundle_Header).error != .None || sc.init(&ref_codec, Ref).error != .None {
        return {}, .Codec
    }

    header_size := sc.HEADER_BYTES + header_codec.wire_size

    if len(bytes) < header_size {
        return {}, .Invalid
    }

    meta, _, inspected := sc.inspect(bytes[:header_size])

    if inspected.error != .None {
        return {}, .Codec
    }

    if meta.kind != BUNDLE_KIND || meta.content != content {
        return {}, .Content
    }

    header: Bundle_Header
    _, report := sc.unpack(
        &header_codec,
        &header,
        bytes[:header_size],
        {kind = BUNDLE_KIND, epoch = meta.epoch, content = content},
    )

    if report.error != .None {
        return {}, .Codec
    }

    body := bytes[header_size:]

    if header.version != BUNDLE_VERSION ||
       header.count > BUNDLE_ASSETS ||
       header.root_bytes == 0 ||
       header.root_bytes > BUNDLE_ROOT_LIMIT ||
       int(header.body_bytes) != len(body) ||
       int(header.root_bytes) > len(body) {
        return {}, .Invalid
    }

    if tf.hash(body) != header.body_hash {
        return {}, .Integrity
    }

    view := Bundle_View {
        meta  = meta,
        root  = body[:header.root_bytes],
        count = int(header.count),
    }
    at := int(header.root_bytes)

    for i in 0 ..< view.count {
        if ref_codec.wire_size > len(body) - at {
            return {}, .Invalid
        }

        ref: Ref

        if sc.decode(&ref_codec, &ref, body[at:at + ref_codec.wire_size]).error != .None || !ref_valid(ref) {
            return {}, .Invalid
        }

        at += ref_codec.wire_size

        if int(ref.bytes) > len(body) - at || i > 0 && !ref_less(view.assets[i - 1].ref, ref) {
            return {}, .Invalid
        }

        payload := body[at:at + int(ref.bytes)]

        if reference(payload) != ref {
            return {}, .Integrity
        }

        view.assets[i] = {ref, payload}
        at += int(ref.bytes)
    }

    if at != len(body) {
        return {}, .Invalid
    }

    return view, .None
}

bundle_has :: proc(view: ^Bundle_View, ref: Ref) -> bool {
    if ref == (Ref{}) {
        return true
    }

    for entry in view.assets[:view.count] {
        if entry.ref == ref {
            return true
        }
    }

    return false
}

// Preflight every dependency and all cache capacity before installing any asset.
// Validators must be read-only and must not mutate this cache reentrantly.
bundle_install :: proc(
    view: ^Bundle_View,
    cache: ^Cache,
    validator: proc(user: rawptr, ref: Ref, bytes: []u8) -> bool = nil,
    user: rawptr = nil,
) -> Bundle_Error {
    if cache == nil || !cache.ready || view.count < 0 || view.count > BUNDLE_ASSETS {
        return .Invalid
    }

    count, size := 0, 0

    for entry, i in view.assets[:view.count] {
        if !ref_valid(entry.ref) || len(entry.bytes) != int(entry.ref.bytes) || reference(entry.bytes) != entry.ref {
            return .Integrity
        }

        if i > 0 && !ref_less(view.assets[i - 1].ref, entry.ref) {
            return .Invalid
        }

        if validator != nil && !validator(user, entry.ref, entry.bytes) {
            return .Content
        }

        if entry.ref.bytes > u32(cache.cfg.max_asset_bytes) {
            return .Capacity
        }

        if !cache_has(cache, entry.ref) {
            count += 1
            size += len(entry.bytes)
        }
    }

    if count > len(cache.items) - cache.count || size > cache.cfg.max_total_bytes - cache.bytes {
        return .Capacity
    }

    for entry in view.assets[:view.count] {
        _, err := cache_put(cache, entry.bytes, entry.ref)
        assert(err == .None) // preflight and immutable cache ownership establish this
    }

    return .None
}

@(private)
ref_less :: proc(a, b: Ref) -> bool {
    for value, i in a.id {
        if value != b.id[i] {
            return value < b.id[i]
        }
    }

    return a.bytes < b.bytes
}
