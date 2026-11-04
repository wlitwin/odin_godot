//gd:extends Node
//gd:class ProductionQuotaProbe
package production_quota_probe

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import gd "godot:godot"
import b "godot:box3d"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"
import bd "godot:box3d/diagnostics"
import k "godot:kit/sim"
import ks "godot:kit/session"
import kp "godot:kit/physics"
import r "godot:replay"
import rn "godot:replay/net"
import rp "godot:replay/physics"
import quota "godot:tests/box3d_modules/quota_fixture"

Game :: struct {tick:u64,key:b.Body_Key}
Control :: struct {axis:i32}
PROFILE :: u64(0x50524f4451554f31)
Kit_Source :: struct {
 lane:k.Lane,session:ks.Session,physics:kp.Instance(Game),sdk:kp.SDK_Context,
 provider,author:kp.SDK_User_Owner,
}
Replay_Source :: struct {
 timeline:r.Timeline(Game,rn.Batch(Control,u8,1),rn.Net_Event(u8)),
 codec:rp.Network_Codec(Game,Control,u8,u8,1),model:rn.Model(Game,Control,u8,u8,1),
 memory:^bm.Context,image_owner,codec_owner,model_owner:rp.Owner_Context,
 catalog:b.Recovery_Catalog,
}
ProductionQuotaProbe :: struct {owner:gd.Node,kit:^Kit_Source,replay:^Replay_Source,pressure:quota.Context,aux:b.World}
Case :: struct {
 framework,operation,error:string,
 setup,exact64m,extra_byte_rejected,operation_rejected,aux_unchanged,full_state_preserved,resumed,cleanup:bool,
 admitted_before,actual_storage_bytes,admitted_at,admitted_after_refusal:u64,
}
Report :: struct {ok:bool,cases:[2]Case,native,wrapper,meter,owners_before,owners_after:u64,observed:bool}

world :: proc()->(b.World,Game,b.Status){
 d:=b.world_def_default();d.gravity={0,0,0};w,status:=b.world_create(d);if status!=.Ok{return 0,{},status}
 body_def:=b.body_def_default();body_def.type=.Dynamic;body_def.pose.position={0,2,0};body,bs:=b.body_create(w,body_def)
 if bs!=.Ok{b.world_destroy(&w);return 0,{},bs}
 _,ss:=b.shape_box(body,b.shape_def_default(),{.25,.25,.25});if ss!=.Ok{b.world_destroy(&w);return 0,{},ss}
 key,key_status:=b.body_key(body);return w,Game{key=key},key_status
}
kit_step :: proc(user:rawptr,tick:u64){s:=cast(^Kit_Source)user;state:=kp.state(&s.physics);state.tick=tick}
replay_step :: proc(game:^Game,_:[1]Control,_,_:u64,ctx:^r.Step(u8)){
 if rp.body_impulse(ctx.execution,game.key,{.01,0,0})!=.None||rp.step(ctx.execution)!=.None{r.abort(ctx);return};game.tick=ctx.tick
}
kit_open :: proc(self:^ProductionQuotaProbe)->bool{
 sdk,error:=kp.sdk_context_create();if error!=.Ok{return false};allocator:=bm.allocator(sdk.memory)
 s:=new(Kit_Source,allocator);if s==nil{kp.sdk_context_destroy(&sdk);return false};self.kit=s;s.sdk=sdk
 s.provider,error=kp.sdk_user_owner_create(sdk.memory,s,size_of(Kit_Source),&s.physics,size_of(s.physics));if error!=.Ok{return false}
 s.author,error=kp.sdk_user_owner_create(sdk.memory,s,size_of(Kit_Source),s,size_of(Kit_Source));if error!=.Ok{return false}
 s.session.is_host=true;s.session.me=1;k.lane_init(&s.lane,&s.session,0,allocator=allocator);k.lane_set_sim(&s.lane,s,nil,kit_step)
 w,game,status:=world();if status!=.Ok{return false};defer if w!=0{b.world_destroy(&w)}
 config:=kp.sdk_context_config(s.sdk,PROFILE,s.provider,s.author)
 if kp.attach(&s.physics,&s.lane,&w,game,nil,config)!=.Ok{return false}
 return k.lane_frame(&s.lane,1.0/60)==1
}
replay_open :: proc(self:^ProductionQuotaProbe)->bool{
 memory,ms:=bm.create(bg.service_get(),bg.CATEGORY_REPLAY_PROVIDER);if ms!=bg.OK{return false};allocator:=bm.allocator(memory)
 s:=new(Replay_Source,allocator);if s==nil{bm.destroy(&memory);return false};self.replay=s;s.memory=memory
 error:r.Error;s.image_owner,error=rp.owner_context_create(bm.data_lease(memory),allocator_data=allocator.data,require_live_instance=false);if error!=.None{return false}
 lease,ls:=bm.block_lease(memory,s,size_of(Replay_Source),&s.codec,size_of(s.codec));if ls!=bg.OK{return false}
 s.codec_owner,error=rp.owner_context_create(lease,user_data=&s.codec,require_live_instance=false);if error!=.None{return false}
 model_lease,ml:=bm.block_lease(memory,s,size_of(Replay_Source),&s.model,size_of(s.model));if ml!=bg.OK{return false}
 s.model_owner,error=rp.owner_context_create(model_lease,user_data=&s.model,require_live_instance=false);if error!=.None{return false}
 config:=b.recovery_config_default();config.profile=PROFILE
 assets:=[1]b.Recovery_Asset{{id=1,kind=.Box,a={.25,.25,.25}}};status:b.Status;s.catalog,status=b.recovery_catalog_create(config,assets[:]);if status!=.Ok{return false}
 provider:=rp.config_default(PROFILE,b.build_fingerprint());provider.initial_dynamic_bodies=1;provider.asset_count=1;provider.assets[0]={id=1,kind=.Box,shape=b.shape_def_default(),half_extents={.25,.25,.25}}
 w,game,ws:=world();if ws!=.Ok{return false};defer b.world_destroy(&w)
 initial,ie:=rp.checkpoint_make(r.Frame(Game){state=game},rn.Net_Event(u8),w,provider,allocator=allocator,ownership=s.image_owner,catalog=&s.catalog);if ie!=.None{return false};defer r.complete_checkpoint_destroy(&initial)
 if rp.network_codec_init(&s.codec,&s.catalog,provider,bd.hash_bytes(transmute([]u8)string("production-public-quota.v1")),allocator=allocator,ownership=s.image_owner,context_ownership=s.codec_owner)!=.None{return false}
 s.model={complete_state=true,complete_codec=s.codec.value,step=replay_step,control_valid=proc(Control)->bool{return true},action_valid=proc(value:u8)->bool{return value==0},state_valid=proc(game:Game)->bool{return game.key!=0}}
 if r.init_complete(&s.timeline,&initial,rn.model_callback(Game,Control,u8,u8,1),{128,32},user=&s.model,allocator=allocator,user_owner=s.model_owner.owner,user_data=&s.model)!=.None{return false}
 return r.advance(&s.timeline,rn.Batch(Control,u8,1){}).error==.None
}

close_all :: proc(self:^ProductionQuotaProbe)->bool{
 // Pressure release comes before typed adapters and their actual creators.
 if quota.destroy(&self.pressure)!=bg.OK{return false}
 if self.aux!=0{if b.world_destroy(&self.aux)!=.Ok{return false}}
 if self.kit!=nil{
  s:=self.kit;sdk:=s.sdk;allocator:=bm.allocator(sdk.memory)
  if kp.detach(&s.physics)!=.Ok{return false};k.lane_destroy(&s.lane);ks.session_destroy(&s.session)
  if kp.sdk_user_owner_destroy(&s.provider)!=.Ok||kp.sdk_user_owner_destroy(&s.author)!=.Ok{return false}
  mem.free(s,allocator);self.kit=nil;if kp.sdk_context_destroy(&sdk)!=.Ok{return false}
 }
 if self.replay!=nil{
  s:=self.replay;memory:=s.memory;allocator:=bm.allocator(memory);r.destroy(&s.timeline)
  if s.codec.ready||s.codec.catalog._handle!=nil{if rp.network_codec_destroy(&s.codec)!=.None{return false}}
  if b.recovery_catalog_destroy(&s.catalog)!=.Ok{return false}
  if rp.owner_context_destroy(&s.model_owner)!=.None||rp.owner_context_destroy(&s.codec_owner)!=.None||rp.owner_context_destroy(&s.image_owner)!=.None{return false}
  mem.free(s,allocator);self.replay=nil;if bm.destroy(&memory)!=bg.OK{return false}
 }
 return true
}
pressure_open :: proc(self:^ProductionQuotaProbe,c:^Case)->bool{
 w,_,status:=world();if status!=.Ok{return false};self.aux=w
 if quota.init(&self.pressure,w,0x51554f54414f574e)!=bg.OK{return false}
 before,bs:=quota.admitted();if bs!=bg.OK||before>=67108864{return false};c.admitted_before=before;c.actual_storage_bytes=67108864-before
 if quota.allocate(&self.pressure,c.actual_storage_bytes)!=bg.OK{return false}
 full,fs:=quota.admitted();c.admitted_at=full;c.exact64m=fs==bg.OK&&full==67108864
 c.extra_byte_rejected=quota.allocate(&self.pressure,1,slot=1)==bg.CAPACITY
 after,after_status:=quota.admitted();c.admitted_after_refusal=after;c.aux_unchanged=quota.probe(&self.pressure)
 return c.exact64m&&c.extra_byte_rejected&&after_status==bg.OK&&after==full&&c.aux_unchanged
}
release_pressure :: proc(self:^ProductionQuotaProbe){
 if self.pressure.meter==nil{return}
 for &block in self.pressure.blocks{delete(block,self.pressure.allocator);block=nil}
}

kit_case :: proc(self:^ProductionQuotaProbe)->Case{
 c:=Case{framework="Kit",operation="lane_world_checkpoint"};c.setup=kit_open(self);if !c.setup{c.error="kit.setup";c.cleanup=close_all(self);return c}
 s:=self.kit;before,be:=k.lane_world_checkpoint(&s.lane,1)
 if be!=.Ok{c.error="kit.before";c.cleanup=close_all(self);return c}
 if pressure_open(self,&c){candidate,error:=k.lane_world_checkpoint(&s.lane,1);c.operation_rejected=error!=.Ok;_=k.world_checkpoint_destroy(&candidate)}else{c.error="kit.pressure"}
 admitted,as:=quota.admitted();c.admitted_after_refusal=admitted;if as!=bg.OK||admitted!=67108864{c.error="kit.refusal.ledger"}
 release_pressure(self)
 after,ae:=k.lane_world_checkpoint(&s.lane,1)
 if ae==.Ok{equal,ee:=k.world_checkpoint_equal(&before,&after);c.full_state_preserved=ee==.Ok&&equal}
 _=k.world_checkpoint_destroy(&after);_=k.world_checkpoint_destroy(&before)
 c.resumed=k.lane_frame(&s.lane,1.0/60)==1;c.cleanup=close_all(self);return c
}
replay_case :: proc(self:^ProductionQuotaProbe)->Case{
 c:=Case{framework="Replay",operation="advance managed complete tick"};c.setup=replay_open(self);if !c.setup{c.error="replay.setup";c.cleanup=close_all(self);return c}
 s:=self.replay;allocator:=bm.allocator(s.memory);before,be:=r.capture_complete(&s.timeline,1,allocator)
 if be!=.None{c.error="replay.before";c.cleanup=close_all(self);return c}
 if pressure_open(self,&c){result:=r.advance(&s.timeline,rn.Batch(Control,u8,1){});c.operation_rejected=result.error!=.None&&s.timeline.head==1}else{c.error="replay.pressure"}
 admitted,as:=quota.admitted();c.admitted_after_refusal=admitted;if as!=bg.OK||admitted!=67108864{c.error="replay.refusal.ledger"}
 release_pressure(self)
 after,ae:=r.capture_complete(&s.timeline,1,allocator)
 if ae==.None{
  a,ad:=rn.complete_view(s.codec.value,&before,&s.codec.state,&s.codec.occurrence,allocator)
  z,zd:=rn.complete_view(s.codec.value,&after,&s.codec.state,&s.codec.occurrence,allocator)
  if ad==.None&&zd==.None{c.full_state_preserved=true;for part in bd.Part{c.full_state_preserved=c.full_state_preserved&&mem.compare(a.frame.parts[part],z.frame.parts[part])==0}}
  rn.complete_view_destroy(&a);rn.complete_view_destroy(&z)
 }
 r.complete_checkpoint_destroy(&after);r.complete_checkpoint_destroy(&before)
 c.resumed=r.advance(&s.timeline,rn.Batch(Control,u8,1){}).error==.None;c.cleanup=close_all(self);return c
}
owner_count :: proc()->(u64,bool){contract,cs:=b.domain_contract_get();if cs!=.Ok{return 0,false};ledger,ls:=b.host_ledger_get(contract.cookie);return u64(ledger.owner_count),ls==.Ok}
case_ok :: proc(c:Case)->bool{return c.setup&&c.exact64m&&c.extra_byte_rejected&&c.operation_rejected&&c.aux_unchanged&&c.full_state_preserved&&c.resumed&&c.cleanup&&len(c.error)==0}
@(gd_method)
production_quota_probe_exercise :: proc(self:^ProductionQuotaProbe)->gd.String{
 context=runtime.default_context()
 result:Report;before,bo:=owner_count();result.owners_before=before
 result.cases[0]=kit_case(self);result.cases[1]=replay_case(self)
 native,ns:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats();kit,ks:=bm.category_stats(bg.CATEGORY_KIT_CORE);provider,ps:=bm.category_stats(bg.CATEGORY_REPLAY_PROVIDER);codec,cs:=bm.category_stats(bg.CATEGORY_REPLAY_CODEC)
 after,ao:=owner_count();result.native=native.live_bytes;result.wrapper=wrapper.live_bytes;result.meter=kit.live_bytes+provider.live_bytes+codec.live_bytes;result.owners_after=after;result.observed=bo&&ao&&ns==.Ok&&ws==.Ok&&ks==bg.OK&&ps==bg.OK&&cs==bg.OK
 result.ok=case_ok(result.cases[0])&&case_ok(result.cases[1])&&result.observed&&result.native==0&&result.wrapper==0&&result.meter==0&&before==after
 bytes,error:=json.marshal(result);if error!=nil{return gd.new_string_odin("{\"ok\":false,\"error\":\"JSON\"}")};defer delete(bytes)
 fmt.printf("PRODUCTION_PUBLIC_QUOTA %s\n",string(bytes));return gd.new_string_odin(string(bytes))
}
production_quota_probe_exit_tree :: proc(self:^ProductionQuotaProbe){if !close_all(self){gd.print_str("PRODUCTION_PUBLIC_QUOTA_CLEANUP_FAIL")}}
