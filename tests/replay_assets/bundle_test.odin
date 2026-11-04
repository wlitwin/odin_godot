package replay_assets_test

import "core:testing"
import "core:reflect"
import a "godot:replay/assets"

@(test)
bundle_round_trip_orders_dependencies_and_supports_more_than_one_megabyte :: proc(t: ^testing.T) {
    cache: a.Cache
    a.cache_init(&cache, {8, 800000, 3000000})
    defer a.cache_destroy(&cache)
    first := make([]u8, 700000)
    second := make([]u8, 600000)
    defer delete(first)
    defer delete(second)
    first[0], second[0] = 1, 2
    one, _ := a.cache_put(&cache, first)
    two, _ := a.cache_put(&cache, second)
    root := [4]u8{1, 2, 3, 4}
    refs := [3]a.Ref{two, one, two}
    bytes, err := a.bundle_encode(root[:], refs[:], &cache, {epoch = 3, tick = 19, content = 7})
    defer delete(bytes)
    testing.expect_value(t, err, a.Bundle_Error.None)
    testing.expect(t, len(bytes) > 1024 * 1024)
    view, decoded := a.bundle_decode(bytes, 7)
    testing.expect_value(t, decoded, a.Bundle_Error.None)
    testing.expect_value(t, view.count, 2)
    testing.expect(t, reflect.equal(view.root, root[:], true))
    testing.expect(t, a.bundle_has(&view, one) && a.bundle_has(&view, two))
    refs = {one, two, {}}
    again, encoded := a.bundle_encode(root[:], refs[:], &cache, view.meta)
    defer delete(again)
    testing.expect_value(t, encoded, a.Bundle_Error.None)
    testing.expect(t, reflect.equal(bytes, again, true))
    target: a.Cache
    a.cache_init(&target, {8, 800000, 3000000})
    defer a.cache_destroy(&target)
    testing.expect_value(t, a.bundle_install(&view, &target), a.Bundle_Error.None)
    testing.expect_value(t, target.bytes, 1300000)
    copy, copied := a.cache_copy(&target, two)
    defer delete(copy)
    testing.expect_value(t, copied, a.Error.None)
    testing.expect(t, reflect.equal(copy, second, true))
    _, decoded = a.bundle_decode(bytes, 8)
    testing.expect_value(t, decoded, a.Bundle_Error.Content)
    bytes[len(bytes) - 1] ~= 1
    _, decoded = a.bundle_decode(bytes, 7)
    testing.expect_value(t, decoded, a.Bundle_Error.Integrity)
}

@(test)
missing_content_and_failed_batch_install_preserve_existing_cache :: proc(t: ^testing.T) {
    source: a.Cache
    a.cache_init(&source)
    defer a.cache_destroy(&source)
    one := [4]u8{1, 2, 3, 4}
    two := [4]u8{5, 6, 7, 8}
    r1, _ := a.cache_put(&source, one[:])
    r2 := a.reference(two[:])
    refs := [2]a.Ref{r1, r2}
    bytes, err := a.bundle_encode(one[:], refs[:], &source, {epoch = 1, content = 7})
    testing.expect_value(t, err, a.Bundle_Error.Missing)
    testing.expect(t, bytes == nil)
    a.cache_put(&source, two[:])
    bytes, err = a.bundle_encode(one[:], refs[:], &source, {epoch = 1, content = 7})
    defer delete(bytes)
    view, decoded := a.bundle_decode(bytes, 7)
    testing.expect_value(t, decoded, a.Bundle_Error.None)
    target: a.Cache
    a.cache_init(&target, {1, 8, 8})
    defer a.cache_destroy(&target)
    a.cache_put(&target, one[:])
    a.cache_pin(&target, r1)
    testing.expect_value(t, a.bundle_install(&view, &target), a.Bundle_Error.Capacity)
    testing.expect_value(t, target.count, 1)
    testing.expect(t, a.cache_has(&target, r1) && !a.cache_has(&target, r2))
    second: a.Cache
    a.cache_init(&second)
    defer a.cache_destroy(&second)
    denied := view.assets[1].ref
    result := a.bundle_install(&view, &second, proc(user: rawptr, ref: a.Ref, bytes: []u8) -> bool {
            return ref != (cast(^a.Ref)user)^
        }, &denied)
    testing.expect_value(t, result, a.Bundle_Error.Content)
    testing.expect_value(t, second.count, 0)
    view.assets[1].bytes[0] ~= 1
    testing.expect_value(t, a.bundle_install(&view, &second), a.Bundle_Error.Integrity)
    testing.expect_value(t, second.count, 0)
}

@(test)
replacing_bundle_root_preserves_asset_records_and_metadata :: proc(t: ^testing.T) {
    cache: a.Cache
    a.cache_init(&cache)
    defer a.cache_destroy(&cache)
    one := [4]u8{1, 2, 3, 4}
    two := [3]u8{5, 6, 7}
    root := [2]u8{8, 9}
    r1, _ := a.cache_put(&cache, one[:])
    r2, _ := a.cache_put(&cache, two[:])
    refs := [2]a.Ref{r1, r2}
    bytes, err := a.bundle_encode(root[:], refs[:], &cache, {epoch = 3, tick = 99, content = 7})
    defer delete(bytes)
    testing.expect_value(t, err, a.Bundle_Error.None)
    before := a.reference(bytes)
    view, _ := a.bundle_decode(bytes, 7)
    sizes := [?]int{1, 70, a.BUNDLE_ROOT_LIMIT}

    for size in sizes {
        replacement := make([]u8, size)
        defer delete(replacement)
        replacement[0] = 42
        converted, result := a.bundle_replace_root(bytes, replacement, 7)
        defer delete(converted)
        testing.expect_value(t, result, a.Bundle_Error.None)
        after, decoded := a.bundle_decode(converted, 7)
        testing.expect_value(t, decoded, a.Bundle_Error.None)
        testing.expect_value(t, after.meta, view.meta)
        testing.expect_value(t, after.count, view.count)
        testing.expect(t, reflect.equal(after.root, replacement, true))

        for asset, i in view.assets[:view.count] {
            testing.expect_value(t, after.assets[i].ref, asset.ref)
            testing.expect(t, reflect.equal(after.assets[i].bytes, asset.bytes, true))
        }

        // Suffix comparison includes canonical reference records as well as payloads.
        suffix := len(bytes) - 96 - len(view.root)
        testing.expect(t, reflect.equal(converted[len(converted) - suffix:], bytes[len(bytes) - suffix:], true))
    }

    testing.expect_value(t, a.reference(bytes), before)

    for mode in 0 ..< 4 {
        bad := make([]u8, len(bytes))
        copy(bad, bytes)
        defer delete(bad)
        replacement := make([]u8, mode == 2 ? a.BUNDLE_ROOT_LIMIT + 1 : 2)
        defer delete(replacement)
        content := u64(7)
        input := replacement

        if mode == 0 {
            input = nil
        }

        if mode == 1 {
            bad[len(bad) - 1] ~= 1
        }

        if mode == 3 {
            content = 8
        }

        original := a.reference(bad)
        out, rejected := a.bundle_replace_root(bad, input, content)
        defer delete(out)
        testing.expect(t, rejected != .None && len(out) == 0)
        testing.expect_value(t, a.reference(bad), original)
    }
}

@(test)
root_conversion_can_explicitly_advance_content_without_changing_assets :: proc(t: ^testing.T) {
    cache: a.Cache
    a.cache_init(&cache)
    defer a.cache_destroy(&cache)
    root := [2]u8{1, 2}
    ref, _ := a.cache_put(&cache, root[:])
    refs := [1]a.Ref{ref}
    old, _ := a.bundle_encode(root[:], refs[:], &cache, {epoch = 2, tick = 30, content = 7})
    defer delete(old)
    out, err := a.bundle_replace_root(old, root[:], 7, target_content = 8)
    defer delete(out)
    testing.expect_value(t, err, a.Bundle_Error.None)
    view, decoded := a.bundle_decode(out, 8)
    testing.expect_value(t, decoded, a.Bundle_Error.None)
    testing.expect_value(t, view.meta.epoch, u64(2))
    testing.expect_value(t, view.meta.tick, u64(30))
    testing.expect(t, a.bundle_has(&view, ref))
    testing.expect(t, reflect.equal(view.assets[0].bytes, root[:], true))
    _, wrong := a.bundle_decode(out, 7)
    testing.expect_value(t, wrong, a.Bundle_Error.Content)
}
