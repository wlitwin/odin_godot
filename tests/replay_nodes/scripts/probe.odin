//gd:extends Node2D
//gd:class ReplayNodesProbe
package nodes_probe

import "core:fmt"
import gd "godot:godot"
import rgd "godot:replay/godot"

LEGACY :: #config(REPLAY_NODES_LEGACY,false)
ReplayNodesProbe :: struct {owner:gd.Node2d,nodes:rgd.Nodes2,frames:int}
replay_nodes_probe_ready :: proc(self:^ReplayNodesProbe) {
    if gd.env_string("REPLAY_NODES_MODE","check")=="bench" {bench(self)} else {when !LEGACY {check(self);typed_check(self);bake_check(self);input_check(self);effects_check(self);body_check(self)}}
    rgd.nodes_destroy(&self.nodes)
}
replay_nodes_probe_process :: proc(self:^ReplayNodesProbe,dt:f64) {
    self.frames+=1;if self.frames==6 {gd.print_str("REPLAY_NODES_OK");gd.scene_tree_quit(gd.get_tree(self.owner),0)}
}
replay_nodes_probe_exit_tree :: proc(self:^ReplayNodesProbe) {rgd.nodes_destroy(&self.nodes)}
value :: proc(key:u64,x:f32)->rgd.Instance2 {return {key=key,pose={position={x,2},angle=0.25},scale={2,3},color={1,0.5,0.25,1}}}
when !LEGACY {
    check :: proc(self:^ReplayNodesProbe) {
        assert(rgd.nodes_load(&self.nodes,self.owner,"res://view.tscn",4))
        input:=[2]rgd.Instance2{value(1,10),value(2,20)}
        assert(rgd.nodes_present(&self.nodes,input[:]))
        first,known:=rgd.nodes_get(&self.nodes,1);assert(known)
        assert(gd.node2d_get_position(first)==(gd.Vector2{10,2}) && gd.node2d_get_scale(first)==(gd.Vector2{2,3}))
        assert(gd.canvas_item_get_modulate(first)==input[0].color)
        writes:=self.nodes.stats.property_writes
        assert(rgd.nodes_present(&self.nodes,input[:]) && self.nodes.stats.property_writes==writes+8)
        self.nodes.cache_properties=true;writes=self.nodes.stats.property_writes
        assert(rgd.nodes_present(&self.nodes,input[:]) && self.nodes.stats.property_writes==writes)
        input[0].pose.position[0]=11
        assert(rgd.nodes_present(&self.nodes,input[:]) && self.nodes.stats.property_writes==writes+1)
        reversed:=[2]rgd.Instance2{input[1],input[0]}
        assert(rgd.nodes_present(&self.nodes,reversed[:]))
        retained,_:=rgd.nodes_get(&self.nodes,1);assert(retained==first)
        invalid:=[2]rgd.Instance2{value(1,99),value(1,100)}
        assert(!rgd.nodes_present(&self.nodes,invalid[:]))
        assert(self.nodes.count==2 && gd.node2d_get_position(first)==(gd.Vector2{11,2}))
        invalid[0].key=0;assert(!rgd.nodes_present(&self.nodes,invalid[:]))
        gd.node2d_set_position(first,{88,99})
        assert(rgd.nodes_present(&self.nodes,input[:]))
        assert(gd.node2d_get_position(first)==(gd.Vector2{88,99}))
        rgd.nodes_invalidate(&self.nodes,1)
        assert(rgd.nodes_present(&self.nodes,input[:]) && gd.node2d_get_position(first)==(gd.Vector2{11,2}))
        input[0].key=0x200000001
        assert(rgd.nodes_present(&self.nodes,input[:]))
        _,found:=rgd.nodes_get(&self.nodes,1);assert(!found)
        replacement,exists:=rgd.nodes_get(&self.nodes,input[0].key);assert(exists && replacement!=first)
        full:=[4]rgd.Instance2{value(11,1),value(12,2),value(13,3),value(14,4)}
        assert(rgd.nodes_present(&self.nodes,full[:]) && self.nodes.count==4)
        next:=[4]rgd.Instance2{value(21,1),value(22,2),value(23,3),value(24,4)}
        assert(rgd.nodes_present(&self.nodes,next[:]) && self.nodes.count==4)
        for item in full {_,present:=rgd.nodes_get(&self.nodes,item.key);assert(!present)}
        assert(rgd.nodes_present(&self.nodes,nil) && self.nodes.count==0)
        gd.print_str(fmt.tprintf("REPLAY_NODES_CONTRACT_OK created=%d retired=%d writes=%d skips=%d",self.nodes.stats.created,self.nodes.stats.retired,self.nodes.stats.property_writes,self.nodes.stats.property_skips))
    }
}
bench :: proc(self:^ReplayNodesProbe) {
    when !LEGACY {if gd.env_int("REPLAY_NODES_TYPED",0)==1 {typed_bench(self);return}}
    count:=gd.env_int("REPLAY_NODES_COUNT",512)
    assert(count>0 && count<=2048)
    capacity:=gd.env_int("REPLAY_NODES_CAPACITY",int(count));assert(capacity>=count && capacity<=2048)
    assert(rgd.nodes_load(&self.nodes,self.owner,"res://view.tscn",int(capacity)))
    cached:=gd.env_int("REPLAY_NODES_CACHE",0)==1
    when !LEGACY {self.nodes.cache_properties=cached} else {assert(!cached)}
    input:=make([]rgd.Instance2,int(count));defer delete(input)
    for &item,i in input {item=value(u64(i+1),f32(i))}
    assert(rgd.nodes_present(&self.nodes,input))
    for sample in 0..<6 {
        before:=gd.time_get_ticks_usec(gd.singleton_time())
        for frame in 0..<120 {
            for &item,i in input {item.pose.position[0]=f32(i)+f32(frame%16)}
            assert(rgd.nodes_present(&self.nodes,input))
        }
        elapsed:=gd.time_get_ticks_usec(gd.singleton_time())-before
        // First cohort is warm-up; no allocation/scene construction in timings.
        if sample>0 {gd.print_str(fmt.tprintf("REPLAY_NODES_BENCH legacy=%t cached=%t count=%d frames=120 us=%d",LEGACY,cached,count,elapsed))}
    }
    when !LEGACY {gd.print_str(fmt.tprintf("REPLAY_NODES_OPS writes=%d skips=%d probes=%d",self.nodes.stats.property_writes,self.nodes.stats.property_skips,self.nodes.index.probes+self.nodes.desired.probes))}
}
