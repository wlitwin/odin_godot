package steam_core_test

import "core:testing"
import "core:reflect"
import auth "godot:replay/authority"
import gd "godot:godot"
import rgd "godot:replay/godot"

@(test)
steam_authority_endpoints_roundtrip_full_ids_and_virtual_port_zero :: proc(t:^testing.T) {
 for id in ([3]u64{1,76561198000000001,max(u64)}) {
  for port in ([3]u16{0,1,max(u16)}) {
   endpoint,ok:=rgd.steam_endpoint(id,port);testing.expect(t,ok)
   actual_id,actual_port,valid:=rgd.steam_endpoint_read(endpoint)
   testing.expect(t,valid && actual_id==id && actual_port==port)
  }
 }
 for text in ([]string{"127.0.0.1","steam:0:0","steam:01:0","steam:1:00","steam:1:65536","steam:1:-1","steam:1:1:2","steam:1:","steam:18446744073709551616:1"}) {
  endpoint,ok:=auth.endpoint(text,1);assert(ok)
  _,_,valid:=rgd.steam_endpoint_read(endpoint);testing.expect(t,!valid)
 }
 endpoint,_:=rgd.steam_endpoint(1,0);endpoint.port=2
 _,_,valid:=rgd.steam_endpoint_read(endpoint);testing.expect(t,!valid)
 endpoint,_=rgd.steam_endpoint(1,0);endpoint.host[95]=1
 _,_,valid=rgd.steam_endpoint_read(endpoint);testing.expect(t,!valid)
}

@(test)
steam_target_is_scoped_to_authenticated_endpoint_and_local_host_identity :: proc(t:^testing.T) {
 runtime:=rgd.Steam_Runtime{ready=true,steam_id=11}
 config:=rgd.STEAM_CONFIG;config.runtime=&runtime;config.host_steam_id=999;config.virtual_port=90
 before:=config
 endpoint,_:=rgd.steam_endpoint(22,0)
 target,ok:=rgd.steam_target(config,endpoint,false)
 testing.expect(t,ok && target.host_steam_id==22 && target.virtual_port==0 && target.runtime==&runtime)
 _,ok=rgd.steam_target(config,endpoint,true);testing.expect(t,!ok)
 endpoint,_=rgd.steam_endpoint(11,65535)
 target,ok=rgd.steam_target(config,endpoint,true);testing.expect(t,ok && target.virtual_port==65535)
 testing.expect(t,reflect.equal(config,before))
 config.peer=cast(gd.Multiplayer_Peer)rawptr(uintptr(1))
 _,ok=rgd.steam_target(config,endpoint,true);testing.expect(t,!ok)
 config.peer=nil;runtime.ready=false
 _,ok=rgd.steam_target(config,endpoint,false);testing.expect(t,!ok)
}
