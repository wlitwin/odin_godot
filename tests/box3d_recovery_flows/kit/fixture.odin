package kit_recovery_flows_test

import "core:testing"
import n "godot:kit/net"
import k "godot:kit/sim"
import s "godot:kit/session"
import f "godot:tests/kit_box3d_net"
import wp "godot:tests/kit_world_protocol"

// Only test endpoint identity and existing public Session construction. The
// authority Session/Lane is never restarted when enrolling a later endpoint.
enroll :: proc(box:^f.Box,peer:s.Peer_Id,token:u64,spectator:bool){
 box.peer=peer
 s.session_client_start(&box.ses,token,"later endpoint",spectate=spectator)
 s.session_set_transport(&box.ses,box,f.send)
 s.session_client_join(&box.ses)
}

parts_at :: proc(t:^testing.T,authority,replica:^f.Box,tick:u64){
 a,z:k.World_Diagnostic_Frame
 testing.expect_value(t,k.lane_world_diagnostic_frame(&authority.lane,tick,&a),k.World_Error.Ok)
 defer k.world_diagnostic_frame_destroy(&a)
 testing.expect_value(t,k.lane_world_diagnostic_frame(&replica.lane,tick,&z),k.World_Error.Ok)
 defer k.world_diagnostic_frame_destroy(&z)
 f.diagnostic_expect_parts(t,&a,&z)
}

save_frame :: proc(t:^testing.T,box:^f.Box,tick:u64,out:^k.World_Diagnostic_Frame)->bool{
 error:=k.lane_world_diagnostic_frame(&box.lane,tick,out)
 testing.expect_value(t,error,k.World_Error.Ok);return error==.Ok
}

expect_saved :: proc(t:^testing.T,box:^f.Box,saved:^k.World_Diagnostic_Frame){
 current:k.World_Diagnostic_Frame
 if !save_frame(t,box,saved.view.tick,&current){return}
 defer k.world_diagnostic_frame_destroy(&current)
 f.diagnostic_expect_parts(t,saved,&current)
}

expect_control :: proc(t:^testing.T,box:^f.Box,tick:u64,player:n.Player_Id,axis:i32){
 bytes,_,_,error:=k.lane_world_accepted_input(&box.lane,tick,player,0)
 testing.expect_value(t,error,k.World_Error.Ok)
 if error==.Ok{testing.expect_value(t,(cast(^f.Control)raw_data(bytes)).axis,axis)}
}

no_observer_sample :: proc(_:rawptr,_:u64,_:rawptr){
 assert(false,"zero-only spectator consumer must never sample a local predicted control")
}

advance_authority :: proc(t:^testing.T,host:^f.Box,target:u64)->bool{
 for k.lane_now(&host.lane)<target{if !wp.advance_one(t,host){return false}}
 return true
}

expect_usage :: proc(t:^testing.T,before:wp.Usage,diagnostics:u64){
 testing.expect_value(t,wp.usage(t),before)
 testing.expect_value(t,k.world_diagnostic_frame_owned_bytes(),diagnostics)
}
