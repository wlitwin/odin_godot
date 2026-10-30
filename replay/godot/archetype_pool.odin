package replay_godot

import "core:mem"
import "core:fmt"
import d "godot:replay/definitions"
import gd "godot:godot"
import v "godot:replay/view"

// One typed pool per registered scene. Registration is frozen for this owner's
// lifetime. Partition storage is id_limit * capacity, plus each registered pool; live nodes
// across all pools are bounded by capacity. Asset owner must outlive this owner.
Archetype_Pool2 :: struct($Entity,$Value,$Rig:typeid) {
    pools:[]View_Pool2(Entity,Value,Rig),
    batches:[]v.View_Item(Entity,Value),counts:[]int,
    desired:v.Key_Index,capacity:int,
    select:proc(Value)->u32,
    allocator:mem.Allocator,
    problem:d.Report,
}
archetype_pool_init :: proc(p:^Archetype_Pool2($Entity,$Value,$Rig),assets:^Archetype_Assets($Definition),parent:gd.Node,capacity:int,
                            select:proc(Value)->u32,binding:proc(rawptr,u32,Definition,Archetype_Visual)->View_Binding(Value,Rig),user:rawptr,
                            allocator:=context.allocator)->bool {
    if len(p.pools)!=0 || capacity<1 || capacity>v.MAX_INDEX_CAPACITY || select==nil || binding==nil || assets.registry.count==0 {return false}
    n:=len(assets.registry.entries)
    if i64(n)*i64(capacity)>1024*1024 {return false}
    p.allocator,p.capacity,p.select=allocator,capacity,select
    p.pools=make([]View_Pool2(Entity,Value,Rig),n,allocator)
    p.batches=make([]v.View_Item(Entity,Value),n*capacity,allocator);p.counts=make([]int,n,allocator)
    if !v.key_index_init(&p.desired,capacity,allocator) {archetype_pool_destroy(p);return false}
    for slot,i in assets.registry.entries {if slot.present {
        value:=slot.value
        if !view_pool_init(&p.pools[i],parent,value.local.scene,capacity,binding(user,value.id,value.definition,value.local),allocator) {archetype_pool_destroy(p);return false}
    }}
    return true
}
archetype_pool_destroy :: proc(p:^Archetype_Pool2($Entity,$Value,$Rig)) {
    for &pool in p.pools {view_pool_destroy(&pool)}
    delete(p.pools,p.allocator);delete(p.batches,p.allocator);delete(p.counts,p.allocator);v.key_index_destroy(&p.desired);p^={}
}
archetype_pool_present :: proc(p:^Archetype_Pool2($Entity,$Value,$Rig),scope:v.View_Scope,items:[]v.View_Item(Entity,Value))->View_Pool_Error {
    p.problem={}
    if len(p.pools)==0 || scope.epoch==0 {p.problem=d.problem(.Invalid,"$view","uninitialized pool or invalid epoch");return .Invalid}
    if len(items)>p.capacity {p.problem=d.problem(.Capacity,"$view","entity capacity exceeded");return .Capacity}
    for pool in p.pools {if pool.scoped && scope.epoch<pool.scope.epoch {p.problem=d.problem(.Invalid,"$view.scope","stale authority epoch");return .Invalid}}
    v.key_index_clear(&p.desired);for &count in p.counts {count=0}
    // Global preflight rejects duplicate identities even across archetypes.
    for item,i in items {
        id:=p.select(item.view.value)
        if u64(id)>=u64(len(p.pools)) || len(p.pools[id].entries)==0 || v.handle_key(item.handle)==0 || !v.entity_view_valid(item.view) || item.source>.Authoritative {p.problem=d.problem(.Invalid,fmt.tprintf("archetype=%d entity=%d",id,v.handle_key(item.handle)),"missing archetype or invalid display item");return .Invalid}
        if v.key_index_put(&p.desired,v.handle_key(item.handle),i)!=.None {p.problem=d.problem(.Invalid,fmt.tprintf("archetype=%d entity=%d",id,v.handle_key(item.handle)),"duplicate entity identity");return .Duplicate}
        p.batches[int(id)*p.capacity+p.counts[id]]=item;p.counts[id]+=1
    }
    for &pool,i in p.pools {if len(pool.entries)>0 {
        if error:=view_pool_present(&pool,scope,p.batches[i*p.capacity:i*p.capacity+p.counts[i]]);error!=.None {
            detail:=view_pool_problem(&pool);p.problem=d.problem(.Invalid,fmt.tprintf("archetype=%d %s",i,d.report_path(&detail)),d.report_message(&detail));return error
        }
    }}
    return .None
}
