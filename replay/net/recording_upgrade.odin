package replay_net

import r "godot:replay"
import d "godot:replay/diagnostic"

// Frozen pre-authority-observation diagnostic input schema. Gameplay packets and
// checkpoints never encode Batch and do not require this recording conversion.
@(private)
Batch_Before_Authority :: struct($Control,$Action:typeid,$Seats:int) {
 prediction_group:u64,
 prediction_seat:u16,
 controls:[Seats]Control,
 views:[Seats]View_Time,
 stamps:[Seats]View_Stamp,
 joins,leaves:u64,
 fresh:u64,
 has_action:[Seats]bool,
 actions:[Seats]Action,
 sequences:[Seats]u64,
 rejections:[Seats]Action_Reason,
}

// Explicit conversion for models whose authority policy remains disabled.
// Preserve context, frames, controls, decisions and events; do not invent host
// observations that the old recording did not contain. Replaying remains a
// separate verification operation, including for intentionally divergent files.
recording_upgrade_without_authority :: proc(bytes:[]u8,model:^Model($S,$C,$A,$E,$N),identity:d.Recording_Context,
                                            allocator:=context.allocator)->([]u8,d.Recording_Error) {
 if model==nil || model.authority.id!=0 || recording_model(model).step==nil {return nil,.Model}
 source:d.Recording(S,Batch_Before_Authority(C,A,N),Net_Event(E));defer d.recording_destroy(&source)
 if err:=d.recording_decode(&source,bytes,identity,allocator);err!=.None {return nil,err}
 memory:=u64(size_of(S))+u64(len(source.ticks))*u64(size_of(d.Recorded_Tick(S,Batch(C,A,N))))+u64(len(source.events))*u64(size_of(r.Occurrence(Net_Event(E))))
 if memory>d.MAX_RECORDING_MEMORY {return nil,.Capacity}
 target:=d.Recording(S,Batch(C,A,N),Net_Event(E)){allocator=allocator,ready=true,epoch=source.epoch,header=source.header,base=source.base,events=source.events}
 target.ticks=make([]d.Recorded_Tick(S,Batch(C,A,N)),len(source.ticks),allocator);defer delete(target.ticks,allocator)
 for &old,index in source.ticks {
  input:=Batch(C,A,N){prediction_group=old.input.prediction_group,prediction_seat=old.input.prediction_seat,
   controls=old.input.controls,views=old.input.views,stamps=old.input.stamps,joins=old.input.joins,leaves=old.input.leaves,fresh=old.input.fresh,
   has_action=old.input.has_action,actions=old.input.actions,sequences=old.input.sequences,rejections=old.input.rejections}
  if !recording_batch_valid(model,input) {return nil,.Model}
  target.ticks[index]={frame=old.frame,input=input,event_start=old.event_start,event_count=old.event_count}
 }
 return d.recording_encode(&target,allocator)
}
