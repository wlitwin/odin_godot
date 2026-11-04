// Private test byte owner. Deliberately contains NO reference-runtime pointer,
// Native image, checkpoint, codec/catalog/schema, or borrowed reference lease.
package replay_gate_b_probe

import "core:mem"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"

Prediction_Byte_Store :: struct {
 owner:r.Owner, // guarded fixed prefix; owns the exact self allocation
 allocator_owner:r.Owner,
 scope:^meter.Context,allocator:mem.Allocator,
 storage:[]u8,
 frame:bd.Frame_View, // identity/epoch/tick values; slices only into storage
}
byte_store_create :: proc(frame:bd.Frame_View)->(store:^Prediction_Byte_Store,error:r.Error){
 total:u64
 for part in bd.Part{if u64(len(frame.parts[part]))>u64(net.COMPLETE_MAX_BYTES)-total{return nil,.Resource_Limit};total+=u64(len(frame.parts[part]))}
 if len(frame.parts[.Solver])==0 || total==0{return nil,.Incomplete_State}
 scope,status:=meter.create(bg.service_get(),bg.CATEGORY_REPLAY_PROVIDER);if status!=bg.OK{return nil,.Resource_Limit}
 allocator:=meter.allocator(scope);value,allocation_error:=new(Prediction_Byte_Store,allocator)
 if allocation_error!=.None{meter.destroy(&scope);return nil,.Resource_Limit}
 value.scope=scope;value.allocator=allocator
 okay:=false;defer if !okay{byte_store_destroy(&value)}
 allocator_owner,owner_error:=ph.owner_context_create(meter.data_lease(scope),allocator_data=allocator.data,require_live_instance=false)
 if owner_error!=.None{return nil,owner_error};value.allocator_owner=allocator_owner.owner
 lease,ls:=meter.block_lease(scope,value,size_of(value^),value,size_of(value^));if ls!=bg.OK{return nil,.Resource_Limit}
 self_owner,self_error:=ph.owner_context_create(lease,user_data=value,require_live_instance=false);if self_error!=.None{return nil,self_error};value.owner=self_owner.owner
 value.storage,allocation_error=mem.alloc_bytes(int(total),allocator=allocator);if allocation_error!=.None{return nil,.Resource_Limit}
 value.frame={identity=frame.identity,epoch=frame.epoch,tick=frame.tick};at:=0
 for part in bd.Part{n:=len(frame.parts[part]);value.frame.parts[part]=value.storage[at:at+n];copy(value.frame.parts[part],frame.parts[part]);at+=n}
 if at!=len(value.storage){return nil,.External_State}
 okay=true;return value,.None
}
byte_store_destroy :: proc(pointer:^^Prediction_Byte_Store)->r.Error{
 if pointer==nil || pointer^==nil{return .None};value:=pointer^
 if error:=r.owner_access(value.owner);error!=.None{return error}
 if error:=r.owner_access(value.allocator_owner);error!=.None{return error}
 // All typed data and allocator values are copied before self release. These
 // are this fixture's fixed Meter leases, inside an actual protected Core call.
 scope,allocator,owner,allocator_owner:=value.scope,value.allocator,value.owner,value.allocator_owner
 delete(value.storage,allocator);mem.free(value,allocator)
 if error:=r.owner_drop(&owner);error!=.None{return error}
 if error:=r.owner_drop(&allocator_owner);error!=.None{return error}
 pointer^=nil
 return meter.destroy(&scope)==bg.OK?r.Error.None:r.Error.External_State
}
byte_store_compare :: proc(store:^Prediction_Byte_Store,actual:bd.Frame_View)->(expected_signature,actual_signature:bd.Signature,equal:bool){
 if store==nil || r.owner_access(store.owner)!=.None{return}
 expected_error,actual_error:bd.Error
 expected_signature,expected_error=bd.sign(store.frame);actual_signature,actual_error=bd.sign(actual)
 equal=expected_error==.None&&actual_error==.None&&bd.compare(expected_signature,actual_signature)==.Match
 for part in bd.Part{equal=equal&&mem.compare(store.frame.parts[part],actual.parts[part])==0}
 return
}
