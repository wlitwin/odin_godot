package kit_godot_physics

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
import p "godot:kit/physics"
import k "godot:kit/sim"
import n "godot:kit/net"
import s "godot:kit/session"
import ng "godot:kit/netgd"

Report :: struct {
    error, cleanup_error: k.World_Error,
    stage: string, // library-owned static label
    detail: [512]u8,
    count: u16,
    truncated: bool,
}

Authored_World :: struct($Side,$Control,$Proxy,$User: typeid) {
    storage: meter.Storage(Authored_Data(Side,Control,Proxy,User)),
    opening, closing, closing_active, user_cleaned: bool,
    cleanup_user: proc(^User,mem.Allocator) -> k.World_Error,
    report: Report,
}

Authored_Data :: struct($Side,$Control,$Proxy,$User: typeid) {
    using game: User,
    allocator: mem.Allocator,
    wire: ng.Session_Wire,
    ses: s.Session,
    lane: k.Lane,
    physics: p.Instance(Side),
    network: p.Network(Side),
    controls: p.Typed_Codec(Control),
    proxy_codec: p.Typed_Codec(Proxy),
    baked: a.Baked_Scene,
    built: ar.Built_Scene,
    content_hash: bd.Digest,
    closing, lane_ready: bool,
    _wire_ready: bool,
    _checkpoint: k.World_Checkpoint,
    _config: p.Config,
    _network_owner, _control_owner, _proxy_owner: p.SDK_User_Owner,
}

@(private)
problem :: proc(error: k.World_Error, stage, detail: string) -> (report: Report) {
    report.error = error
    report.stage = stage
    count := min(len(detail),len(report.detail))
    if count < len(detail) {
        for count > 0 && detail[count] & 0xc0 == 0x80 { count -= 1 }
        report.truncated = true
    }
    report.count = u16(copy(report.detail[:],transmute([]u8)detail[:count]))
    return
}

describe :: proc(report: ^Report) -> string {
    if report == nil || report.error == .Ok { return "" }
    return fmt.tprintf("%s: %s (%v; cleanup %v)%s",report.stage,string(report.detail[:report.count]),report.error,report.cleanup_error,report.truncated ? " [truncated]" : "")
}

@(private)
user_owner :: proc(storage: ^meter.Storage($T), user: ^$U, live: bool = false) -> (p.SDK_User_Owner,bg.Status) {
    owner,status := meter.storage_bind(storage,user,live)
    if status != bg.OK { return {},status }
    return {owner=owner,user=user,allocation_base=storage.data,allocation_size=size_of(T)},bg.OK
}

// Captures content and prepares the standard owned wire/session storage. The
// game still selects transports, binds its handlers, chooses a roster and sets
// its lane model. Optional cleanup_user owns only application-specific data.
authored_open :: proc {authored_open_default,authored_open_custom}

@(private)
authored_open_default :: proc(owned: ^Authored_World($Side,$Control,$Proxy,$User),source:gd.Object,profile:u64=0)->Report {
    cleanup: proc(^User,mem.Allocator)->k.World_Error
    return authored_open_custom(owned,source,cleanup,profile)
}

@(private)
authored_open_custom :: proc(
    owned: ^Authored_World($Side,$Control,$Proxy,$User), source: gd.Object,
    cleanup_user: proc(^User,mem.Allocator) -> k.World_Error,
    profile: u64 = 0,
) -> (report: Report) {
    if owned == nil || source == nil { return problem(.Invalid,"owner.open","provide an owner and authored World") }
    if owned.storage.memory != nil || owned.closing || owned.opening { return problem(.Busy,"owner.open","finish closing the previous world") }
    owned.opening = true
    owned.cleanup_user = cleanup_user
    complete := false
    defer {
        owned.opening = false
        if !complete { report.cleanup_error = authored_close(owned) }
        owned.report = report
    }
    if status := meter.storage_open(&owned.storage,bg.service_get(),bg.CATEGORY_KIT_CORE,true); status != bg.OK {
        return problem(.Allocation_Failed,"storage.open",fmt.tprintf("managed storage refused (%v)",status))
    }
    data := owned.storage.data
    data.allocator = meter.allocator(owned.storage.memory)
    data.ses.allocator = data.allocator
    author,as := user_owner(&owned.storage,data)
    provider,ps := user_owner(&owned.storage,&data.physics)
    if as != bg.OK || ps != bg.OK { return problem(.Invalid,"physics.owner","cannot bind callback storage") }
    status: bg.Status
    data._network_owner,status = user_owner(&owned.storage,&data.network)
    if status != bg.OK { return problem(.Invalid,"network.owner","cannot bind network storage") }
    data._control_owner,status = user_owner(&owned.storage,&data.controls)
    if status != bg.OK { return problem(.Invalid,"control.owner","cannot bind control codec storage") }
    data._proxy_owner,status = user_owner(&owned.storage,&data.proxy_codec)
    if status != bg.OK { return problem(.Invalid,"proxy.owner","cannot bind proxy codec storage") }
    wire_owner,ws := user_owner(&owned.storage,&data.wire,true)
    if ws != bg.OK { return problem(.Invalid,"wire.owner","cannot bind ingress storage") }
    data._config = p.Config{
        owner=owned.storage.live_owner,detached_owner=owned.storage.allocator_owner,
        allocator_context=owned.storage.memory,provider_user=provider.user,provider_owner=provider.owner,
        author_user=author.user,author_owner=author.owner,effect_user=author.user,effect_owner=author.owner,
    }
    wire_status := ng.wire_configure(&data.wire,{
        allocator=data.allocator,owner=wire_owner.owner,user_data=&data.wire,
        allocator_owner=owned.storage.allocator_owner,allocator_data=data.allocator.data,
    })
    data._wire_ready = data.wire.owned
    if wire_status != .Ok { return problem(.Invalid,"wire.configure",fmt.tprintf("%v",wire_status)) }
    extracted: ga.Diagnostic
    data.baked,extracted = ga.extract(source,data.allocator)
    defer ga.diagnostic_destroy(&extracted)
    if owned.closing { return problem(.Busy,"owner.cancelled","close requested during extraction") }
    if extracted.error != .None {
        detail := len(extracted.authoring_errors_json)>0 ? string(extracted.authoring_errors_json) : fmt.tprintf("%v / %v at %s",extracted.error,extracted.bake_diagnostic.error,extracted.bake_diagnostic.field)
        return problem(.Invalid,"authoring.extract",detail)
    }
    data.content_hash = data.baked.content_hash
    baked: a.Diagnostic
    data.built,baked = ar.build(&data.baked,profile == 0 ? a.content_id64(&data.baked) : profile)
    if baked.error != .None { return problem(.Step_Failed,"authoring.build",fmt.tprintf("%v at %s (%v)",baked.error,baked.field,baked.native_status)) }
    complete = true
    return {}
}

authored_lane_init :: proc(data: ^Authored_Data($Side,$Control,$Proxy,$User)) -> k.World_Error {
    if data == nil || data.closing || data.lane_ready { return .Invalid }
    k.lane_init(&data.lane,&data.ses,size_of(Control),cfg=k.world_lane_config_default(),allocator=data.allocator)
    data.lane_ready = true
    return .Ok
}

// Lane callbacks use this stable Authored_Data as their user context. Mapping
// into Side, tracked fields and the proxy descriptor remain game decisions.
authored_attach :: proc(
    data: ^Authored_Data($Side,$Control,$Proxy,$User),
    initial: Side, fields: []k.World_Field_Type,
    proxy_descriptor: ^n.Entity_Desc = nil, settle: k.Step_Proc = nil,
) -> k.World_Error {
    if data == nil || data.closing || !data.lane_ready { return .Invalid }
    error := p.authoring_attach(&data.physics,&data.lane,&data.built,initial,fields,data._config,settle)
    if error != .Ok { return error }
    if error = p.codec_init(&data.controls,allocator=data.allocator,ownership=data._control_owner); error != .Ok { return error }
    return p.codec_init(&data.proxy_codec,proxy_descriptor,data.allocator,data._proxy_owner)
}

authored_network_attach :: proc(
    data: ^Authored_Data($Side,$Control,$Proxy,$User),
    fields: []k.World_Wire_Field, inputs: []k.World_Wire_Input,
    drivers: []k.World_Driver, effects: []k.World_Effect_Def, rules: bd.Digest,
    epoch: u64 = 1,
) -> k.World_Error {
    if data == nil || data.closing { return .Invalid }
    return p.network_attach(&data.network,&data.physics,&data.built.catalog,fields,inputs,drivers,effects,rules,epoch,data._network_owner)
}

authored_data :: proc(owned: ^Authored_World($Side,$Control,$Proxy,$User)) -> ^Authored_Data(Side,Control,Proxy,User) {
    if owned == nil || k.world_owner_check(owned.storage.allocator_owner) != .Ok { return nil }
    if owned.opening || owned.closing { return nil }
    return owned.storage.data
}

authored_checkpoint :: proc(owned: ^Authored_World($Side,$Control,$Proxy,$User), tick: u64) -> (^k.World_Checkpoint,k.World_Error) {
    data := authored_data(owned)
    if data == nil { return nil,.Busy }
    if error := authored_checkpoint_release(owned); error != .Ok { return nil,error }
    checkpoint,error := k.lane_world_checkpoint(&data.lane,tick)
    if error != .Ok { return nil,error }
    data._checkpoint = checkpoint
    return &data._checkpoint,.Ok
}

authored_checkpoint_release :: proc(owned: ^Authored_World($Side,$Control,$Proxy,$User)) -> k.World_Error {
    if owned == nil { return .Ok }
    if error := k.world_owner_check(owned.storage.allocator_owner); error != .Ok { return error }
    if owned.storage.data == nil { return .Ok }
    return k.world_checkpoint_destroy(&owned.storage.data._checkpoint)
}

authored_close :: proc(owned: ^Authored_World($Side,$Control,$Proxy,$User)) -> (error: k.World_Error) {
    if owned == nil { return .Ok }
    if meter.storage_check(&owned.storage) != bg.OK { return .Rejected }
    owned.closing = true
    if owned.opening || owned.closing_active { return .Busy }
    owned.closing_active = true
    defer owned.closing_active = false
    stage := "storage.close"
    defer if error != .Ok { owned.report = problem(error,stage,"cleanup remains owned; retry after releasing the dependent operation") }
    if data := owned.storage.data; data != nil {
        data.closing = true
        stage = "wire.detach"
        if data._wire_ready {
            if ng.wire_detach(&data.wire) != .Ok { return .Busy }
            data._wire_ready = false
        }
        stage = "checkpoint.close"
        if error = k.world_checkpoint_destroy(&data._checkpoint); error != .Ok { return }
        stage = "network.close"
        if error = p.network_destroy(&data.network); error != .Ok { return }
        stage = "codecs.close"
        if error = p.codec_destroy(&data.controls); error != .Ok { return }
        if error = p.codec_destroy(&data.proxy_codec); error != .Ok { return }
        stage = "physics.detach"
        if error = p.detach(&data.physics); error != .Ok { return }
        stage = "lane.close"
        if data.lane_ready {
            if error = k.lane_destroy(&data.lane); error != .Ok { return }
            data.lane_ready = false
        }
        s.session_destroy(&data.ses)
        stage = "authoring.close"
        if ar.built_destroy(&data.built) != .Ok { return .Busy }
        a.destroy(&data.baked)
        stage = "user.close"
        if !owned.user_cleaned {
            if owned.cleanup_user != nil {
                if error = owned.cleanup_user(&data.game,data.allocator); error != .Ok { return }
            }
            owned.user_cleaned = true
        }
    }
    stage = "storage.close"
    if meter.storage_close(&owned.storage) != bg.OK { return .Busy }
    owned^ = {}
    return .Ok
}
