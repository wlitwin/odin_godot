package replay_recovery_test

import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import tf "godot:replay/transfer"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"

// Pure hook fixture for admission and cleanup. Actual SDK generation/code pins
// are exercised separately by tests/box3d_modules/replay/runner.
Admission_Owner :: struct {
    active:                     bool,
    refs, checks, budget_calls: int,
}

admission_owner :: proc(h: ^Admission_Owner) -> r.Owner {
    return {
        user = h,
        realm = 1729,
        context_caps = bg.MANAGED_DATA | bg.INDEPENDENT_CONTEXT,
        check = proc "c" (user: rawptr, _: u32) -> bg.Status {
            h := cast(^Admission_Owner)user
            h.checks += 1
            return h.active ? bg.OK : bg.INVALID_HANDLE
        },
        retain = proc "c" (user: rawptr) -> bg.Status {
            h := cast(^Admission_Owner)user
            h.refs += 1
            return bg.OK
        },
        drop = proc "c" (user: rawptr) -> bg.Status {
            h := cast(^Admission_Owner)user
            h.refs -= 1
            return bg.OK
        },
    }
}

admission_meter :: proc(h: ^Admission_Owner) -> ^meter.Context {
    service := bg.Service {
        realm = 1729,
        user = h,
        request_totals = proc "c" (_: rawptr, out: ^bg.Request_Totals) -> bg.Status {
            out^ = {}
            return bg.OK
        },
        legacy_extra = proc "c" (_: rawptr, _: u64, _: u64, extra: u64, out: ^u64) -> bg.Status {
            out^ = extra
            return bg.OK
        },
        account = proc "c" (_: rawptr, _: u32, _: u64, _: u64) -> bg.Status {
            return bg.OK
        },
    }
    m, status := meter.create(service, bg.CATEGORY_REPLAY_CODEC)
    assert(status == bg.OK)
    return m
}

@(test)
declared_codec_and_transfer_owners_require_complete_exact_live_bindings :: proc(t: ^testing.T) {
    assert(r.owner_realm_install(1729) == .None)
    h := Admission_Owner {
        active = true,
        refs   = 1,
    }
    owner := admission_owner(&h)
    m := admission_meter(&h)
    defer assert(meter.destroy(&m) == bg.OK)
    alloc := meter.allocator(m)
    codec := new(net.Checkpoint_Codec, alloc)
    defer free(codec, alloc)
    sender := new(tf.Sender, alloc)
    defer free(sender, alloc)
    wire_data, wrong_data: u64
    owned := net.Container_Ownership {
        allocator    = {owner, alloc.data},
        data_context = {owner, codec},
    }

    missing := owned
    missing.allocator = {}
    testing.expect_value(
        t,
        net.checkpoint_codec_init(codec, World, Control, Action, Event, 2, allocator = alloc, ownership = missing),
        net.Error.Invalid_Model,
    )
    missing = owned
    missing.data_context = {}
    testing.expect_value(
        t,
        net.checkpoint_codec_init(codec, World, Control, Action, Event, 2, allocator = alloc, ownership = missing),
        net.Error.Invalid_Model,
    )
    wrong := owned
    wrong.data_context.data = &wrong_data
    testing.expect_value(
        t,
        net.checkpoint_codec_init(codec, World, Control, Action, Event, 2, allocator = alloc, ownership = wrong),
        net.Error.Invalid_Model,
    )
    wrong = owned
    wrong.data_context.owner.realm += 1
    checks := h.checks
    testing.expect_value(
        t,
        net.checkpoint_codec_init(codec, World, Control, Action, Event, 2, allocator = alloc, ownership = wrong),
        net.Error.Invalid_Model,
    )
    testing.expect(
        t,
        h.checks == checks + 1,
        "the allocator is checked, but a foreign realm never invokes its owner callback",
    )
    h.active = false
    testing.expect_value(
        t,
        net.checkpoint_codec_init(codec, World, Control, Action, Event, 2, allocator = alloc, ownership = owned),
        net.Error.Invalid_Model,
    )
    h.active = true
    testing.expect(t, !codec.ready && h.refs == 1)

    testing.expect_value(
        t,
        net.checkpoint_codec_init(codec, World, Control, Action, Event, 2, allocator = alloc, ownership = owned),
        net.Error.None,
    )
    refs := h.refs
    h.active = false
    _, _, ready := net.checkpoint_frame_layout(codec)
    testing.expect(t, !ready)
    testing.expect_value(t, net.checkpoint_codec_destroy(codec), net.Error.Invalid_Model)
    testing.expect(t, codec.ready && h.refs == refs, "expired access preserves the owned cache for cleanup retry")
    h.active = true
    testing.expect_value(t, net.checkpoint_codec_destroy(codec), net.Error.None)
    testing.expect_value(t, h.refs, 1)

    transfer := tf.Ownership {
        allocator = {owner, alloc.data},
        container = {owner, sender},
        wire      = {owner, &wire_data},
    }
    incomplete := transfer
    incomplete.container = {}
    testing.expect_value(
        t,
        tf.sender_init(
            sender,
            SCOPE,
            2,
            {user = &wire_data},
            archive_kind = net.CHECKPOINT_KIND,
            allocator = alloc,
            ownership = incomplete,
        ),
        tf.Error.Invalid_Config,
    )
    incomplete = transfer
    incomplete.wire = {}
    testing.expect_value(
        t,
        tf.sender_init(
            sender,
            SCOPE,
            2,
            {user = &wire_data},
            archive_kind = net.CHECKPOINT_KIND,
            allocator = alloc,
            ownership = incomplete,
        ),
        tf.Error.Invalid_Config,
    )
    incomplete = {
        wire = {owner, &wire_data},
    }
    testing.expect_value(
        t,
        tf.sender_init(
            sender,
            SCOPE,
            2,
            {user = &wire_data},
            archive_kind = net.CHECKPOINT_KIND,
            allocator = alloc,
            ownership = incomplete,
        ),
        tf.Error.Invalid_Config,
    )
    testing.expect(t, !sender.ready && h.refs == 1)
    testing.expect_value(
        t,
        tf.sender_init(
            sender,
            SCOPE,
            2,
            {user = &wire_data},
            archive_kind = net.CHECKPOINT_KIND,
            allocator = alloc,
            ownership = transfer,
        ),
        tf.Error.None,
    )
    refs = h.refs
    h.active = false
    testing.expect_value(t, tf.sender_update(sender, 1), tf.Error.Invalid_Config)
    testing.expect_value(t, tf.sender_destroy(sender), tf.Error.Invalid_Config)
    testing.expect(t, sender.ready && h.refs == refs)
    h.active = true
    sender.ownership.wire.data = &wrong_data
    testing.expect_value(t, tf.sender_update(sender, 1), tf.Error.Invalid_Config)
    sender.ownership.wire = transfer.wire
    sender.ownership.wire.owner.realm += 1
    testing.expect_value(t, tf.sender_update(sender, 1), tf.Error.Invalid_Config)
    sender.ownership.wire = transfer.wire
    testing.expect_value(t, tf.sender_destroy(sender), tf.Error.None)
    testing.expect_value(t, h.refs, 1)

    value_receiver: Receiver
    receiver_owned := rec.Receiver_Ownership {
        model = {owner, &value_receiver.model},
    }
    testing.expect_value(
        t,
        rec.receiver_init(&value_receiver, SCOPE, 1, {}, model(), allocator = alloc, ownership = receiver_owned),
        rec.Error.Invalid_Config,
    )
    receiver_owned.transfer = {
        allocator = {owner, alloc.data},
        container = {owner, &value_receiver.transfer},
        accept    = {owner, &value_receiver},
    }
    testing.expect_value(
        t,
        rec.receiver_init(&value_receiver, SCOPE, 1, {}, model(), allocator = alloc, ownership = receiver_owned),
        rec.Error.Invalid_Config,
    )
    testing.expect(
        t,
        !value_receiver.ready && h.refs == 1,
        "a declared receiver owner also requires the transfer and cache owners",
    )

    when #config(BOX3D_REQUIRE_DOMAIN, false) {
        // Complete recovery must reject an unmanaged container before invoking
        // catalog/budget code, even though the codec's own owners are admitted.
        complete_model := model()
        complete_model.complete_state = true
        complete_model.complete_codec.catalog = &h
        complete_model.complete_codec.ownership = {
            allocator    = {owner, alloc.data},
            data_context = {owner, &h},
        }
        complete_model.complete_codec.transfer_budget = {
            user = &h,
            reserve = proc(user: rawptr, _: u64) -> bool {
                h := cast(^Admission_Owner)user
                h.budget_calls += 1
                return true
            },
            release = proc(_: rawptr, _: u64) {},
        }
        testing.expect_value(t, net.model_ownership_check(complete_model, false), net.Error.None)
        receiver: Receiver
        testing.expect_value(t, rec.receiver_init(&receiver, SCOPE, 1, {}, complete_model), rec.Error.Invalid_Config)
        testing.expect(t, !receiver.ready)
        plain: rec.Sender
        testing.expect_value(t, rec.sender_init(&plain, SCOPE, 2, {}), rec.Error.None)
        checkpoint: Checkpoint
        testing.expect_value(t, rec.sender_publish(&plain, &checkpoint, complete_model, 1), rec.Error.Invalid_Config)
        testing.expect_value(t, rec.sender_destroy(&plain), rec.Error.None)
        cache: net.Checkpoint_Codec
        testing.expect_value(t, net.checkpoint_codec_init(&cache, World, Control, Action, Event, 2), net.Error.None)
        _, encode_error := net.checkpoint_encode(&checkpoint, complete_model, codec = &cache)
        testing.expect_value(t, encode_error, net.Error.Invalid_Model)
        testing.expect_value(
            t,
            net.checkpoint_decode(&checkpoint, nil, complete_model, 1, codec = &cache),
            net.Error.Invalid_Model,
        )
        testing.expect_value(t, net.checkpoint_codec_destroy(&cache), net.Error.None)
        testing.expect_value(t, h.budget_calls, 0)
    }
}

@(test)
strict_complete_link_cannot_start_backup_in_an_unmanaged_value_container :: proc(t: ^testing.T) {
    when #config(BOX3D_REQUIRE_DOMAIN, false) {
        f: Link_Fixture
        link_fixture_init(&f)
        defer link_fixture_destroy(&f)

        for _ in 0 ..< 60 {
            link_fixture_step(&f)
        }

        connection, live := net.server_seat_connection(&f.server, 2)
        assert(live)
        // No step/capture uses this marker: admission must reject before any
        // complete-state operation can run in the unmanaged value-only fixture.
        f.server.model.complete_state = true
        error := rec.link_target(&f.links[0], &f.server, connection.peer)
        f.server.model.complete_state = false
        testing.expect_value(t, error, net.Error.Invalid_Model)
        testing.expect(t, !f.links[0].publish_codec.ready && !f.links[0].outgoing.ready)
    }
}
