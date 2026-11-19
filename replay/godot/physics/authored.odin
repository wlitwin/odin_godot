package replay_godot_physics

import "core:fmt"
import "core:mem"
import b "godot:box3d"
import a "godot:box3d/authoring"
import ar "godot:box3d/authoring/runtime"
import ga "godot:box3d/godot/authoring"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import bd "godot:box3d/diagnostics"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import ph "godot:replay/physics"
import rgd "godot:replay/godot"

// Owning control state, never copied while live. Its payload has stable metered
// storage; borrowed Session/codec pointers expire only after successful close.
Authored_Session :: struct($S, $C, $A, $E: typeid, $N: int) {
    storage: meter.Storage(Authored_Data(S,C,A,E,N)),
    ready, closing, opening, room_mode: bool,
    content: bd.Digest,
    report: net.Setup_Report,
}

Authored_Data :: struct($S, $C, $A, $E: typeid, $N: int) {
    using room: rgd.Room(S,C,A,E,N),
    codec: ph.Network_Codec(S,C,A,E,N),
    _baked: a.Baked_Scene,
    _built: ar.Built_Scene,
    _checkpoint: r.Complete_Checkpoint(S,net.Net_Event(E)),
}

authored_options :: proc(role: rgd.Session_Role) -> rgd.Session_Options {
    options := rgd.SESSION_OPTIONS
    options.role = role
    options.network = net.physics_config_default()
    return options
}

// initial maps authored logical IDs/native keys into the game's value state.
// It runs synchronously and must not retain the borrowed bake/build pointers.
// Model callback users/permits still need their explicit existing ownership.
authored_open :: proc(
    owned: ^Authored_Session($S,$C,$A,$E,$N),
    source: gd.Object,
    model: net.Model(S,C,A,E,N),
    initial: proc(^a.Baked_Scene,^ar.Built_Scene) -> (S,bool),
    rules: bd.Digest,
    options: rgd.Session_Options,
    profile: u64 = 0,
    ownership: rgd.Session_Ownership = {},
) -> (report: net.Setup_Report) {
    return authored_open_impl(owned,source,model,initial,rules,options,profile,ownership,nil)
}

// Open the same authored world under a provisioned Room. rtc_ice owns the
// borrowed relay credential source, if present, until Room cleanup completes.
authored_room_open :: proc(
    owned: ^Authored_Session($S,$C,$A,$E,$N), source: gd.Object,
    model: net.Model(S,C,A,E,N), initial: proc(^a.Baked_Scene,^ar.Built_Scene) -> (S,bool),
    rules: bd.Digest, options: rgd.Room_Options, rtc_ice: r.Owned_Context = {}, profile:u64=0,
) -> net.Setup_Report {
    opts:=options
    return authored_open_impl(owned,source,model,initial,rules,opts.session,profile,{rtc_ice=rtc_ice},&opts)
}

@(private)
authored_open_impl :: proc(
    owned: ^Authored_Session($S,$C,$A,$E,$N), source: gd.Object,
    model: net.Model(S,C,A,E,N), initial: proc(^a.Baked_Scene,^ar.Built_Scene) -> (S,bool),
    rules: bd.Digest, options: rgd.Session_Options, profile:u64,
    ownership:rgd.Session_Ownership, room_options:^rgd.Room_Options,
) -> (report:net.Setup_Report) {
    if owned == nil { return net.setup_problem(.Invalid_Config,"owner","provide an authored Session owner") }
    if owned.storage.memory != nil || owned.ready || owned.closing {
        return net.setup_problem(.Wrong_Phase,"owner","finish closing the previous authored Session")
    }
    if source == nil || initial == nil || rules == (bd.Digest{}) {
        return net.setup_problem(.Invalid_Model,"authoring","provide a World, initial-state mapping and game rules identity")
    }
    if options.role != .Solo && options.backend != .Enet && options.backend != .Rtc {
        return net.setup_problem(.Invalid_Config,"options.role/backend","choose Solo or a network role with Enet or Rtc")
    }
    if model.complete_codec.catalog != nil || model.complete_codec.encode != nil {
        return net.setup_problem(.Invalid_Model,"model.complete_codec","the authored owner supplies its own complete physics codec")
    }
    if !r.owner_is_nil(ownership.allocator.owner) || !r.owner_is_nil(ownership.container.owner) || ownership.allocation_base != nil {
        return net.setup_problem(.Invalid_Model,"ownership","the authored owner supplies allocator/container storage; pass only additional callback contexts")
    }
    complete := false
    owned.room_mode = room_options != nil
    owned.opening = true
    defer {
        owned.opening = false
        if !complete {
            cleanup := authored_close(owned)
            if cleanup != .None { report.cleanup_error = cleanup }
        }
        owned.report = report
    }
    if status := meter.storage_open(&owned.storage,bg.service_get(),bg.CATEGORY_REPLAY_PROVIDER); status != bg.OK {
        return net.setup_problem(.Capacity,"storage.open",fmt.tprintf("managed storage could not open (%v)",status))
    }
    data := owned.storage.data
    allocator := meter.allocator(owned.storage.memory)
    image_owner := ph.Owner_Context{owner=owned.storage.allocator_owner,allocator_data=allocator.data}
    codec_owner, cs := meter.storage_bind(&owned.storage,&data.codec)
    if cs != bg.OK { return net.setup_problem(.Invalid_Model,"codec.owner",fmt.tprintf("cannot bind codec storage (%v)",cs)) }
    session_owner: bg.Owner
    // Room creates the lease for its embedded Session during room_open_complete.
    if !owned.room_mode {
        status: bg.Status
        session_owner,status = meter.storage_bind(&owned.storage,&data.session)
        if status != bg.OK { return net.setup_problem(.Invalid_Model,"session.owner",fmt.tprintf("cannot bind Session storage (%v)",status)) }
    }

    extracted: ga.Diagnostic
    data._baked, extracted = ga.extract(source,allocator)
    defer ga.diagnostic_destroy(&extracted)
    if owned.closing { return net.setup_problem(.Wrong_Phase,"owner.cancelled","close was requested during initialization") }
    if extracted.error != .None {
        message := len(extracted.authoring_errors_json)>0 ? string(extracted.authoring_errors_json) : fmt.tprintf("%v / %v at %s",extracted.error,extracted.bake_diagnostic.error,extracted.bake_diagnostic.field)
        return net.setup_problem(.Invalid_Config,"authoring.extract",message)
    }
    owned.content = data._baked.content_hash
    config, error := ph.authoring_config(&data._baked)
    if error != .None { return net.setup_problem(.Invalid_Config,"authoring.config",fmt.tprintf("%v",error)) }
    selected_profile := profile == 0 ? a.content_id64(&data._baked) : profile
    problem: a.Diagnostic
    data._built, problem = ar.build(&data._baked,selected_profile)
    if problem.error != .None { return net.setup_problem(.Invalid_Config,problem.field,fmt.tprintf("%v (%v)",problem.error,problem.native_status)) }
    game, valid := initial(&data._baked,&data._built)
    if owned.closing { return net.setup_problem(.Wrong_Phase,"owner.cancelled","close was requested during initial-state mapping") }
    if !valid { return net.setup_problem(.Invalid_Model,"initial","the game rejected the authored body/shape mappings") }
    if result := ph.network_codec_init(&data.codec,&data._built.catalog,config,rules,allocator,
        image_owner,{owner=codec_owner,user_data=&data.codec}); result != .None {
        return net.setup_problem(result,"codec.init","could not initialize complete physics encoding")
    }
    effective_model := model
    effective_model.complete_state = true
    effective_model.complete_codec = data.codec.value
    effective_owner := ownership
    effective_owner.allocator = {owned.storage.allocator_owner,allocator.data}
    effective_owner.container = {session_owner,&data.session}
    effective_owner.allocation_base = data
    effective_owner.allocation_bytes = size_of(data^)
    result: net.Error
    if owned.room_mode || options.role == .Solo || options.role == .Host || options.role == .Server {
        cp_error: r.Error
        data._checkpoint, cp_error = ph.authoring_checkpoint(&data._built,config,r.Frame(S){state=game},net.Net_Event(E),epoch=options.network.epoch,allocator=allocator,ownership=image_owner)
        if cp_error != .None { return net.setup_problem(.Invalid_Checkpoint,"initial.checkpoint",fmt.tprintf("%v",cp_error)) }
        if owned.room_mode {
            owner,status:=meter.storage_bind(&owned.storage,&data.room)
            if status!=bg.OK {return net.setup_problem(.Invalid_Model,"room.owner","cannot bind Room storage")}
            result=rgd.room_open_complete(&data.room,&data._checkpoint,effective_model,room_options^,allocator,{
                allocator=effective_owner.allocator,container={owner,&data.room},rtc_ice=ownership.rtc_ice,
                allocation_base=data,allocation_bytes=size_of(data^),
            },&report)
        } else {
            result = rgd.session_open_complete(&data.session,&data._checkpoint,effective_model,options,allocator,effective_owner)
        }
    } else {
        result = rgd.session_open(&data.session,r.Frame(S){},effective_model,options,allocator,effective_owner)
    }
    if owned.closing { return net.setup_problem(.Wrong_Phase,"owner.cancelled","close was requested during Session initialization") }
    if result != .None {
        if owned.room_mode {return report}
        report = data.session.setup_report
        net.setup_finish(&report,result,"session.open","could not open the complete physics Session")
        return
    }
    if error := r.complete_checkpoint_destroy(&data._checkpoint); error != .None {
        return net.setup_problem(.Wrong_Phase,"initial.release",fmt.tprintf("initial checkpoint remains owned (%v)",error))
    }
    if status := ar.built_destroy(&data._built); status != .Ok {
        return net.setup_problem(.Wrong_Phase,"authoring.release",fmt.tprintf("initial native world remains owned (%v)",status))
    }
    a.destroy(&data._baked)
    owned.ready = true
    complete = true
    return {}
}

authored_session :: proc(owned: ^Authored_Session($S,$C,$A,$E,$N)) -> ^rgd.Session(S,C,A,E,N) {
    data := authored_data(owned)
    return data == nil ? nil : &data.session
}

authored_allocator :: proc(owned: ^Authored_Session($S,$C,$A,$E,$N)) -> mem.Allocator {
    if owned == nil || owned.storage.memory == nil || r.owner_access(owned.storage.allocator_owner) != .None { return {} }
    return meter.allocator(owned.storage.memory)
}

// Guarded borrowed access for advanced presentation/diagnostic composition.
authored_data :: proc(owned: ^Authored_Session($S,$C,$A,$E,$N)) -> ^Authored_Data(S,C,A,E,N) {
    if owned == nil || r.owner_access(owned.storage.allocator_owner) != .None { return nil }
    if !owned.ready || owned.closing { return nil }
    return owned.storage.data
}

// A managed temporary checkpoint. The pointer is borrowed until release, the
// next capture, or close. Clone explicitly for an independently owned snapshot.
authored_checkpoint :: proc(owned: ^Authored_Session($S,$C,$A,$E,$N), tick: u64) -> (^r.Complete_Checkpoint(S,net.Net_Event(E)),net.Error) {
    data := authored_data(owned)
    if data == nil { return nil,.Wrong_Phase }
    if error := authored_checkpoint_release(owned); error != .None { return nil,error }
    checkpoint,error := rgd.session_checkpoint(&data.session,tick)
    if error != .None { return nil,error }
    data._checkpoint = checkpoint
    return &data._checkpoint,.None
}

authored_checkpoint_release :: proc(owned: ^Authored_Session($S,$C,$A,$E,$N)) -> net.Error {
    if owned == nil { return .None }
    if r.owner_access(owned.storage.allocator_owner) != .None { return .Wrong_Phase }
    if owned.storage.data == nil { return .None }
    return r.complete_checkpoint_destroy(&owned.storage.data._checkpoint) == .None ? .None : .Wrong_Phase
}

authored_close :: proc(owned: ^Authored_Session($S,$C,$A,$E,$N)) -> net.Error {
    if owned == nil { return .None }
    if meter.storage_check(&owned.storage) != bg.OK { return .Wrong_Phase }
    if owned.opening {
        owned.closing = true
        owned.ready = false
        return .Wrong_Phase
    }
    owned.closing = true
    owned.ready = false
    if data := owned.storage.data; data != nil {
        if owned.room_mode {
            if error:=rgd.room_try_close(&data.room); error!=.None {return authored_close_error(owned,"room.close",error)}
        } else if error:=rgd.session_close(&data.session); error!=.None {return authored_close_error(owned,"session.close",error)}
        if r.complete_checkpoint_destroy(&data._checkpoint) != .None { return authored_close_error(owned,"initial.close",.Wrong_Phase) }
        if error := ph.network_codec_destroy(&data.codec); error != .None { return authored_close_error(owned,"codec.close",error) }
        if ar.built_destroy(&data._built) != .Ok { return authored_close_error(owned,"authoring.close",.Wrong_Phase) }
        a.destroy(&data._baked)
    }
    if status := meter.storage_close(&owned.storage); status != bg.OK {
        owned.report = net.setup_problem(.Wrong_Phase,"storage.close",fmt.tprintf("ownership remains retained (%v)",status))
        return .Wrong_Phase
    }
    owned^ = {}
    return .None
}

@(private)
authored_close_error :: proc(owned: ^Authored_Session($S,$C,$A,$E,$N), field: string, error: net.Error) -> net.Error {
    owned.report = net.setup_problem(error,field,"cleanup remains pending; retry close after releasing the dependent operation")
    return error
}
