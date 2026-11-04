package replay_godot_transport

import "base:runtime"
import "core:mem"
import r "godot:replay"
import bg "godot:box3d/godot"
import rt "godot:runtime"
import gd "godot:godot"
import "godot:gdext"
import tr "godot:replay/transport"

Rtc_Ownership :: struct {allocator,container,configuration,ice,authorization:r.Owned_Context}
rtc_prepare :: proc(rtc:^Rtc,ownership:Rtc_Ownership)->bg.Status{
 if rtc==nil{return bg.INVALID_ARGUMENT}
 if r.owned_context_access(ownership.container,rtc,true,.Execute)!=.None{return bg.INCOMPATIBLE}
 if rtc.ready||rtc.retained.count!=0{return bg.INVALID_ARGUMENT}
 rtc.ownership=ownership;return bg.OK
}
@(private)
rtc_managed :: proc(rtc:^Rtc)->bool{return !r.owner_is_nil(rtc.ownership.container.owner)}
@(private)
rtc_ownership_open :: proc(rtc:^Rtc,cfg:Rtc_Config,allocator:mem.Allocator)->bool{
 managed:=rtc_managed(rtc)
 if r.owner_contexts_check({owner=rtc.ownership.allocator.owner,owner_allocator_data=rtc.ownership.allocator.data},allocator)!=.None ||
  r.owned_context_access(rtc.ownership.container,rtc,managed,.Execute)!=.None{return false}
 if !managed{return true}
 if r.owner_is_nil(rtc.ownership.allocator.owner)||r.owned_context_access(rtc.ownership.configuration,&rtc.config,true,.Execute)!=.None{return false}
 if cfg.ice_source!=nil&&(r.owner_is_nil(rtc.ownership.ice.owner)||r.owned_context_access(rtc.ownership.ice,cfg.ice_user,true,.Execute)!=.None){return false}
 if cfg.authorize!=nil&&(r.owner_is_nil(rtc.ownership.authorization.owner)||r.owned_context_access(rtc.ownership.authorization,cfg.authorization_user,true,.Execute)!=.None){return false}
 owners:=[?]r.Owner{rtc.ownership.allocator.owner,rtc.ownership.container.owner,rtc.ownership.configuration.owner,rtc.ownership.ice.owner,rtc.ownership.authorization.owner}
 return r.owner_retains_acquire(&rtc.retained,owners[:])==.None
}
@(private)
Rtc_Payload :: struct {owner:r.Owner,retained:r.Owner_Retains,allocator:mem.Allocator,transport:^Rtc,index:int,serial:u64,description:bool}
@(private)
RTC_SIGNAL :: u32(0x52544301)
@(private)
rtc_callable :: proc(rtc:^Rtc,index:int,description:bool)->(rt.Managed_Callable,bg.Status){
 service:=bg.service_get();if service.capsule_create==nil{return {},bg.UNSUPPORTED}
 payload,error:=mem.new_clone(Rtc_Payload{owner=rtc.ownership.container.owner,allocator=rtc.allocator,transport=rtc,index=index,serial=rtc.slots[index].serial,description=description},rtc.allocator)
 if error!=.None{return {},bg.OUT_OF_MEMORY}
 owners:=[?]r.Owner{rtc.ownership.allocator.owner,rtc.ownership.container.owner}
 if r.owner_retains_acquire(&payload.retained,owners[:])!=.None{retained:=payload.retained;mem.free(payload,rtc.allocator);r.owner_retains_drop(&retained);return {},bg.INCOMPATIBLE}
 capsule:bg.Capsule
 status:=service.capsule_create(service.user,&payload.owner,payload,rtc_dispatch,&capsule)
 if status!=bg.OK{retained:=payload.retained;mem.free(payload,rtc.allocator);r.owner_retains_drop(&retained);return {},status}
 handle,created:=rt.managed_callable_create(&capsule,RTC_SIGNAL)
 if created!=bg.OK{capsule.destroy(capsule.user);return {},created}
 return handle,bg.OK
}
@(private)
rtc_dispatch :: proc "c"(data:rawptr,operation:u32,args:rawptr)->bg.Status{
 context=rt.script_context()
 temp:=runtime.default_temp_allocator_temp_begin();defer runtime.default_temp_allocator_temp_end(temp)
 payload:=cast(^Rtc_Payload)data
 if payload==nil||r.owner_access(payload.owner)!=.None{return bg.INCOMPATIBLE}
 if operation==bg.CAPSULE_DESTROY{
  retained,allocator:=payload.retained,payload.allocator
  mem.free(payload,allocator)
  return r.owner_retains_drop(&retained)==.None?bg.OK:bg.INCOMPATIBLE
 }
 if operation!=RTC_SIGNAL||args==nil{return bg.INVALID_ARGUMENT}
 if r.owner_access(payload.owner,.Execute)!=.None{return bg.INCOMPATIBLE}
 rtc:=payload.transport
 if rtc.cleanup||payload.index<0||payload.index>=len(rtc.slots){return bg.INCOMPATIBLE}
 peer:=&rtc.slots[payload.index]
 if peer.conn==nil||peer.serial!=payload.serial||peer.failed{return bg.INCOMPATIBLE}
 call:=cast(^rt.Managed_Callable_Args)args
 expected:=payload.description?i32(2):i32(3)
 if call.reserved!=0||call.count!=expected||call.variants==nil||call.result==nil||call.error==nil{return bg.INVALID_ARGUMENT}
 variants:=cast([^]gdext.VariantPtr)call.variants
 if gdext.variant_get_type(variants[0])!=.String{return bg.INVALID_ARGUMENT}
 if payload.description{
  if gdext.variant_get_type(variants[1])!=.String{return bg.INVALID_ARGUMENT}
  rtc_description_effect(peer,variants,i64(call.count),cast(gdext.VariantPtr)call.result,cast(^gdext.CallError)call.error)
 }else{
  if gdext.variant_get_type(variants[1])!=.Int||gdext.variant_get_type(variants[2])!=.String{return bg.INVALID_ARGUMENT}
  rtc_ice_effect(peer,variants,i64(call.count),cast(gdext.VariantPtr)call.result,cast(^gdext.CallError)call.error)
 }
 return bg.OK
}

// Refuse recursive destruction while producer callbacks are on the stack.
rtc_try_close :: proc(rtc:^Rtc)->bg.Status{
 if rtc==nil{return bg.INVALID_ARGUMENT}
 managed:=rtc_managed(rtc)
 if managed{
  if r.owned_context_access(rtc.ownership.container,rtc,true)!=.None{return bg.INCOMPATIBLE}
  if rtc.callback_depth!=0{return rt.MANAGED_CALLABLE_BUSY}
  stats,status:=rt.managed_callable_stats();if status!=bg.OK{return status}
  if stats.inflight_calls!=0{return rt.MANAGED_CALLABLE_BUSY}
 }
 rtc.cleanup=true
 for &peer in rtc.slots{status:=rtc_peer_try_close(&peer);if status!=bg.OK{return status}}
 if rtc.ready{
  tr.fragments_destroy(&rtc.fragments)
  if rtc.ws!=nil{gd.web_socket_peer_close(rtc.ws,1000,gd.string_empty());rtc_unref(rtc.ws);rtc.ws=nil}
  delete(rtc.config.url,rtc.allocator);delete(rtc.config.room,rtc.allocator);delete(rtc.config.ice_json,rtc.allocator)
  delete(rtc.room,rtc.allocator);delete(rtc.resume_token,rtc.allocator)
 }
 retained:=rtc.retained;rtc^={}
 if r.owner_retains_drop(&retained)!=.None{rtc.retained=retained;rtc.cleanup=true;return bg.INCOMPATIBLE}
 return bg.OK
}
@(private)
rtc_ice_value :: proc(rtc:^Rtc)->(string,bool){
 if rtc.config.ice_source==nil{return rtc.config.ice_json,true}
 if rtc_managed(rtc)&&r.owned_context_access(rtc.ownership.ice,rtc.config.ice_user,true,.Execute)!=.None{return "",false}
 if rtc.callback_depth==max(u32){return "",false}
 rtc.callback_depth+=1;defer rtc.callback_depth-=1
 return rtc.config.ice_source(rtc.config.ice_user)
}
@(private)
rtc_authorization_value :: proc(rtc:^Rtc,challenge,room:string,create:bool)->string{
 if rtc.config.authorize==nil{return ""}
 if rtc_managed(rtc)&&r.owned_context_access(rtc.ownership.authorization,rtc.config.authorization_user,true,.Execute)!=.None{return ""}
 if rtc.callback_depth==max(u32){return ""}
 rtc.callback_depth+=1;defer rtc.callback_depth-=1
 return rtc.config.authorize(rtc.config.authorization_user,challenge,room,create)
}
