package box3d_editor_pure_test

import "core:encoding/json"
import "core:mem"
import "core:strings"
import "core:testing"
import a "godot:box3d/authoring"
import bd "godot:box3d/diagnostics"
import f "godot:tests/box3d_motion/pure"
import shapes "godot:tests/box3d_authoring/pure"

definition :: proc(t:^testing.T,input:a.Scene_Input)->[]u8{bytes,error:=json.marshal(input);testing.expect(t,error==nil);return bytes}
valid :: proc(t:^testing.T,problem:a.Artifact_Diagnostic)->bool{testing.expect_value(t,problem.error,a.Artifact_Error.None);return problem.error==.None}
put32 :: proc(bytes:[]u8,at:int,value:u32){for i in 0..<4{bytes[at+i]=u8(value>>uint(i*8))}}
get32 :: proc(bytes:[]u8,at:int)->u32{value:u32;for i in 0..<4{value|=u32(bytes[at+i])<<uint(i*8)};return value}
reject :: proc(t:^testing.T,encoded:[]u8,error:a.Artifact_Error){artifact,problem:=a.artifact_load(encoded);defer a.artifact_destroy(&artifact);testing.expect_value(t,problem.error,error);testing.expect(t,len(problem.field)>0&&len(artifact.encoded)==0&&len(artifact.scene.data.bodies)==0)}

@(test)
artifact_detaches_exact_source_metadata_and_shared_bake :: proc(t:^testing.T){
 input:f.Fixture;f.fixture_init(&input,"hinge");bytes:=definition(t,input.scene)
 artifact,p:=a.artifact_create(bytes,a.import_metadata("res://world.tscn","saved-revision-1"));if !valid(t,p){delete(bytes);return}
 source_hash:=bd.hash_bytes(bytes);testing.expect(t,mem.compare(bytes,artifact.definition_json)==0&&artifact.source_hash==source_hash&&artifact.shared_bake_hash==a.shared_bake_identity())
 delete(bytes);input.bodies={};input.shapes={};input.joints={};input.characters={}
 loaded,lp:=a.artifact_load(artifact.encoded);if !valid(t,lp){a.artifact_destroy(&artifact);return}
 testing.expect(t,mem.compare(loaded.encoded,artifact.encoded)==0&&loaded.scene.content_hash==artifact.scene.content_hash&&loaded.metadata.source_uri=="res://world.tscn"&&loaded.metadata.source_revision=="saved-revision-1")
 a.artifact_destroy(&artifact)
 testing.expect(t,len(loaded.scene.data.bodies)==3&&len(loaded.scene.data.joints)==1&&len(loaded.scene.data.characters)==1&&loaded.source_hash==source_hash)
 a.artifact_destroy(&loaded);a.artifact_destroy(&loaded)
}

@(test)
semantic_identity_survives_order_with_distinct_exact_source_identity :: proc(t:^testing.T){
 input:f.Fixture;f.fixture_init(&input)
 first_bytes:=definition(t,input.scene);defer delete(first_bytes)
 first,p:=a.artifact_create(first_bytes,a.import_metadata());defer a.artifact_destroy(&first);if !valid(t,p){return}
 input.bodies[0],input.bodies[2]=input.bodies[2],input.bodies[0]
 next_bytes:=definition(t,input.scene);defer delete(next_bytes)
 next,np:=a.artifact_create(next_bytes,a.import_metadata());defer a.artifact_destroy(&next);if !valid(t,np){return}
 testing.expect(t,first.scene.content_hash==next.scene.content_hash&&first.source_hash!=next.source_hash&&mem.compare(first.encoded,next.encoded)!=0)
 testing.expect_value(t,first.scene.data.bodies[0].logical_id,next.scene.data.bodies[0].logical_id)
}

@(test)
strict_versions_hashes_lengths_truncation_and_failure_atomicity :: proc(t:^testing.T){
 input:f.Fixture;f.fixture_init(&input,"hinge");bytes:=definition(t,input.scene);defer delete(bytes)
 artifact,p:=a.artifact_create(bytes,a.import_metadata());defer a.artifact_destroy(&artifact);if !valid(t,p){return}
 changed:=make([]u8,len(artifact.encoded));defer delete(changed)
 for i in 0..<a.ARTIFACT_HEADER_BYTES{reject(t,artifact.encoded[:i],.Truncated)}
 reject(t,artifact.encoded[:len(artifact.encoded)-1],.Truncated)
 copy(changed,artifact.encoded);put32(changed,8,99);reject(t,changed,.Version)
 copy(changed,artifact.encoded);put32(changed,16,99);reject(t,changed,.Version)
 copy(changed,artifact.encoded);put32(changed,20,99);reject(t,changed,.Version)
 copy(changed,artifact.encoded);changed[0]~=1;reject(t,changed,.Corrupt)
 copy(changed,artifact.encoded);changed[40]~=1;reject(t,changed,.Corrupt)
 copy(changed,artifact.encoded);changed[72]~=1;reject(t,changed,.Corrupt)
 copy(changed,artifact.encoded);changed[104]~=1;reject(t,changed,.Corrupt)
 copy(changed,artifact.encoded);changed[136]~=1;reject(t,changed,.Corrupt)
 copy(changed,artifact.encoded);changed[168]~=1;reject(t,changed,.Shared_Bake)
 copy(changed,artifact.encoded);put32(changed,24,a.MAX_DEFINITION_BYTES+1);reject(t,changed,.Capacity)
 trailing:=make([]u8,len(changed)+1);defer delete(trailing);copy(trailing,artifact.encoded);reject(t,trailing,.Truncated)
 // Even self-consistent hashes cannot turn an invalid authored reference into
 // a usable artifact. This forges OUR envelope, never a Native/wire packet.
 copy(changed,artifact.encoded);source_at:=a.ARTIFACT_HEADER_BYTES+int(get32(changed,28));source:=changed[source_at:]
 needle:="\"body_b\":\"mover\"";at:=strings.index(string(source),needle);testing.expect(t,at>=0);if at<0{return}
 key_at:=at+len("\"body_b\":\"");copy(source[key_at:key_at+5],transmute([]u8)string("xxxxx"))
 hash:=bd.hash_bytes(source);copy(changed[40:72],hash[:]);hash=bd.hash_bytes(changed[a.ARTIFACT_HEADER_BYTES:]);copy(changed[136:168],hash[:]);reject(t,changed,.Definition)
}

@(test)
owned_inspection_json_exact_hex_ids_and_authored_preview_only :: proc(t:^testing.T){
 input:shapes.Fixture;shapes.fixture_init(&input)
 bytes:=definition(t,input.scene);defer delete(bytes)
 artifact,p:=a.artifact_create(bytes,a.import_metadata());defer a.artifact_destroy(&artifact);if !valid(t,p){return}
 result,rp:=a.artifact_inspect_json(&artifact,include_preview=true);defer delete(result);if !valid(t,rp){return}
 scratch:=make([]u8,2*1024*1024);defer delete(scratch);arena:mem.Arena;mem.arena_init(&arena,scratch)
 report:a.Inspection_Result;error:=json.unmarshal(result,&report,allocator=mem.arena_allocator(&arena));testing.expect(t,error==nil);if error!=nil{return}
 testing.expect(t,report.ok&&report.metadata.counts.bodies==8&&report.metadata.counts.shapes==8&&len(report.metadata.content_id_hex)==16&&len(report.metadata.bake_sha256)==64&&report.metadata.source_revision_available==false)
 for body in report.metadata.bodies{testing.expect(t,len(body.id_hex)==16);for c in body.id_hex{testing.expect(t,(c>='0'&&c<='9')||(c>='a'&&c<='f'))}}
 testing.expect(t,report.preview.available&&report.preview.error=="None"&&report.preview.scope=="AUTHORED_SHAPES_ONLY_NO_FRAME_NO_STAMP"&&len(report.preview.lines)>0&&len(report.preview.lines)==int(report.preview.required))
 testing.expect(t,!strings.contains(string(result),"ground_shape")&&!strings.contains(string(result),"native_handle"))
}

@(test)
invalid_definition_metadata_and_input_bounds_publish_no_owner :: proc(t:^testing.T){
 input:f.Fixture;f.fixture_init(&input,"hinge");input.joints[0].body_b="missing";bytes:=definition(t,input.scene);defer delete(bytes)
 invalid,p:=a.artifact_create(bytes,a.import_metadata());defer a.artifact_destroy(&invalid);testing.expect(t,p.error==.Definition&&p.definition.error==.Reference&&len(invalid.encoded)==0&&len(invalid.scene.data.bodies)==0)
 invalid,p=a.artifact_create(nil,a.import_metadata());testing.expect(t,p.error==.Capacity&&len(invalid.encoded)==0)
 metadata:=a.import_metadata();metadata.importer_version=99;invalid,p=a.artifact_create(bytes,metadata);testing.expect(t,p.error==.Metadata&&len(invalid.encoded)==0)
 metadata=a.import_metadata("");invalid,p=a.artifact_create(bytes,metadata);testing.expect(t,p.error==.Metadata&&len(invalid.encoded)==0)
 too_large:=make([]u8,a.MAX_ARTIFACT_BYTES+1);defer delete(too_large);reject(t,too_large,.Capacity)
}
