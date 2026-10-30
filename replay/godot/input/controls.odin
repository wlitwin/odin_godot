package replay_godot_input

import gd "godot:godot"
import r "godot:replay"

Input_Action :: struct {name:string,bit:u8}
Input_Binding :: struct($Control:typeid) {
    names:[64]gd.String_Name,bits:[64]u8,count:int,
    capture:r.Control_Capture,
    neutral:Control,
    user:rawptr,
    mapper:proc(rawptr,r.Buttons)->Control,
    ready:bool,
}
// Godot action names are interned once. The owner must remain outside World;
// user is borrowed until destroy. Map returns a detached game Control value.
input_binding_init :: proc(b:^Input_Binding($Control),actions:[]Input_Action,neutral:Control,
                           mapper:proc(rawptr,r.Buttons)->Control,user:rawptr=nil)->bool {
    if b.ready || len(actions)==0 || len(actions)>64 || mapper==nil || !r.value_supported(Control) {return false}
    used:u64
    for action,i in actions {
        if len(action.name)==0 || action.bit>=64 || used&(u64(1)<<action.bit)!=0 {return false}
        for prior in actions[:i] {if action.name==prior.name {return false}}
        used|=u64(1)<<action.bit
    }
    b.neutral,b.mapper,b.user=neutral,mapper,user
    for action,i in actions {b.names[i]=gd.new_string_name(action.name);b.bits[i]=action.bit}
    b.count,b.ready=len(actions),true;return true
}
input_binding_destroy :: proc(b:^Input_Binding($Control)) {for name in b.names[:b.count] {gd.free_string_name(name)};b^={}}
// Sample exactly once per engine frame. Multiple simulation steps may read the
// current controls; consume edges only after a committed tick/submission.
input_binding_sample :: proc(b:^Input_Binding($Control),gates:r.Input_Gates={})->bool {
    if !b.ready {return false}
    held,pressed,released:u64;input:=gd.singleton_input()
    for name,i in b.names[:b.count] {
        bit:=u64(1)<<b.bits[i]
        if gd.input_is_action_pressed(input,name,false) {held|=bit}
        if gd.input_is_action_just_pressed(input,name,false) {pressed|=bit}
        if gd.input_is_action_just_released(input,name,false) {released|=bit}
    }
    r.controls_capture(&b.capture,held,pressed,released,gates);return true
}
input_binding_read :: proc(b:^Input_Binding($Control))->Control {
    if !b.ready || b.capture.blocked {return b.neutral}
    return b.mapper(b.user,b.capture.buttons)
}
input_binding_consume :: proc(b:^Input_Binding($Control)) {r.controls_consume(&b.capture)}
