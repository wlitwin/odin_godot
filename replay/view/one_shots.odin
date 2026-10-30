package replay_view

import "core:mem"
import r "godot:replay"

Once_Result :: enum {New, Duplicate, Expired, Wrong_Epoch, Capacity, Invalid}
Once_Key :: struct {source,key,slot:u64}
Once_Batch :: struct {tick:u64,count:int,valid:bool}
// A bounded consumption ledger for irreversible presentation. Cancellation may
// stop an active voice but does not make a heard event new again after replay.
One_Shots :: struct {
	allocator:mem.Allocator,
	epoch,floor:u64,
	per_tick:int,
	batches:[]Once_Batch,
	keys:[]Once_Key,
}
one_shots_init :: proc(log:^One_Shots,epoch:u64,baseline:u64=0,history:int=512,per_tick:int=40,allocator:=context.allocator)->bool {
	if len(log.batches)!=0 || epoch==0 || history<2 || history>4096 || per_tick<1 || per_tick>4096 {return false}
	log.allocator,log.epoch,log.floor,log.per_tick=allocator,epoch,baseline,per_tick
	log.batches=make([]Once_Batch,history,allocator);log.keys=make([]Once_Key,history*per_tick,allocator)
	return true
}
one_shots_destroy :: proc(log:^One_Shots) {delete(log.batches,log.allocator);delete(log.keys,log.allocator);log^={}}
// Only an explicitly newer presentation epoch can forget all consumed IDs.
one_shots_reset :: proc(log:^One_Shots,epoch,baseline:u64)->bool {
	if len(log.batches)==0 || epoch<=log.epoch {return false}
	for &batch in log.batches {batch={}}
	log.epoch,log.floor=epoch,baseline;return true
}
// Caller supplies a monotonic frontier past which events cannot newly begin.
// Old IDs remain rejected after their slots have been reclaimed.
one_shots_retire :: proc(log:^One_Shots,through:u64)->bool {
	if len(log.batches)==0 || through<log.floor {return false}
	log.floor=through;return true
}
one_shot_note :: proc(log:^One_Shots,id:r.Event_Id,slot:u64=0)->Once_Result {
	if len(log.batches)==0 {return .Invalid}
	if id.epoch!=log.epoch {return .Wrong_Epoch}
	if id.tick<=log.floor {return .Expired}
	index:=int(id.tick%u64(len(log.batches)));batch:=&log.batches[index]
	if batch.valid && batch.tick!=id.tick && batch.tick>log.floor {return .Capacity}
	if !batch.valid || batch.tick!=id.tick {batch^={tick=id.tick,valid=true}}
	keys:=log.keys[index*log.per_tick:(index+1)*log.per_tick]
	key:=Once_Key{id.source,id.key,slot}
	for prior in keys[:batch.count] {if prior==key {return .Duplicate}}
	if batch.count==len(keys) {return .Capacity}
	keys[batch.count]=key;batch.count+=1;return .New
}
