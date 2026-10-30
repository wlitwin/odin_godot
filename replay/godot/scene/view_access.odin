package replay_godot_scene

import r "godot:replay"

// Borrowed rigs may be inspected or drained for local notices. Callbacks must
// not change membership, reenter the pool or retain pointers to its storage.
view_pool_visit :: proc(p:^View_Pool2($Entity,$Value,$Rig),user:^$User,visit:proc(^User,r.Handle(Entity),Rig)) {
    if visit==nil {return}
    for bucket in p.index.occupied[:p.index.count] {
        entry:=p.entries[p.index.values[bucket]]
        handle:=r.Handle(Entity){u32(entry.key)-1,u32(entry.key>>32)}
        visit(user,handle,entry.rig)
    }
}
archetype_pool_visit :: proc(p:^Archetype_Pool2($Entity,$Value,$Rig),user:^$User,visit:proc(^User,r.Handle(Entity),Rig)) {
    for &pool in p.pools {view_pool_visit(&pool,user,visit)}
}
View_Stats :: struct {count:int,created,retired,paints,skipped_paints,property_writes,property_skips:u64}
view_pool_stats :: proc(p:^View_Pool2($Entity,$Value,$Rig))->View_Stats {
    n:=p.nodes.stats;return {p.nodes.count,n.created,n.retired,p.paints,p.skipped_paints,n.property_writes,n.property_skips}
}
archetype_pool_stats :: proc(p:^Archetype_Pool2($Entity,$Value,$Rig))->View_Stats {
    result:View_Stats
    for &pool in p.pools {
        s:=view_pool_stats(&pool);result.count+=s.count;result.created+=s.created;result.retired+=s.retired;result.paints+=s.paints
        result.skipped_paints+=s.skipped_paints;result.property_writes+=s.property_writes;result.property_skips+=s.property_skips
    }
    return result
}
