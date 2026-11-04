//gd:extends Node
//gd:class MotionProbe
package box3d_motion_probe

import "core:encoding/json"
import "core:fmt"
import b "godot:box3d"
import ba "godot:box3d/authoring"
import ga "godot:box3d/godot/authoring"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import gd "godot:godot"

MotionProbe :: struct {owner:gd.Node,scope:^meter.Context,baked:ba.Baked_Scene,built:ba.Built_Scene}
Extract_Report :: struct {
 ok:bool,
 bodies,shapes,assets,baked_sensor_shapes,joints,characters:int,
}
Build_Error_Report :: struct {
 ok:bool,
 error,field:string,
 native_status:i32,
}
World_Counts_Report :: struct {
 ok:bool,
 body_count,shape_count,joint_count:u32,
}
json_string :: proc(value:$T)->gd.String{bytes,error:=json.marshal(value);if error!=nil{return gd.new_string_odin("{}")};defer delete(bytes);return gd.new_string_odin(string(bytes))}
probe_close :: proc(self:^MotionProbe)->bool{
 if self.built.world!=0{if ba.built_destroy(&self.built)!=.Ok{return false}}
 ba.destroy(&self.baked)
 if self.scope!=nil{if meter.destroy(&self.scope)!=bg.OK{return false}}
 return true
}
@(gd_method)
motion_probe_extract :: proc(self:^MotionProbe,world:gd.Object)->gd.String{
 if !probe_close(self){return gd.new_string_odin("{\"ok\":false,\"error\":\"prior_close\"}")}
 status:bg.Status;self.scope,status=meter.create(bg.service_get(),bg.CATEGORY_REPLAY_PROVIDER)
 if status!=bg.OK{return json_string(struct{ok:bool,status:i32}{false,i32(status)})}
 result,error:=ga.extract(world,meter.allocator(self.scope));defer ga.diagnostic_destroy(&error)
 if error.error!=.None{return json_string(struct{ok:bool,error,field,details:string}{false,fmt.tprintf("%v",error.error),error.bake_diagnostic.field,string(error.authoring_errors_json)})}
 self.baked=result
 sensor_shapes:=0;for shape in self.baked.data.shapes{if shape.definition.is_sensor!=0{sensor_shapes+=1}}
 return json_string(Extract_Report{true,len(self.baked.data.bodies),len(self.baked.data.shapes),len(self.baked.data.assets),sensor_shapes,len(self.baked.data.joints),len(self.baked.data.characters)})
}
@(gd_method)
motion_probe_hash :: proc(self:^MotionProbe)->gd.String{
 bytes:[64]u8;digits:="0123456789abcdef"
 for byte,i in self.baked.content_hash{bytes[i*2]=digits[byte>>4];bytes[i*2+1]=digits[byte&15]}
 return gd.new_string_odin(string(bytes[:]))
}
@(gd_method)
motion_probe_logical_ids :: proc(self:^MotionProbe)->gd.String{
 ids:=make([dynamic]string);defer {for id in ids{delete(id)};delete(ids)}
 for body in self.baked.data.bodies{append(&ids,fmt.aprintf("body:%s:%016x",body.stable_key,body.logical_id))}
 for shape in self.baked.data.shapes{append(&ids,fmt.aprintf("shape:%s:%016x",shape.stable_key,shape.logical_id))}
 for joint in self.baked.data.joints{append(&ids,fmt.aprintf("joint:%s:%016x",joint.stable_key,joint.logical_id))}
 for character in self.baked.data.characters{append(&ids,fmt.aprintf("character:%s:%016x",character.stable_key,character.logical_id))}
 return json_string(ids[:])
}
@(gd_method)
motion_probe_build :: proc(self:^MotionProbe)->gd.String{
 if self.built.world!=0{return gd.new_string_odin("{\"ok\":false}")}
 built,error:=ba.build(&self.baked,0x4d4f54494f4e3032)
 if error.error!=.None{return json_string(Build_Error_Report{false,fmt.tprintf("%v",error.error),error.field,i32(error.native_status)})}
 self.built=built;counts,status:=b.world_counters(self.built.world)
 return json_string(World_Counts_Report{status==.Ok,counts.body_count,counts.shape_count,counts.joint_count})
}
@(gd_method)
motion_probe_close :: proc(self:^MotionProbe)->bool{return probe_close(self)}
@(gd_method)
motion_probe_clean :: proc(self:^MotionProbe)->bool{
 engine,es:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats();category,cs:=meter.category_stats(bg.CATEGORY_REPLAY_PROVIDER)
 return self.scope==nil && self.built.world==0 && es==.Ok && ws==.Ok && cs==bg.OK && engine.live_bytes==0 && wrapper.live_bytes==0 && category.live_bytes==0 && category.contexts==0
}
@(gd_method)
motion_probe_native_images :: proc(self:^MotionProbe)->gd.Int{return gd.Int(native_image_count())}
motion_probe_exit_tree :: proc(self:^MotionProbe){if !probe_close(self){gd.print_str("BOX3D_MOTION_PROBE_CLEANUP_FAIL")}}

Character_Report :: struct {
 ok:bool,
 max_slides:u32,
 radius,floor_cosine:f32,
 position,velocity:[3]f32,
 initial_grounding_zero,exclude_resolved:bool,
}
Character_Step_Report :: struct {ok:bool,displacement:[3]f32,iterations,plane_count:u32}
@(gd_method)
motion_probe_character :: proc(self:^MotionProbe)->gd.String{
 if len(self.built.characters)!=1{return gd.new_string_odin("{\"ok\":false}")}
 c:=self.built.characters[0];p,v:=c.initial.position,c.initial.velocity
 return json_string(Character_Report{true,c.config.max_slides,c.config.capsule.radius,c.config.floor_cosine,{p.x,p.y,p.z},{v.x,v.y,v.z},c.initial.grounded==0&&c.initial.ground_shape==0,c.config.filter.exclude_body!=0})
}
@(gd_method)
motion_probe_character_step :: proc(self:^MotionProbe)->gd.String{
 if len(self.built.characters)!=1{return gd.new_string_odin("{\"ok\":false}")}
 c:=self.built.characters[0]
 result,status:=b.character_step(self.built.world,c.config,c.initial,b.FIXED_SECONDS)
 return json_string(Character_Step_Report{status==.Ok,{result.displacement.x,result.displacement.y,result.displacement.z},result.iterations,result.plane_count})
}
