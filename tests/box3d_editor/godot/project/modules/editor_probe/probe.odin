//gd:extends Node
//gd:class EditorDrawProbe
package box3d_editor_probe
import "core:encoding/json"
import "core:encoding/base64"
import "core:mem"
import b "godot:box3d"
import a "godot:box3d/authoring"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import gd "godot:godot"
import "godot:gdext"
EditorDrawProbe :: struct {owner:gd.Node}
Stats :: struct {ok:bool,engine_live,wrapper_live,engine_calls,wrapper_calls,engine_total_bytes,wrapper_total_bytes:u64}
@(gd_method)
editor_draw_probe_stats :: proc(self:^EditorDrawProbe)->gd.String{
 e,es:=b.engine_allocation_stats();w,ws:=b.snapshot_allocation_stats()
 bytes,error:=json.marshal(Stats{es==.Ok&&ws==.Ok,e.live_bytes,w.live_bytes,e.total_calls,w.total_calls,e.total_bytes,w.total_bytes});if error!=nil{return gd.new_string_odin("{}")};defer delete(bytes);return gd.new_string_odin(string(bytes))
}
@(gd_method)
editor_draw_probe_native_images :: proc(self:^EditorDrawProbe)->gd.Int{return gd.Int(native_image_count())}

Native_Artifact_Report :: struct {
 ok,cleanup:bool,
 phase:string,
 artifact_error:a.Artifact_Error,build_error:a.Error,native_status:b.Status,
 body_count,shape_count:u32,
}
@(gd_method)
editor_draw_probe_build_artifact :: proc(self:^EditorDrawProbe,encoded:gd.String)->gd.String{
 report:=Native_Artifact_Report{phase="base64.bytes"}
 value:=encoded
 count:=gdext.string_to_utf8_chars(cast(gdext.StringPtr)&value,nil,0)
 if count<0||count>((a.MAX_ARTIFACT_BYTES+2)/3)*4{return artifact_report_string(report)}
 text,error:=mem.alloc_bytes(int(count));if error!=.None{return artifact_report_string(report)};defer delete(text)
 if count>0&&gdext.string_to_utf8_chars(cast(gdext.StringPtr)&value,cast(cstring)raw_data(text),count)!=count{return artifact_report_string(report)}
 decoded,de:=base64.decode(string(text));if de!=nil{return artifact_report_string(report)};defer delete(decoded)
 scope,status:=meter.create(bg.service_get(),bg.CATEGORY_REPLAY_PROVIDER)
 report.phase="scope";if status!=bg.OK{return artifact_report_string(report)}
 artifact,problem:=a.artifact_load(decoded,meter.allocator(scope));report.artifact_error=problem.error;report.phase="artifact.load"
 built:a.Built_Scene
 if problem.error==.None{
  candidate,build_problem:=a.build(&artifact.scene,0x454449544f525344)
  built=candidate;report.build_error=build_problem.error;report.native_status=build_problem.native_status;report.phase="native.build"
  if build_problem.error==.None{
   counts,cs:=b.world_counters(built.world);report.native_status=cs
   if cs==.Ok{
    report.body_count=counts.body_count;report.shape_count=counts.shape_count
    report.native_status=b.world_step_fixed(built.world);report.phase="native.step"
    report.ok=report.native_status==.Ok&&counts.body_count==1&&counts.shape_count==1&&counts.joint_count==0
   }
  }
 }
 drop:=a.built_destroy(&built);a.artifact_destroy(&artifact)
 scope_drop:=meter.destroy(&scope)
 engine,es:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats()
 report.cleanup=drop==.Ok&&scope_drop==bg.OK&&es==.Ok&&ws==.Ok&&engine.live_bytes==0&&wrapper.live_bytes==0
 report.ok=report.ok&&report.cleanup
 return artifact_report_string(report)
}
@(private)
artifact_report_string :: proc(report:Native_Artifact_Report)->gd.String{
 bytes,error:=json.marshal(report);if error!=nil{return gd.new_string_odin("{\"ok\":false}")};defer delete(bytes)
 return gd.new_string_odin(string(bytes))
}
