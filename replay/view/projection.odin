package replay_view

import "core:math"
import "core:mem"
import r "godot:replay"

Sample_Source :: enum u8 {Predicted, Observed, Authoritative, Mixed}
Sample_Policy :: enum u8 {Predicted, Observed, Authoritative, Local_Predicted_Remote_Observed}
View_Scope :: struct {epoch,revision:u64}
Projection_Error :: enum {None,Invalid,Capacity,Duplicate,Unsupported_Value}
// Detached rendering data. cut changes when a pose must not interpolate across
// a teleport; owner selects presentation policy, never simulation permission.
Entity_View :: struct($Value:typeid) {
    pose:Pose2,
    scale:[2]f32,
    color:[4]f32,
    value:Value,
    owner:u16,
    cut:u64,
}
View_Item :: struct($Entity,$Value:typeid) {handle:r.Handle(Entity),view:Entity_View(Value),tick:u64,source:Sample_Source}
Projection :: struct($Entity,$Value:typeid) {
    allocator:mem.Allocator,
    items,scratch:[]View_Item(Entity,Value),
    keys:Key_Index,
    count:int,
    scope:View_Scope,
    tick:u64,
    source:Sample_Source,
    ready:bool,
}
projection_init :: proc(p:^Projection($Entity,$Value),capacity:int,allocator:=context.allocator)->bool {
    if len(p.items)!=0 || !r.value_supported(Entity) || !r.value_supported(Value) || !key_index_init(&p.keys,capacity,allocator) {return false}
    p.allocator=allocator;p.items=make([]View_Item(Entity,Value),capacity,allocator);p.scratch=make([]View_Item(Entity,Value),capacity,allocator)
    return true
}
projection_destroy :: proc(p:^Projection($Entity,$Value)) {delete(p.items,p.allocator);delete(p.scratch,p.allocator);key_index_destroy(&p.keys);p^={}}
projection_values :: proc(p:^Projection($Entity,$Value))->[]View_Item(Entity,Value) {return p.ready ? p.items[:p.count] : nil}

// Input is already a detached pool value. Callbacks receive entity VALUES, not
// pointers into history. False filters a member; invalid output rejects the whole
// candidate. Failure preserves the previously published projection.
project_pool :: proc(p:^Projection($Entity,$Value),pool:r.Pool(Entity,$N),scope:View_Scope,tick:u64,source:Sample_Source,
                     project:proc(Entity)->(Entity_View(Value),bool))->Projection_Error {
    if len(p.items)==0 || scope.epoch==0 || source>.Authoritative || project==nil {return .Invalid}
    pool:=pool;count:=0;alive:=u32(0);key_index_clear(&p.keys)
    for entity,i in pool.values {
        if !pool.alive[i] {continue};alive+=1
        handle:=r.Handle(Entity){u32(i),pool.generations[i]}
        if handle_key(handle)==0 {return .Invalid}
        value,include:=project(entity);if !include {continue}
        if !entity_view_valid(value) {return .Invalid}
        if count==len(p.scratch) {return .Capacity}
        if key_index_put(&p.keys,handle_key(handle),count)!=.None {return .Duplicate}
        p.scratch[count]={handle,value,tick,source};count+=1
    }
    if alive!=pool.count {return .Invalid}
    copy(p.items,p.scratch[:count]);p.count,p.scope,p.tick,p.source,p.ready=count,scope,tick,source,true
    return .None
}
entity_view_valid :: proc(value:Entity_View($Value))->bool {
    if !finite_pose2(value.pose) {return false}
    for x in value.scale {if math.is_nan(x) || math.is_inf(x) {return false}}
    for x in value.color {if math.is_nan(x) || math.is_inf(x) {return false}}
    return true
}

// Membership and discrete values come from a. Only matching generations/cuts
// interpolate poses. A scope change selects b directly. Destination may be reused
// between frames but must not alias either input owner.
projection_blend :: proc(dst:^Projection($Entity,$Value),a,b:^Projection(Entity,Value),alpha:f32)->Projection_Error {
    if dst==a || dst==b || len(dst.items)==0 || !a.ready || !b.ready || a.source!=b.source || a.source==.Mixed || math.is_nan(alpha) || math.is_inf(alpha) || b.tick<a.tick {return .Invalid}
    t:=clamp(alpha,0,1)
    if t>=1 || a.scope!=b.scope {return projection_copy(dst,b)}
    if a.count>len(dst.items) {return .Capacity}
    key_index_clear(&dst.keys)
    for item,i in b.items[:b.count] {if key_index_put(&dst.keys,handle_key(item.handle),i)!=.None {return .Duplicate}}
    for item,i in a.items[:a.count] {
        dst.scratch[i]=item
        if at,found:=key_index_get(&dst.keys,handle_key(item.handle));found {
            other:=b.items[at]
            if item.view.cut==other.view.cut {dst.scratch[i].view.pose=pose_blend(item.view.pose,other.view.pose,t)}
            else {dst.scratch[i].view.pose=other.view.pose}
        }
    }
    copy(dst.items,dst.scratch[:a.count]);dst.count,dst.scope,dst.tick,dst.source,dst.ready=a.count,a.scope,a.tick,a.source,true
    return .None
}
projection_copy :: proc(dst:^Projection($Entity,$Value),src:^Projection(Entity,Value))->Projection_Error {
    if dst==src || len(dst.items)==0 || !src.ready {return .Invalid}
    if src.count>len(dst.items) {return .Capacity}
    copy(dst.items,src.items[:src.count]);dst.count,dst.scope,dst.tick,dst.source,dst.ready=src.count,src.scope,src.tick,src.source,true
    return .None
}

// Mixed selection takes local members from prediction and everyone else from
// observation. Missing sources are explicit; no implicit authority fallback.
projection_select :: proc(dst:^Projection($Entity,$Value),predicted,observed,authority:^Projection(Entity,Value),policy:Sample_Policy,local:u16=0)->Projection_Error {
    if policy>.Local_Predicted_Remote_Observed {return .Invalid}
    #partial switch policy {
    case .Predicted:if predicted==nil || predicted.source!=.Predicted {return .Invalid};return projection_copy(dst,predicted)
    case .Observed:if observed==nil || observed.source!=.Observed {return .Invalid};return projection_copy(dst,observed)
    case .Authoritative:if authority==nil || authority.source!=.Authoritative {return .Invalid};return projection_copy(dst,authority)
    }
    if local==0 || predicted==nil || observed==nil || dst==predicted || dst==observed || len(dst.items)==0 ||
        !predicted.ready || !observed.ready || predicted.source!=.Predicted || observed.source!=.Observed || predicted.scope!=observed.scope {return .Invalid}
    count:=0;key_index_clear(&dst.keys)
    for source in ([2]^Projection(Entity,Value){predicted,observed}) {
        for item in source.items[:source.count] {
            if (item.view.owner==local)!=(source==predicted) {continue}
            if count==len(dst.scratch) {return .Capacity}
            // One source pool cannot display two lifetimes of the same slot.
            // Conflicting local/remote ownership or generations need an explicit
            // game policy instead of silently showing both versions.
            if key_index_put(&dst.keys,u64(item.handle.index)+1,count)!=.None {return .Duplicate}
            dst.scratch[count]=item;count+=1
        }
    }
    copy(dst.items,dst.scratch[:count]);dst.count,dst.scope,dst.tick,dst.source,dst.ready=count,predicted.scope,predicted.tick,.Mixed,true
    return .None
}
