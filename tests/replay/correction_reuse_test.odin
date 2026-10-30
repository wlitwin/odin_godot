package replay_test
import "core:testing"
import "core:reflect"
import r "godot:replay"

Reuse_State :: struct {value:i32,bits:u32}
Reuse_Input :: struct {add:i32,reset,fail:bool}
Reuse_Count :: struct {steps,rewrites:int,change_at:u64,fail_at:u64}
reuse_step :: proc(w:^Reuse_State,input:Reuse_Input,ctx:^r.Step(i32)) {
 if ctx.user!=nil {(cast(^Reuse_Count)ctx.user).steps+=1}
 if input.fail {r.abort(ctx);return}
 if input.reset {w.value=0};w.value+=input.add
 r.emit(ctx,1,1,w.value)
}
reuse_equal :: proc(t:^testing.T,a,b:^r.Timeline(Reuse_State,Reuse_Input,i32)) {
 testing.expect_value(t,a.head,b.head);testing.expect_value(t,a.confirmed,b.confirmed)
 for tick in a.confirmed..=a.head {
  x,ok:=r.read(a,tick);y,found:=r.read(b,tick);testing.expect(t,ok && found && reflect.equal(x,y))
  xi,xk:=r.read_input(a,tick);yi,yk:=r.read_input(b,tick);testing.expect(t,xk==yk && reflect.equal(xi,yi))
  xe,ye:[4]r.Occurrence(i32);xn,xerr:=r.copy_events(a,tick,xe[:]);yn,yerr:=r.copy_events(b,tick,ye[:])
  testing.expect(t,xerr==.None && yerr==.None && xn==yn && reflect.equal(xe[:xn],ye[:yn],true))
 }
}
@(test)
exact_prefix_and_converged_suffix_reuse_preserve_events_and_rewriter_order :: proc(t:^testing.T) {
 for change in ([3]u64{0,4,7}) {
  a,b:r.Timeline(Reuse_State,Reuse_Input,i32);defer r.destroy(&a);defer r.destroy(&b)
  ac,bc:Reuse_Count
  r.init(&a,r.Frame(Reuse_State){},reuse_step,cfg={32,4},user=&ac)
  r.init(&b,r.Frame(Reuse_State){},reuse_step,cfg={32,4},user=&bc)
  for tick in 1..=12 {input:=Reuse_Input{add=1,reset=tick==6};r.advance(&a,input);r.advance(&b,input)}
  truth,_:=r.read(&a,2)
  events:=[1]r.Occurrence(i32){{id={epoch=1,tick=2,source=99,key=1},value=777}}
  ac,bc={change_at=change},{change_at=change}
  callback:=proc(user:rawptr,tick:u64,input:Reuse_Input)->Reuse_Input {
   c:=cast(^Reuse_Count)user;c.rewrites+=1;out:=input;if tick==c.change_at {out.add=5};return out
  }
  original:=r.correct(&a,truth,events[:],r.Input_Rewrite(Reuse_Input){user=&ac,apply=callback})
  result,reused:=r.correct_reusing(&b,truth,events[:],r.Input_Rewrite(Reuse_Input){user=&bc,apply=callback})
  testing.expect_value(t,original.error,r.Error.None);testing.expect_value(t,result.error,r.Error.None)
  testing.expect_value(t,original.steps,result.steps);testing.expect_value(t,ac.rewrites,10);testing.expect_value(t,bc.rewrites,10)
  testing.expect_value(t,bc.steps+reused,10);testing.expect(t,reused>0 && bc.steps<ac.steps)
  reuse_equal(t,&a,&b)
  // Audit must still execute all steps instead of trusting the reused records.
  bc.steps=0;testing.expect_value(t,r.audit(&b,3).error,r.Error.None);testing.expect_value(t,bc.steps,10)
 }
}
@(test)
reuse_still_fails_atomically_after_an_unchanged_prefix :: proc(t:^testing.T) {
 a:r.Timeline(Reuse_State,Reuse_Input,i32);defer r.destroy(&a)
 count:Reuse_Count;r.init(&a,r.Frame(Reuse_State){},reuse_step,cfg={16,4},user=&count)
 for _ in 0..<8 {r.advance(&a,Reuse_Input{add=1})}
 before,_:=r.current(&a);truth,_:=r.read(&a,2)
 rewrite:=r.Input_Rewrite(Reuse_Input){apply=proc(_:rawptr,tick:u64,input:Reuse_Input)->Reuse_Input {out:=input;if tick==7 {out.fail=true};return out}}
 result,reused:=r.correct_reusing(&a,truth,nil,rewrite)
 testing.expect_value(t,result.error,r.Error.Aborted);testing.expect_value(t,reused,0)
 after,_:=r.current(&a);testing.expect(t,reflect.equal(before,after));testing.expect_value(t,a.confirmed,u64(0))
 input,_:=r.read_input(&a,7);testing.expect(t,!input.fail)
}
Float_State :: struct {value:f32,bits:u32}
float_bits_step :: proc(w:^Float_State,input:u8,ctx:^r.Step(u32)) {w.bits=transmute(u32)w.value;r.emit(ctx,1,1,w.bits)}
@(test)
correction_reuse_distinguishes_signed_zero :: proc(t:^testing.T) {
 a:r.Timeline(Float_State,u8,u32);defer r.destroy(&a);r.init(&a,r.Frame(Float_State){},float_bits_step)
 for _ in 0..<3 {r.advance(&a,u8(0))}
 truth,_:=r.read(&a,1);truth.state.value=transmute(f32)u32(0x80000000)
 result,reused:=r.correct_reusing(&a,truth,nil)
 testing.expect_value(t,result.error,r.Error.None);testing.expect_value(t,reused,0)
 frame,_:=r.current(&a);testing.expect_value(t,frame.state.bits,u32(0x80000000))
}

@(test)
reused_prefix_does_not_hide_missing_suffix_or_invalid_authority_events :: proc(t:^testing.T) {
 a:r.Timeline(Reuse_State,Reuse_Input,i32);defer r.destroy(&a)
 r.init(&a,r.Frame(Reuse_State){},reuse_step,cfg={16,4})
 for _ in 0..<8 {r.advance(&a,Reuse_Input{add=1})}
 truth,_:=r.read(&a,2);before,_:=r.current(&a)
 a.records[7].valid=false
 result,reused:=r.correct_reusing(&a,truth,nil)
 testing.expect_value(t,result.error,r.Error.History_Missing);testing.expect_value(t,result.tick,u64(7));testing.expect_value(t,reused,0)
 testing.expect_value(t,a.confirmed,u64(0));after,_:=r.current(&a);testing.expect(t,reflect.equal(before,after))
 a.records[7].valid=true
 invalid:=[1]r.Occurrence(i32){{id={epoch=2,tick=2,source=1,key=1},value=2}}
 result,reused=r.correct_reusing(&a,truth,invalid[:]);testing.expect_value(t,result.error,r.Error.Invalid_Event);testing.expect_value(t,reused,0)
 testing.expect_value(t,a.confirmed,u64(0))
}
