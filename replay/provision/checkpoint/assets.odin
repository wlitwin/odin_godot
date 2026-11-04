package replay_checkpoint

import a "godot:replay/assets"
import auth "godot:replay/authority"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tf "godot:replay/transfer"

PACKAGE_KIND :: u16(0x6355)
PACKAGE_SCHEMA :: u64(0x524f4f4d41535331)

// A room publication retains the transfer engine's 1 MiB bound, including root
// and assets. Larger local save bundles remain a separate storage profile.
Payload :: struct {
    kind:  u16,
    bytes: u32,
    hash:  [32]u8,
}

Asset_Policy :: struct {
    user:     rawptr,
    // Enumerate ALL required references from root state and executable pending
    // work, not merely the current camera's visible set. Return false on overflow.
    collect:  proc(user: rawptr, root: []u8, dst: []a.Ref, codec: ^net.Checkpoint_Codec) -> (count: int, valid: bool),
    validate: proc(user: rawptr, ref: a.Ref, bytes: []u8) -> bool,
}

payload_for :: proc(point: auth.Point, bytes: []u8 = nil) -> Payload {
    if len(bytes) == 0 {
        return {net.CHECKPOINT_KIND, point.archive.bytes, point.archive.hash}
    }

    return {PACKAGE_KIND, u32(len(bytes)), tf.hash(bytes)}
}

payload_valid :: proc(p: Payload) -> bool {
    return(
        (p.kind == net.CHECKPOINT_KIND || p.kind == PACKAGE_KIND) &&
        p.bytes >= sc.HEADER_BYTES &&
        p.bytes <= tf.MAX_BYTES &&
        p.hash != ([32]u8{}) \
    )
}

package_view :: proc(bytes: []u8, point: auth.Point) -> (a.Bundle_View, Error) {
    if len(bytes) < sc.HEADER_BYTES || len(bytes) > tf.MAX_BYTES {
        return {}, .Schema
    }

    meta, body, decoded := sc.unpack_bytes(
        PACKAGE_SCHEMA,
        bytes,
        {kind = PACKAGE_KIND, epoch = point.scope.epoch, content = point.scope.content},
    )

    if decoded.error != .None || meta.tick != point.archive.tick {
        return {}, .Schema
    }

    view, error := a.bundle_decode(body, point.scope.content)

    if error != .None ||
       view.meta.epoch != point.scope.epoch ||
       view.meta.tick != point.archive.tick ||
       len(view.root) != int(point.archive.bytes) ||
       tf.hash(view.root) != point.archive.hash {
        return {}, .Schema
    }

    return view, .None
}

asset_dependencies :: proc(
    policy: Asset_Policy,
    root: []u8,
    dst: []a.Ref,
    codec: ^net.Checkpoint_Codec = nil,
) -> (
    int,
    Error,
) {
    if policy.collect == nil {
        return 0, .None
    }

    count, valid := policy.collect(policy.user, root, dst, codec)

    if !valid || count < 0 || count > len(dst) {
        return 0, .Schema
    }

    unique := 0

    for ref in dst[:count] {
        if ref == (a.Ref{}) {
            continue
        }

        if !a.ref_valid(ref) {
            return 0, .Schema
        }

        found := false

        for previous in dst[:unique] {
            if previous == ref {
                found = true
                break
            }
        }

        if !found {
            dst[unique] = ref
            unique += 1
        }
    }

    return unique, .None
}

assets_validate :: proc(
    policy: Asset_Policy,
    root: []u8,
    view: ^a.Bundle_View,
    codec: ^net.Checkpoint_Codec = nil,
) -> Error {
    refs: [a.BUNDLE_ASSETS]a.Ref
    count, error := asset_dependencies(policy, root, refs[:], codec)

    if error != .None {
        return error
    }

    if count != view.count {
        return .Schema
    }

    if count != 0 && policy.validate == nil {
        return .Invalid
    }

    for ref in refs[:count] {
        if !a.bundle_has(view, ref) {
            return .Missing
        }
    }

    for asset in view.assets[:view.count] {
        if !policy.validate(policy.user, asset.ref, asset.bytes) {
            return .Schema
        }
    }

    return .None
}

package_encode :: proc(
    root: []u8,
    point: auth.Point,
    cache: ^a.Cache,
    policy: Asset_Policy,
    allocator := context.allocator,
    codec: ^net.Checkpoint_Codec = nil,
) -> (
    []u8,
    Error,
) {
    refs: [a.BUNDLE_ASSETS]a.Ref
    count, error := asset_dependencies(policy, root, refs[:], codec)

    if error != .None {
        return nil, error
    }

    if count == 0 {
        return nil, .None
    }

    if cache == nil || !cache.ready {
        return nil, .Missing
    }

    body, bundled := a.bundle_encode(
        root,
        refs[:count],
        cache,
        {epoch = point.scope.epoch, tick = point.archive.tick, content = point.scope.content},
        allocator,
        limit = tf.MAX_BYTES - sc.HEADER_BYTES,
    )
    defer delete(body, allocator)

    if bundled != .None {
        return nil, bundled == .Capacity ? .Capacity : .Missing
    }

    if len(body) > tf.MAX_BYTES - sc.HEADER_BYTES {
        return nil, .Capacity
    }

    bytes := make([]u8, sc.HEADER_BYTES + len(body), allocator)

    if sc.pack_bytes(PACKAGE_SCHEMA, {kind = PACKAGE_KIND, epoch = point.scope.epoch, tick = point.archive.tick, content = point.scope.content}, body, bytes).error !=
       .None {
        delete(bytes, allocator)
        return nil, .Schema
    }

    view, checked := package_view(bytes, point)

    if checked != .None || view.count != count || policy.validate == nil {
        delete(bytes, allocator)
        return nil, .Schema
    }

    for ref in refs[:count] {
        if !a.bundle_has(&view, ref) {
            delete(bytes, allocator)
            return nil, .Schema
        }
    }

    for asset in view.assets[:view.count] {
        if !policy.validate(policy.user, asset.ref, asset.bytes) {
            delete(bytes, allocator)
            return nil, .Schema
        }
    }

    return bytes, .None
}

// The view borrows payload. Validate exact dependency completeness before any
// cache mutation; bundle_install preflights integrity, validation and capacity.
package_install :: proc(
    payload, root: []u8,
    point: auth.Point,
    cache: ^a.Cache,
    policy: Asset_Policy,
    codec: ^net.Checkpoint_Codec = nil,
) -> Error {
    view := a.Bundle_View {
        root = root,
    }

    if len(payload) > 0 {
        v, error := package_view(payload, point)

        if error != .None {
            return error
        }

        view = v
    }

    if error := assets_validate(policy, root, &view, codec); error != .None {
        return error
    }

    if view.count == 0 {
        return .None
    }

    if a.bundle_install(&view, cache, policy.validate, policy.user) != .None {
        return .Capacity
    }

    return .None
}
