// Test-only exact shared-budget probe. Each consumer DLL owns its own Context;
// the stable Core service and native ledger must sum both producers.
package box3d_quota_fixture

import "core:mem"
import b "godot:box3d"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"

Context :: struct {
	meter: ^meter.Context,
	allocator: mem.Allocator,
	world: b.World,
	expected, actual: []u8,
	blocks: [2][]u8,
	marker, expected_marker: u64,
}

init :: proc(c:^Context,world:b.World,marker:u64)->bg.Status {
	if c==nil || c.meter!=nil{return bg.INVALID_ARGUMENT}
	s:=bg.service_get();if s.realm==0{return bg.INCOMPATIBLE}
	m,status:=meter.create(s,bg.CATEGORY_REPLAY_CODEC);if status!=bg.OK{return status}
	c.meter=m;c.allocator=meter.allocator(m);c.world=world;c.marker=marker;c.expected_marker=marker
	n,ns:=b.world_dump(world,nil);if ns!=.Ok{destroy(c);return bg.Status(ns)}
	allocation_error:mem.Allocator_Error
	c.expected,allocation_error=make([]u8,int(n),c.allocator)
	if allocation_error!=nil{destroy(c);return bg.CAPACITY}
	c.actual,allocation_error=make([]u8,int(n),c.allocator)
	if allocation_error!=nil{destroy(c);return bg.CAPACITY}
	_,ns=b.world_dump(world,c.expected);if ns!=.Ok{destroy(c);return bg.Status(ns)}
	return bg.OK
}

allocate :: proc(c:^Context,bytes:u64,slot:int=0)->bg.Status {
	if c==nil || c.meter==nil || slot<0 || slot>=len(c.blocks) || len(c.blocks[slot])!=0 || bytes>64*1024*1024{return bg.INVALID_ARGUMENT}
	value,error:=mem.alloc(int(bytes),1,c.allocator)
	if error!=nil{return bg.CAPACITY}
	c.blocks[slot]=(cast([^]u8)value)[:int(bytes)]
	if bytes>0{c.blocks[slot][0]=0x5a;c.blocks[slot][int(bytes)-1]=0xa5}
	return bg.OK
}

probe :: proc(c:^Context)->bool {
	if c==nil || c.meter==nil || c.marker!=c.expected_marker{return false}
	n,status:=b.world_dump(c.world,c.actual)
	if status!=.Ok || n!=u64(len(c.expected)) || mem.compare(c.expected,c.actual)!=0{return false}
	for block in c.blocks {if len(block)>0 && (block[0]!=0x5a || block[len(block)-1]!=0xa5){return false}}
	return true
}

destroy :: proc(c:^Context)->bg.Status {
	if c==nil || c.meter==nil{return bg.OK}
	for &block in c.blocks {delete(block,c.allocator);block=nil}
	delete(c.expected,c.allocator);delete(c.actual,c.allocator);c.expected=nil;c.actual=nil
	status:=meter.destroy(&c.meter);if status==bg.OK{c^={}}
	return status
}

admitted :: proc()->(u64,bg.Status) {
	contract,status:=b.domain_contract_get();if status!=.Ok{return 0,bg.Status(status)}
	stats,ss:=b.host_ledger_get(contract.cookie);return stats.admitted_bytes,bg.Status(ss)
}
