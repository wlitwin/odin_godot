// Engine boundary only. Call once while the source is live, before runtime.
// Returned bake data owns copied bytes; no Node/Resource/Variant is retained.
package box3d_godot_authoring

import "core:mem"
import ba "godot:box3d/authoring"
import gd "godot:godot"
import "godot:gdext"

Error :: enum {None,Nil_Object,Missing_Method,Invalid_Return,Invalid_Authoring,Capacity,Allocation,Definition}
Diagnostic :: struct {error:Error,bake_diagnostic:ba.Diagnostic,authoring_errors_json:[]u8,allocator:mem.Allocator}

diagnostic_destroy :: proc(d:^Diagnostic){
 if d==nil{return}
 if len(d.authoring_errors_json)>0{delete(d.authoring_errors_json,d.allocator)}
 d^={}
}

@(private)
string_call :: proc(world:gd.Object,method:cstring,allocator:mem.Allocator)->([]u8,Error){
 if world==nil{return nil,.Nil_Object}
 if !gd.object_has_method(world,gd.sname(method)){return nil,.Missing_Method}
 value:=gd.vcall(world,method);defer gd.variant_destroy(&value)
 if value.type!=.String{return nil,.Invalid_Return}
 text:=gd.variant_to_string(&value);defer gd.free_string(text)
 count:=gdext.string_to_utf8_chars(cast(gdext.StringPtr)&text,nil,0)
 if count<0 || count>ba.MAX_DEFINITION_BYTES{return nil,.Capacity}
 if count==0{return nil,.None}
 bytes,error:=mem.alloc_bytes(int(count),allocator=allocator)
 if error!=.None{return nil,.Allocation}
 copied:=gdext.string_to_utf8_chars(cast(gdext.StringPtr)&text,cast(cstring)raw_data(bytes),count)
 if copied!=count{delete(bytes,allocator);return nil,.Invalid_Return}
 return bytes,.None
}

// Caller owns returned JSON and frees it with the supplied allocator.
extract_json :: proc(world:gd.Object,allocator:=context.allocator)->([]u8,Diagnostic){
 bytes,error:=string_call(world,"box3d_definition_json",allocator)
 if error!=.None{return nil,{error=error}}
 if len(bytes)==0{
  details,_:=string_call(world,"box3d_diagnostics_json",allocator)
  return nil,{error=.Invalid_Authoring,authoring_errors_json=details,allocator=allocator}
 }
 return bytes,{}
}

// Uses the one shared definition parser/baker; no independent geometry rules,
// ID allocation, native construction or replay implementation live here.
extract :: proc(world:gd.Object,allocator:=context.allocator)->(ba.Baked_Scene,Diagnostic){
 bytes,error:=extract_json(world,allocator)
 if error.error!=.None{return {},error}
 defer delete(bytes,allocator)
 scene,report:=ba.parse_and_bake(bytes,allocator)
 if report.error!=.None{return {},{error=.Definition,bake_diagnostic=report}}
 return scene,{}
}
