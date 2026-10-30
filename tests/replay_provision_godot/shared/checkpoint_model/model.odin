package checkpoint_model

import net "godot:replay/net"
import r "godot:replay"
import a "godot:replay/assets"

World :: struct {value:u32,padding:[4096]u8,images:[2]a.Ref}
Server :: net.Server(World,u8,u8,u8,1)
model :: proc()->net.Model(World,u8,u8,u8,1) {
	return {step=proc(w:^World,c:[1]u8,_:u64,_:u64,_:^r.Step(u8)) {w.value+=u32(c[0])},
	 action=proc(w:^World,_:u16,a:u8,_:^r.Step(u8))->bool {w.value+=u32(a);return true},
	 control_valid=proc(c:u8)->bool{return c<=1},action_valid=proc(a:u8)->bool{return a==1},
	 state_valid=proc(w:World)->bool{return w.value<1000000},hold=proc(c:u8)->u8{return c}}
}
