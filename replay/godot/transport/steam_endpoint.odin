package replay_godot_transport

import "core:fmt"
import "core:strings"
import auth "godot:replay/authority"

// Explicit transport namespace within the unchanged coordinator Endpoint shape.
// Port 1 is a format sentinel; the full Steam virtual port (including zero) is
// encoded in the host text, not interpreted as an IP/ENet destination.
steam_endpoint :: proc(id:u64,virtual_port:u16)->(auth.Endpoint,bool) {
 if id==0 {return {},false}
 return auth.endpoint(fmt.tprintf("steam:%d:%d",id,virtual_port),1)
}
steam_endpoint_read :: proc(endpoint:auth.Endpoint)->(u64,u16,bool) {
 if endpoint.port!=1 {return 0,0,false}
 endpoint:=endpoint
 end:=strings.index_byte(string(endpoint.host[:]),0)
 if end<1 {return 0,0,false}
 for byte in endpoint.host[end:] {if byte!=0 {return 0,0,false}}
 text:=string(endpoint.host[:end])
 if !strings.has_prefix(text,"steam:") {return 0,0,false}
 text=text[len("steam:"):]
 separator:=strings.index_byte(text,':')
 if separator<1 || separator==len(text)-1 {return 0,0,false}
 id_text,port_text:=text[:separator],text[separator+1:]
 if (len(id_text)>1 && id_text[0]=='0') || (len(port_text)>1 && port_text[0]=='0') || len(port_text)>5 {return 0,0,false}
 id,ok:=steam_parse_id(id_text);if !ok {return 0,0,false}
 port:=u32(0)
 for digit in port_text {
  if digit<'0' || digit>'9' {return 0,0,false}
  port=port*10+u32(digit-'0');if port>u32(max(u16)) {return 0,0,false}
 }
 return id,u16(port),true
}

// Bind the destination exclusively to an authenticated coordinator endpoint.
// The caller retains its own runtime/factory, never a peer from another process.
steam_target :: proc(config:Steam_Config,endpoint:auth.Endpoint,hosting:bool)->(Steam_Config,bool) {
 id,port,valid:=steam_endpoint_read(endpoint)
 if !valid || config.runtime==nil || !config.runtime.ready || config.runtime.steam_id==0 ||
    config.peer!=nil || config.max_peers<1 || config.max_peers>4095 || (hosting && config.runtime.steam_id!=id) {return {},false}
 result:=config;result.host_steam_id,result.virtual_port=id,port
 return result,true
}
