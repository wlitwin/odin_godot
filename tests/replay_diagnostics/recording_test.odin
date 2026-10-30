package diagnostic_test

import "core:testing"
import "core:reflect"
import "core:strings"
import r "godot:replay"
import d "godot:replay/diagnostic"
import sc "godot:replay/schema"

Record_State :: struct {value:i32,secret:u32 `replay:"authority"`}
RECORD_ID :: d.Recording_Context{1,2,60}
record_step :: proc(w:^Record_State,input:i32,ctx:^r.Step(i32)) {w.value+=input;w.secret+=1;r.emit(ctx,1,2,w.value)}
wrong_state_step :: proc(w:^Record_State,input:i32,ctx:^r.Step(i32)) {record_step(w,input,ctx);w.secret+=1}
wrong_event_step :: proc(w:^Record_State,input:i32,ctx:^r.Step(i32)) {w.value+=input;w.secret+=1;r.emit(ctx,1,2,w.value+1)}

@(test)
portable_recording_is_owned_and_verifies_states_and_events :: proc(t:^testing.T) {
 tl:r.Timeline(Record_State,i32,i32);r.init(&tl,r.Frame(Record_State){},record_step,{8,3},7)
 for i in 0..<10 {r.advance(&tl,i32(i))}
 original,_:=r.current(&tl)
 a:d.Recording(Record_State,i32,i32);defer d.recording_destroy(&a)
 testing.expect_value(t,d.recording_capture(&a,&tl,RECORD_ID).error,d.Recording_Error.None)
 testing.expect_value(t,a.base.tick,u64(3));testing.expect_value(t,len(a.ticks),7)
 testing.expect_value(t,d.recording_capture(&a,&tl,RECORD_ID).error,d.Recording_Error.Occupied)
 after,_:=r.current(&tl);testing.expect(t,reflect.equal(after,original));r.destroy(&tl)
 bytes,error:=d.recording_encode(&a);defer delete(bytes);testing.expect_value(t,error,d.Recording_Error.None)
 b:d.Recording(Record_State,i32,i32);defer d.recording_destroy(&b)
 testing.expect_value(t,d.recording_decode(&b,bytes,RECORD_ID),d.Recording_Error.None)
 again,encoded:=d.recording_encode(&b);defer delete(again);testing.expect_value(t,encoded,d.Recording_Error.None);testing.expect(t,reflect.equal(bytes,again,true))
 capture:r.Audit_Capture(Record_State,i32,i32);defer r.audit_capture_destroy(&capture)
 result:=d.recording_verify(&b,RECORD_ID,d.Recording_Model(Record_State,i32,i32){step=record_step},&capture)
 testing.expect_value(t,result.error,d.Recording_Error.None);testing.expect_value(t,result.replay.steps,7);testing.expect(t,!capture.ready)
 b.events[0].value+=1
 result=d.recording_verify(&b,RECORD_ID,d.Recording_Model(Record_State,i32,i32){step=record_step},&capture)
 testing.expect_value(t,result.replay.error,r.Error.Diverged_Event);testing.expect_value(t,result.replay.tick,u64(4));testing.expect(t,capture.ready)
 testing.expect(t,a.events[0].value!=b.events[0].value)
 r.audit_capture_destroy(&capture);b.events[0].value-=1
 result=d.recording_verify(&b,RECORD_ID,d.Recording_Model(Record_State,i32,i32){step=wrong_state_step},&capture)
 testing.expect_value(t,result.replay.error,r.Error.Diverged_State)
 text:=d.audit_text(result.replay,&capture);defer delete(text);testing.expect(t,strings.contains(text,"$.secret"))
 d.recording_destroy(&b);testing.expect_value(t,capture.parent.tick,u64(3));testing.expect(t,capture.expected.state.secret!=capture.actual.state.secret)
}

@(test)
recording_handles_checkpoints_busy_timelines_and_tick_exhaustion :: proc(t:^testing.T) {
 tl:r.Timeline(Record_State,i32,i32);defer r.destroy(&tl);r.init(&tl,r.Frame(Record_State){tick=max(u64)-1},record_step,{4,1})
 a:d.Recording(Record_State,i32,i32);defer d.recording_destroy(&a)
 testing.expect_value(t,d.recording_capture(&a,&tl,RECORD_ID).error,d.Recording_Error.None);testing.expect_value(t,len(a.ticks),0);d.recording_destroy(&a)
 tl.busy=true
 result:=d.recording_capture(&a,&tl,RECORD_ID);testing.expect_value(t,result.replay.error,r.Error.Reentrant);testing.expect(t,!a.ready);tl.busy=false
 r.advance(&tl,1)
 testing.expect_value(t,d.recording_capture(&a,&tl,RECORD_ID).error,d.Recording_Error.None);testing.expect_value(t,a.header.head,max(u64))
 capture:r.Audit_Capture(Record_State,i32,i32);defer r.audit_capture_destroy(&capture)
 testing.expect_value(t,d.recording_verify(&a,RECORD_ID,d.Recording_Model(Record_State,i32,i32){step=record_step},&capture).error,d.Recording_Error.None)
 d.recording_destroy(&a);r.reset_checkpoint(&tl,r.Frame(Record_State){tick=900},2)
 r.advance(&tl,2);r.advance(&tl,3)
 testing.expect_value(t,d.recording_capture(&a,&tl,RECORD_ID).error,d.Recording_Error.None);testing.expect_value(t,a.base.tick,u64(900))
}

@(test)
recording_decode_is_bounded_atomic_and_rejects_tampering :: proc(t:^testing.T) {
 tl:r.Timeline(Record_State,i32,i32);defer r.destroy(&tl);r.init(&tl,r.Frame(Record_State){},record_step,{8,2})
 r.advance(&tl,3);r.advance(&tl,4)
 a:d.Recording(Record_State,i32,i32);defer d.recording_destroy(&a);d.recording_capture(&a,&tl,RECORD_ID)
 bytes,error:=d.recording_encode(&a);defer delete(bytes);testing.expect_value(t,error,d.Recording_Error.None)
 b:d.Recording(Record_State,i32,i32);defer d.recording_destroy(&b)
 for cut in 0..<len(bytes) {testing.expect(t,d.recording_decode(&b,bytes[:cut],RECORD_ID)!=.None);testing.expect(t,!b.ready && len(b.ticks)==0 && len(b.events)==0)}
 for &byte in bytes {byte~=1;testing.expect(t,d.recording_decode(&b,bytes,RECORD_ID)!=.None);testing.expect(t,!b.ready);byte~=1}
 testing.expect(t,d.recording_decode(&b,bytes,{1,3,60})!=.None)
 // A recomputed checksum must not make impossible counts or misplaced stamps valid.
 hs:sc.Schema;sc.init(&hs,d.Recording_Header);defer sc.destroy(&hs)
 header_size:=sc.HEADER_BYTES+hs.wire_size
 meta,header_fingerprint,_:=sc.inspect(bytes[:header_size]);h:=a.header;h.total_bytes=u64(len(bytes));h.ticks=max(u32)
 sc.encode(&hs,h,bytes[sc.HEADER_BYTES:header_size]);sc.pack_bytes(header_fingerprint,meta,bytes[sc.HEADER_BYTES:header_size],bytes[:header_size])
 testing.expect_value(t,d.recording_decode(&b,bytes,RECORD_ID),d.Recording_Error.Invalid)
 h=a.header;h.total_bytes=u64(len(bytes));sc.encode(&hs,h,bytes[sc.HEADER_BYTES:header_size]);sc.pack_bytes(header_fingerprint,meta,bytes[sc.HEADER_BYTES:header_size],bytes[:header_size])
 testing.expect_value(t,d.recording_decode(&b,bytes,RECORD_ID),d.Recording_Error.None)
 testing.expect_value(t,d.recording_decode(&b,bytes,RECORD_ID),d.Recording_Error.Occupied)
}

reject_record_state :: proc(w:Record_State)->bool {return w.secret<2}
abort_record_step :: proc(w:^Record_State,input:i32,ctx:^r.Step(i32)) {r.abort(ctx)}

@(test)
recording_preflight_and_failed_steps_do_not_execute_or_populate_a_capture :: proc(t:^testing.T) {
 tl:r.Timeline(Record_State,i32,i32);defer r.destroy(&tl);r.init(&tl,r.Frame(Record_State){},record_step,{8,2})
 r.advance(&tl,1);r.advance(&tl,2)
 a:d.Recording(Record_State,i32,i32);defer d.recording_destroy(&a);d.recording_capture(&a,&tl,RECORD_ID)
 capture:r.Audit_Capture(Record_State,i32,i32);defer r.audit_capture_destroy(&capture)
 model:=d.Recording_Model(Record_State,i32,i32){step=abort_record_step,state_valid=reject_record_state}
 result:=d.recording_verify(&a,RECORD_ID,model,&capture)
 testing.expect_value(t,result.error,d.Recording_Error.Model);testing.expect_value(t,result.replay.tick,u64(2));testing.expect(t,!capture.ready)
 model.state_valid=nil
 result=d.recording_verify(&a,d.Recording_Context{1,3,60},model,&capture)
 testing.expect_value(t,result.error,d.Recording_Error.Context)
 result=d.recording_verify(&a,RECORD_ID,model,&capture)
 testing.expect_value(t,result.error,d.Recording_Error.Replay);testing.expect_value(t,result.replay.error,r.Error.Aborted);testing.expect_value(t,result.replay.steps,0);testing.expect(t,!capture.ready)
 a.events[0].id.epoch+=1
 testing.expect_value(t,d.recording_verify(&a,RECORD_ID,model,&capture).error,d.Recording_Error.Invalid)
 a.events[0].id.epoch-=1;a.ticks[0].event_start=1
 testing.expect_value(t,d.recording_verify(&a,RECORD_ID,model,&capture).error,d.Recording_Error.Invalid)
}

@(test)
zero_step_recording_roundtrips_and_forged_tick_envelopes_fail :: proc(t:^testing.T) {
 tl:r.Timeline(Record_State,i32,i32);defer r.destroy(&tl);r.init(&tl,r.Frame(Record_State){tick=100},record_step,{4,1})
 a,b:d.Recording(Record_State,i32,i32);defer d.recording_destroy(&a);defer d.recording_destroy(&b)
 d.recording_capture(&a,&tl,RECORD_ID)
 bytes,error:=d.recording_encode(&a);testing.expect_value(t,error,d.Recording_Error.None)
 testing.expect_value(t,d.recording_decode(&b,bytes,RECORD_ID),d.Recording_Error.None);testing.expect_value(t,b.base.tick,u64(100));testing.expect_value(t,len(b.ticks),0)
 wrong:d.Recording(Record_State,u32,u32);defer d.recording_destroy(&wrong)
 testing.expect_value(t,d.recording_decode(&wrong,bytes,RECORD_ID),d.Recording_Error.Codec);testing.expect(t,!wrong.ready)
 delete(bytes);d.recording_destroy(&a);d.recording_destroy(&b)
 r.advance(&tl,2);d.recording_capture(&a,&tl,RECORD_ID);bytes,error=d.recording_encode(&a);defer delete(bytes)
 header,base,tick:sc.Schema;sc.init(&header,d.Recording_Header);sc.init(&base,r.Frame(Record_State));sc.init(&tick,d.Recorded_Tick(Record_State,i32))
 defer sc.destroy(&header);defer sc.destroy(&base);defer sc.destroy(&tick)
 offset:=2*sc.HEADER_BYTES+header.wire_size+base.wire_size
 packet:=bytes[offset:];meta,fingerprint,_:=sc.inspect(packet)
 // The envelope checksum is valid, but the chronological stamp is wrong.
 meta.tick+=1;sc.pack_bytes(fingerprint,meta,packet[sc.HEADER_BYTES:],packet)
 testing.expect_value(t,d.recording_decode(&b,bytes,RECORD_ID),d.Recording_Error.Invalid);testing.expect(t,!b.ready && len(b.ticks)==0)
 meta.tick-=1
 entry:=a.ticks[0];entry.event_count=max(u32)
 sc.encode(&tick,entry,packet[sc.HEADER_BYTES:]);sc.pack_bytes(fingerprint,meta,packet[sc.HEADER_BYTES:],packet)
 testing.expect_value(t,d.recording_decode(&b,bytes,RECORD_ID),d.Recording_Error.Invalid);testing.expect(t,!b.ready && len(b.events)==0)
}
