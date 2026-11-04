// Three small editor methods; no retained Node, Resource, Native World or cache.
package box3d_godot_authoring

import "core:encoding/base64"
import "core:mem"
import a "godot:box3d/authoring"
import gd "godot:godot"
import "godot:gdext"

@(private)
editor_copy :: proc(value:gd.String,maximum:int)->([]u8,bool){
 borrowed:=value
 count:=gdext.string_to_utf8_chars(cast(gdext.StringPtr)&borrowed,nil,0)
 if count<0||int(count)>maximum{return nil,false}
 bytes,error:=mem.alloc_bytes(int(count));if error!=.None{return nil,false}
 if count>0&&gdext.string_to_utf8_chars(cast(gdext.StringPtr)&borrowed,cast(cstring)raw_data(bytes),count)!=count{delete(bytes);return nil,false}
 return bytes,true
}
@(private)
editor_result :: proc(artifact:^a.Owned_Artifact,diagnostic:a.Artifact_Diagnostic,encoded,preview:bool)->gd.String{
 bytes,problem:=a.artifact_inspect_json(artifact,diagnostic,encoded,preview)
 if problem.error!=.None{return gd.new_string_odin("{\"version\":1,\"ok\":false,\"diagnostic\":{\"error\":\"Allocation\",\"field\":\"inspection.json\"}}")}
 defer delete(bytes);return gd.new_string_odin(string(bytes))
}
editor_inspect_definition :: proc(definition_json:gd.String)->gd.String{
 bytes,ok:=editor_copy(definition_json,a.MAX_DEFINITION_BYTES);if !ok{return editor_result(nil,{error=.Capacity,field="source.bytes"},false,false)};defer delete(bytes)
 artifact,problem:=a.artifact_create(bytes,a.import_metadata("memory://inspect"));defer a.artifact_destroy(&artifact)
 if problem.error!=.None{return editor_result(nil,problem,false,false)}
 return editor_result(&artifact,{},false,true)
}
editor_bake_definition :: proc(definition_json,source_uri,source_revision:gd.String)->gd.String{
 bytes,ok:=editor_copy(definition_json,a.MAX_DEFINITION_BYTES);if !ok{return editor_result(nil,{error=.Capacity,field="source.bytes"},false,false)};defer delete(bytes)
 uri,uok:=editor_copy(source_uri,2048);if !uok{return editor_result(nil,{error=.Capacity,field="source.uri"},false,false)};defer delete(uri)
 revision,rok:=editor_copy(source_revision,128);if !rok{return editor_result(nil,{error=.Capacity,field="source.revision"},false,false)};defer delete(revision)
 artifact,problem:=a.artifact_create(bytes,a.import_metadata(string(uri),string(revision)));defer a.artifact_destroy(&artifact)
 if problem.error!=.None{return editor_result(nil,problem,false,false)}
 return editor_result(&artifact,{},true,false)
}
editor_inspect_artifact :: proc(artifact_base64:gd.String)->gd.String{
 encoded,ok:=editor_copy(artifact_base64,((a.MAX_ARTIFACT_BYTES+2)/3)*4);if !ok{return editor_result(nil,{error=.Capacity,field="artifact.base64"},false,false)};defer delete(encoded)
 bytes,error:=base64.decode(string(encoded));if error!=nil{return editor_result(nil,{error=.Corrupt,field="artifact.base64"},false,false)};defer delete(bytes)
 canonical:=base64.encode(bytes);defer delete(canonical)
 if canonical!=string(encoded){return editor_result(nil,{error=.Corrupt,field="artifact.base64_canonical"},false,false)}
 artifact,problem:=a.artifact_load(bytes);defer a.artifact_destroy(&artifact)
 if problem.error!=.None{return editor_result(nil,problem,false,false)}
 return editor_result(&artifact,{},false,false)
}
