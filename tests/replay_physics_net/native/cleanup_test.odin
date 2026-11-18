package replay_physics_native_net_test

import "core:testing"
import b "godot:box3d"
import bg "godot:box3d/godot"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"
import f "../fixture"

// Controlled ownership callbacks; the catalog and schema allocations are real.
Cleanup_Owner :: struct {
    references: u32,
    deny_retain, deny_drop: bool,
}
cleanup_check :: proc "c" (user: rawptr, _: u32) -> bg.Status {
    return (cast(^Cleanup_Owner)user).references > 0 ? bg.OK : bg.INVALID_HANDLE
}
cleanup_retain :: proc "c" (user: rawptr) -> bg.Status {
    owner := cast(^Cleanup_Owner)user
    if owner.deny_retain { return bg.CAPACITY }
    owner.references += 1
    return bg.OK
}
cleanup_drop :: proc "c" (user: rawptr) -> bg.Status {
    owner := cast(^Cleanup_Owner)user
    if owner.deny_drop { return bg.CAPACITY }
    owner.references -= 1
    return bg.OK
}
cleanup_owner :: proc(value: ^Cleanup_Owner) -> r.Owner {
    if r.owner_realm() == 0 { assert(r.owner_realm_install(73) == .None) }
    value.references = 1
    return {user = value, realm = r.owner_realm(), context_caps = bg.MANAGED_DATA | bg.INDEPENDENT_CONTEXT,
        check = cleanup_check, retain = cleanup_retain, drop = cleanup_drop}
}

@(test)
codec_final_drops_preserve_each_remaining_owner_for_retry :: proc(t: ^testing.T) {
    catalog := catalog_make(t)
    defer b.recovery_catalog_destroy(&catalog)
    codec: ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2)
    allocator_host, context_host: Cleanup_Owner
    allocator_owner, context_owner := cleanup_owner(&allocator_host), cleanup_owner(&context_host)
    config := config_make(&catalog, 4)
    testing.expect_value(t, ph.network_codec_init(&codec, &catalog, config, network_rules(),
        ownership = {owner = allocator_owner, allocator_data = context.allocator.data}, context_ownership = {owner = context_owner, user_data = &codec}), net.Error.None)
    testing.expect_value(t, allocator_host.references, 2)
    testing.expect_value(t, context_host.references, 2)
    allocator_host.deny_drop = true
    testing.expect_value(t, ph.network_codec_destroy(&codec), net.Error.Wrong_Phase)
    testing.expect(t, codec.closing && !codec.ready && codec.catalog._handle == nil)
    testing.expect_value(t, allocator_host.references, 2)
    testing.expect_value(t, context_host.references, 2)
    testing.expect_value(t, ph.network_codec_init(&codec, &catalog, config, network_rules()), net.Error.Invalid_Model)
    allocator_host.deny_drop = false
    context_host.deny_drop = true
    testing.expect_value(t, ph.network_codec_destroy(&codec), net.Error.Wrong_Phase)
    testing.expect_value(t, allocator_host.references, 1)
    testing.expect_value(t, context_host.references, 2)
    testing.expect(t, codec.closing && r.owner_is_nil(codec.ownership.owner) && !r.owner_is_nil(codec.context_ownership.owner))
    context_host.deny_drop = false
    testing.expect_value(t, ph.network_codec_destroy(&codec), net.Error.None)
    testing.expect_value(t, ph.network_codec_destroy(&codec), net.Error.None)
    testing.expect_value(t, context_host.references, 1)
    testing.expect_value(t, r.owner_drop(&allocator_owner), r.Error.None)
    testing.expect_value(t, r.owner_drop(&context_owner), r.Error.None)
}

@(test)
codec_init_rollback_keeps_a_refused_context_drop :: proc(t: ^testing.T) {
    catalog := catalog_make(t)
    defer b.recovery_catalog_destroy(&catalog)
    codec: ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2)
    allocator_host, context_host: Cleanup_Owner
    allocator_owner, context_owner := cleanup_owner(&allocator_host), cleanup_owner(&context_host)
    allocator_host.deny_retain = true
    context_host.deny_drop = true
    testing.expect_value(t, ph.network_codec_init(&codec, &catalog, config_make(&catalog, 4), network_rules(),
        ownership = {owner = allocator_owner, allocator_data = context.allocator.data}, context_ownership = {owner = context_owner, user_data = &codec}), net.Error.Wrong_Phase)
    testing.expect(t, codec.closing && codec.cleanup_error == .Wrong_Phase)
    testing.expect_value(t, context_host.references, 2)
    testing.expect_value(t, allocator_host.references, 1)
    context_host.deny_drop = false
    testing.expect_value(t, ph.network_codec_destroy(&codec), net.Error.None)
    testing.expect_value(t, context_host.references, 1)
    testing.expect_value(t, r.owner_drop(&allocator_owner), r.Error.None)
    testing.expect_value(t, r.owner_drop(&context_owner), r.Error.None)
}

@(test)
codec_void_release_records_a_pending_drop_and_stops_new_acquires :: proc(t: ^testing.T) {
    catalog := catalog_make(t)
    defer b.recovery_catalog_destroy(&catalog)
    codec: ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2)
    allocator_host, context_host: Cleanup_Owner
    allocator_owner, context_owner := cleanup_owner(&allocator_host), cleanup_owner(&context_host)
    testing.expect_value(t, ph.network_codec_init(&codec, &catalog, config_make(&catalog, 4), network_rules(),
        ownership = {owner = allocator_owner, allocator_data = context.allocator.data}, context_ownership = {owner = context_owner, user_data = &codec}), net.Error.None)
    value := codec.value
    testing.expect_value(t, value.acquire(value.catalog), net.Error.None)
    testing.expect_value(t, context_host.references, 3)
    context_host.deny_drop = true
    value.drop(value.catalog)
    testing.expect_value(t, codec.runtime_leases, 0)
    testing.expect_value(t, codec.pending_context_drops, 1)
    testing.expect_value(t, value.acquire(value.catalog), net.Error.Wrong_Phase)
    testing.expect_value(t, ph.network_codec_destroy(&codec), net.Error.Wrong_Phase)
    testing.expect_value(t, context_host.references, 3)
    context_host.deny_drop = false
    testing.expect_value(t, ph.network_codec_destroy(&codec), net.Error.None)
    testing.expect_value(t, context_host.references, 1)
    testing.expect_value(t, allocator_host.references, 1)
    testing.expect_value(t, r.owner_drop(&allocator_owner), r.Error.None)
    testing.expect_value(t, r.owner_drop(&context_owner), r.Error.None)
}
