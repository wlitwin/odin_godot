package main
import "core:fmt"
import "core:math"
import "core:time"
import "core:strings"
import r "godot:replay"
import sc "godot:replay/schema"
import delta "godot:replay/delta"
import game "../../examples/replay_scrapyard/shared/game"
Snapshot :: struct {snapshot_id,generation,serial,action_settled,input_newest:u64,frame:r.Frame(game.World),held:[game.SEATS]game.Control}
Input :: struct {fire:bool}
Group :: enum {History, Mobs, Shots, Players, Effects, Catalog, Layout, Other_World, Envelope}
Metric :: struct {changed,run_headers:u64}
LAGS :: [5]int{1,4,8,16,32}
step :: proc(w:^game.World,input:Input,ctx:^r.Step(game.Event)) {
 controls:[game.SEATS]game.Control
 if ctx.tick==1 {
  game.step(w,controls,3,0,ctx)
  for seat in u16(1)..=2 {
   assert(game.action(w,seat,game.Action{kind=.Profile,profile={name=game.name("profile"),iron=0,abilities={1,2}}},ctx))
   assert(game.action(w,seat,game.Action{kind=.Ready,ready=true},ctx))
  }
  assert(game.action(w,1,game.Action{kind=.Start},ctx))
 }
 if ctx.tick%6==0 && w.mobs.count<60 {
  living:=0;for alive,i in w.mobs.alive {if alive && w.mobs.values[i].hp>0 {living+=1}}
  for i in 0..<min(max(40-living,0),4) {
   index:=(u32(ctx.tick/6)*4+u32(i))%40
   assert(game.action(w,1,game.Action{kind=.Dev_Spawn,item=0,slot=1,aim={f32(100+index%5*24),f32(i32(index/5)*28-98)}},ctx))
  }
 }
 if input.fire {for seat in 0..<2 {
  nearest:=f32(1e30);aim:=[2]f32{1,0}
  for alive,i in w.mobs.alive {if alive && w.mobs.values[i].hp>0 {
   offset:=w.mobs.values[i].position-w.players[seat].position;d:=offset[0]*offset[0]+offset[1]*offset[1]
   if d<nearest && d>0.0001 {nearest=d;aim=offset/math.sqrt(d)}
  }}
  controls[seat]={aim=aim,fire=true}
 }}
 game.step(w,controls,0,0,ctx)
}
group :: proc(path:string)->Group {
 if !strings.has_prefix(path,"$.frame.state.") {return .Envelope}
 path:=path[len("$.frame.state."):]
 for prefix,i in ([7]string{"hit_history","mobs","shots","players","effects","catalog","layout"}) {
  if strings.has_prefix(path,prefix) {return Group(i)}
 }
 for prefix in ([3]string{"flashes","lobs","zones"}) {if strings.has_prefix(path,prefix) {return .Effects}}
 return .Other_World
}
get16 :: proc(bytes:[]u8)->int {return int(bytes[0])|int(bytes[1])<<8}
// Frozen selection order from the pre-optimization network path. The byte
// codecs remain independently checked; this includes its tiny-sparse LZ4 skip.
legacy_select :: proc(base,target,dst:[]u8,work:^delta.Lz4_Workspace)->(n:int,kind:delta.Encoding,ok:bool) {
 n,ok=delta.encode(base,target,dst);kind=.Sparse
 limit:=len(dst);if ok {limit=min(limit,n-1)}
 if limit>=max(1,(len(target)+254)/255) {
  if count,better:=delta.lz4_xor_encode(base,target,dst[:limit],work);better {return count,.Lz4,true}
 }
 return
}
main :: proc() {
 codec:sc.Schema;opts:=sc.DEFAULT_OPTIONS;opts.projection=.Public;assert(sc.init(&codec,Snapshot,opts).error==.None);defer sc.destroy(&codec)
 ownership:=make([]Group,codec.wire_size);defer delete(ownership)
 widths:[Group]int
 for field in codec.fields {g:=group(field.path);for offset in field.wire_offset..<field.wire_offset+field.width {ownership[offset]=g;widths[g]+=1}}
 total:=0;for width in widths {total+=width};assert(total==codec.wire_size)
 for g in Group {fmt.printf("WIRE group=%v bytes=%d\n",g,widths[g])}
 timeline:r.Timeline(game.World,Input,game.Event)
 w:=game.initial(encounter_count=0);w.rules=game.RUN_RULES;w.rules.base_count,w.rules.growth,w.rules.wave_count,w.rules.barrels=0,0,1,0
 w.catalog.mobs[0].bite=0;w.catalog.guns[0].mechanism.mag=255;w.catalog.guns[0].mechanism.jam_per_mille=0
 assert(r.init(&timeline,r.Frame(game.World){state=w},step,cfg={64,32})==.None);defer r.destroy(&timeline)
 cache:[64][]u8;for &bytes in cache {bytes=make([]u8,codec.wire_size)};defer for bytes in cache {delete(bytes)}
 encoded:=make([]u8,codec.wire_size*5+2);defer delete(encoded)
 legacy_time,lz4_time,old_selection_time,new_selection_time:[5]u64
 selection_winners:[5][delta.Encoding]u64
 metrics:[5][Group]Metric;raw,selected,compressed:[5]u64;samples:=0
 work:delta.Lz4_Workspace;compact:=make([]u8,codec.wire_size*2);defer delete(compact)
 decoded:=make([]u8,codec.wire_size);defer delete(decoded)
 old_selection,new_selection:[65535]u8
 shuffle_scratch:=make([]u8,2*codec.wire_size);defer delete(shuffle_scratch)
 shuffled_bytes,shuffle_ns,shuffle_wins,shuffle_attempts:[5]u64
 for tick in u64(1)..=1440 {
  assert(r.advance(&timeline,Input{fire=tick>240}).error==.None)
  frame,ok:=r.current(&timeline);assert(ok && game.state_valid(frame.state))
  value:=Snapshot{snapshot_id=tick,generation=1,serial=1,frame=frame}
  current:=cache[tick%64];assert(sc.encode(&codec,value,current).error==.None)
  if tick<=240 {continue};samples+=1
  for lag,li in LAGS {
   baseline:=cache[(tick-u64(lag))%64]
   began:=time.tick_now();size,ok:=delta.encode(baseline,current,encoded);legacy_time[li]+=u64(time.tick_since(began));assert(ok);raw[li]+=u64(size);selected[li]+=u64(min(size+48,codec.wire_size))
   began=time.tick_now();n,valid:=delta.lz4_xor_encode(baseline,current,compact,&work);lz4_time[li]+=u64(time.tick_since(began));assert(valid)
   assert(delta.lz4_xor_apply(baseline,compact[:n],decoded));for b,j in decoded {assert(b==current[j])}
   compressed[li]+=u64(min(n+48,min(size+48,codec.wire_size)))
   old_n,new_n:int;old_kind,new_kind:delta.Encoding;old_ok,new_ok:bool
   // Alternate order to avoid always warming the same candidate's input cache.
   for attempt in 0..<2 {
    began=time.tick_now()
    if (int(tick)+attempt)%2==0 {
     old_n,old_kind,old_ok=legacy_select(baseline,current,old_selection[:codec.wire_size-49],&work)
     old_selection_time[li]+=u64(time.tick_since(began))
    } else {
     new_n,new_kind,new_ok=delta.encode_smallest(baseline,current,new_selection[:codec.wire_size-49],&work)
     new_selection_time[li]+=u64(time.tick_since(began))
    }
   }
   assert(old_ok==new_ok)
   if old_ok {
    assert(old_n==new_n && old_kind==new_kind)
    for byte,j in old_selection[:old_n] {assert(byte==new_selection[j])}
    selection_winners[li][new_kind]+=1
   }
   best:=new_ok ? new_n+48 : codec.wire_size
   if !new_ok || new_n>=max(2048,codec.wire_size/16) {
    limit:=best-56-1
    if limit>0 {
     began=time.tick_now()
     count,better:=delta.shuffle_lz4_encode(&codec,baseline,current,compact[:limit],&work,shuffle_scratch)
     shuffle_ns[li]+=u64(time.tick_since(began));shuffle_attempts[li]+=1
     if better {
      assert(delta.shuffle_lz4_apply(&codec,baseline,compact[:count],decoded,shuffle_scratch))
      for byte,j in decoded {assert(byte==current[j])}
      best=count+56;shuffle_wins[li]+=1
     }
    }
   }
   shuffled_bytes[li]+=u64(best)
   cursor:=2
   for _ in 0..<get16(encoded[:2]) {
    at,count:=get16(encoded[cursor:cursor+2]),get16(encoded[cursor+2:cursor+4]);cursor+=4
    metrics[li][ownership[at]].run_headers+=4
    for j in at..<at+count {metrics[li][ownership[j]].changed+=1}
    cursor+=count
   }
   assert(cursor==size)
  }
 }
 for lag,li in LAGS {
  sum:=u64(2*samples)
  for g in Group {m:=metrics[li][g];sum+=m.changed+m.run_headers;fmt.printf("DELTA lag=%d group=%v changed_mean=%.3f headers_mean=%.3f\n",lag,g,f64(m.changed)/f64(samples),f64(m.run_headers)/f64(samples))}
  fmt.printf("COST lag=%d sparse_ns=%.3f lz4_ns=%.3f\n",lag,f64(legacy_time[li])/f64(samples),f64(lz4_time[li])/f64(samples))
  fmt.printf("SELECTION lag=%d old_ns=%.3f bounded_ns=%.3f sparse=%d lz4=%d\n",lag,f64(old_selection_time[li])/f64(samples),f64(new_selection_time[li])/f64(samples),selection_winners[li][.Sparse],selection_winners[li][.Lz4])
  fmt.printf("SHUFFLE lag=%d arrays=%d selected_mean=%.3f extra_ns=%.3f attempts=%d wins=%d\n",lag,len(codec.arrays),f64(shuffled_bytes[li])/f64(samples),f64(shuffle_ns[li])/f64(samples),shuffle_attempts[li],shuffle_wins[li])
  assert(sum==raw[li]);fmt.printf("TOTAL lag=%d raw_mean=%.3f selected_mean=%.3f lz4_selected_mean=%.3f\n",lag,f64(raw[li])/f64(samples),f64(selected[li])/f64(samples),f64(compressed[li])/f64(samples))
 }
 frame,_:=r.current(&timeline)
 fmt.printf("PAYLOAD_PROFILE_OK bytes=%d samples=%d kills=%d shots=%d hash=%d\n",codec.wire_size,samples,frame.state.players[0].kills+frame.state.players[1].kills,frame.state.players[0].shots+frame.state.players[1].shots,sc.digest(cache[1440%64]))
}
