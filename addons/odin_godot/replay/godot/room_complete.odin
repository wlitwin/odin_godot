package replay_godot

import "core:mem"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import r "godot:replay"
import net "godot:replay/net"
import auth "godot:replay/authority"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import gd "godot:godot"

Room_Ownership :: struct {
    allocator, container, rtc_ice: r.Owned_Context,
    allocation_base:               rawptr,
    allocation_bytes:              u64,
}

@(private)
room_managed :: proc(room: ^Room($S, $C, $A, $E, $N)) -> bool {
    return !r.owner_is_nil(room.ownership.container.owner)
}

// Complete physics retains its actual initial image and callback contexts.
// This first managed Room profile supports creator hosting/following/rejoin;
// authority takeover and durable publication remain explicit unsupported modes.
room_open_complete :: proc(
    room: ^Room($S, $C, $A, $E, $N),
    initial: ^r.Complete_Checkpoint(S, net.Net_Event(E)),
    model: net.Model(S, C, A, E, N),
    options: Room_Options,
    allocator := context.allocator,
    ownership: Room_Ownership = {},
) -> net.Error {
    if room == nil ||
       room.ready ||
       room.cleanup ||
       initial == nil ||
       !model.complete_state ||
       r.complete_checkpoint_identity(initial) == 0 {
        return .Invalid_Config
    }

    if options.automatic_successor ||
       options.successor != (auth.Identity{}) ||
       options.checkpoint_interval_ms != 0 ||
       options.restore_published ||
       options.preparation_ready != nil ||
       options.preparation_user != nil ||
       options.checkpoint_assets.collect != nil ||
       options.session.replication.accept_checkpoints {
        return .Invalid_Config
    }

    if r.owner_is_nil(ownership.allocator.owner) ||
       r.owner_is_nil(ownership.container.owner) ||
       r.owner_contexts_check(
           {owner = ownership.allocator.owner, owner_allocator_data = ownership.allocator.data},
           allocator,
       ) !=
           .None ||
       r.owned_context_access(ownership.container, room, true, .Execute) != .None ||
       net.model_ownership_check(model, true) != .None {
        return .Invalid_Model
    }

    if options.session.rtc.ice_source != nil &&
       r.owned_context_access(ownership.rtc_ice, options.session.rtc.ice_user, true, .Execute) != .None {
        return .Invalid_Model
    }

    room.ownership = ownership
    room.allocator = allocator
    room.model = model
    committed := false

    defer if !committed {
        _ = room_try_close(room)
    }

    // RPC schemas have many independently owned metadata allocations. Keep their
    // bookkeeping in a distinct real Core context; all contexts still charge the
    // same domain ledger/admission limit. The physics allocator remains unchanged.
    rpc_meter, status := meter.create(bg.service_get(), bg.CATEGORY_REPLAY_CORE)

    if status != bg.OK {
        return .Capacity
    }

    room.rpc_meter = rpc_meter
    room.rpc_allocator = meter.allocator(rpc_meter)
    owners := [?]r.Owner {
        ownership.allocator.owner,
        ownership.container.owner,
        ownership.rtc_ice.owner,
        model.complete_codec.ownership.data_context.owner,
    }

    if r.owner_retains_acquire(&room.retained, owners[:]) != .None ||
       net.model_ownership_retain(&room.retained, model) != .None {
        return .Invalid_Model
    }

    if model.complete_codec.acquire != nil {
        if error := model.complete_codec.acquire(model.complete_codec.catalog); error != .None {
            return error
        }

        room.codec_retained = true
    }

    copied, error := r.complete_checkpoint_clone(initial, allocator)

    if error != .None {
        return .Invalid_Frame
    }

    room.initial_complete = copied
    room.complete_initial = true
    session_owner, se := session_block_owner(
        allocator,
        ownership.allocation_base,
        ownership.allocation_bytes,
        &room.session,
        size_of(room.session),
    )

    if se != .None {
        return se
    }

    room.aliases[0] = session_owner
    authorization, ae := session_block_owner(
        allocator,
        ownership.allocation_base,
        ownership.allocation_bytes,
        &room.rtc_authorization,
        size_of(room.rtc_authorization),
    )

    if ae != .None {
        return ae
    }

    room.aliases[1] = authorization

    if opened := room_open(room, initial.frame, model, options); opened != .None {
        return opened
    }

    committed = true
    return .None
}

@(private)
room_session_open :: proc(room: ^Room($S, $C, $A, $E, $N), options: Session_Options) -> net.Error {
    if !room_managed(room) {
        return session_open(&room.session, room.initial, room.model, options)
    }

    ownership := Session_Ownership {
        allocator         = room.ownership.allocator,
        container         = room.aliases[0],
        permit            = room.ownership.container,
        identity          = room.ownership.container,
        rtc_ice           = room.ownership.rtc_ice,
        rtc_authorization = room.aliases[1],
        allocation_base   = room.ownership.allocation_base,
        allocation_bytes  = room.ownership.allocation_bytes,
    }

    if options.role == .Host || options.role == .Server {
        return session_open_complete(
            &room.session,
            &room.initial_complete,
            room.model,
            options,
            allocator = room.allocator,
            ownership = ownership,
        )
    }

    return session_open(
        &room.session,
        room.initial,
        room.model,
        options,
        allocator = room.allocator,
        ownership = ownership,
    )
}

@(private)
room_redirect :: proc(room: ^Room($S, $C, $A, $E, $N), target: ^Migration_Transport) -> net.Error {
    if !room_managed(room) {
        return session_redirect(&room.session, &room.lease, target)
    }

    // Preserve the same phase-aware callback and its exact retained data owner.
    // A lease-only callback has different user data and cannot borrow this owner.
    gate := room_permit(room)
    return session_redirect(
        &room.session,
        &room.lease,
        target,
        permit_context = room.ownership.container,
        permit = &gate,
    )
}

// On decline the caller still owns the actual Room/Runtime and can retry. All
// retained data/code contexts stay live until their final typed operation ends.
room_try_close :: proc(room: ^Room($S, $C, $A, $E, $N)) -> net.Error {
    if room == nil {
        return .Invalid_Config
    }

    if !room_managed(room) {
        room_close_legacy(room)
        return .None
    }

    if r.owned_context_access(room.ownership.container, room, true) != .None {
        return .Invalid_Model
    }

    context.allocator = room.allocator

    if !room.cleanup {
        if error := session_close(&room.session); error != .None {
            return error
        }

        if r.complete_checkpoint_destroy(&room.initial_complete) != .None {
            return .Wrong_Phase
        }

        net.checkpoint_codec_destroy(&room.checkpoint_codec)
        room_restore_destroy(&room.restore)
        room_save_destroy(&room.save)
        auth.rpc_client_destroy(&room.rpc)
        auth.prepared_destroy(&room.prepared)
        auth.prepared_destroy(&room.candidate)

        if room.rpc_meter != nil && meter.destroy(&room.rpc_meter) != bg.OK {
            return .Invalid_Model
        }

        tr.close(&room.control_wire)

        if room.options.control_tls != nil {
            gd.release_ref(room.options.control_tls)
        }

        delete(room.options.coordinator, room.allocator)
        delete(room.options.session.rtc.url, room.allocator)
        delete(room.options.session.rtc.ice_json, room.allocator)

        if room.codec_retained && room.model.complete_codec.drop != nil {
            room.model.complete_codec.drop(room.model.complete_codec.catalog)
            room.codec_retained = false
        }

        room.cleanup = true
        room.ready = false
    }

    for &alias in room.aliases {
        if r.owner_drop(&alias.owner) != .None {
            return .Invalid_Model
        }
    }

    if r.owner_retains_drop(&room.retained) != .None {
        return .Invalid_Model
    }

    room^ = {}
    return .None
}
