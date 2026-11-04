package box3d_authoring

import "core:encoding/base64"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import bd "godot:box3d/diagnostics"
import dd "godot:box3d/debugdraw"

Inspection_Counts :: struct {bodies,shapes,assets,resources,joints,characters:int}
Inspection_Id :: struct {stable_key,id_hex:string}
Inspection_Shape :: struct {stable_key,id_hex,body_id_hex,asset_id_hex:string}
Inspection_Resource :: struct {stable_key,id_hex,asset_id_hex:string}
Inspection_Joint :: struct {stable_key,id_hex,body_a_id_hex,body_b_id_hex:string}
Inspection_Character :: struct {stable_key,id_hex,exclude_body_id_hex:string}
Inspection_Metadata :: struct {
 artifact_version,import_version,schema_version:u32,
 namespace,scope,importer,source_uri,source_revision:string,
 source_revision_available:bool,source_definition_bytes:int,
 source_sha256,shared_bake_sha256,bake_sha256,artifact_sha256,content_id_hex:string,
 counts:Inspection_Counts,
 bodies:[]Inspection_Id,shapes:[]Inspection_Shape,assets:[]Inspection_Resource,resources:[]Inspection_Resource,
 joints:[]Inspection_Joint,characters:[]Inspection_Character,
}
Inspection_Preview :: struct {available:bool,scope,error:string,required:u32,lines:[]dd.Line}
Inspection_Diagnostic :: struct {error,field:string,definition_available:bool,definition:Diagnostic}
Inspection_Result :: struct {version:u32,ok:bool,diagnostic:Inspection_Diagnostic,metadata:Inspection_Metadata,artifact_base64:string,preview:Inspection_Preview}

@(private)
digest_text :: proc(digest:bd.Digest)->string{
 bytes:=make([]u8,64,context.temp_allocator);digits:="0123456789abcdef"
 for byte,i in digest{bytes[i*2]=digits[byte>>4];bytes[i*2+1]=digits[byte&15]};return string(bytes)
}
// Returned JSON is ONE owner; caller deletes it with allocator. Every durable
// u64 is an opaque exact16hex string, never a JSON numeric/Godot float.
artifact_inspect_json :: proc(artifact:^Owned_Artifact,diagnostic:Artifact_Diagnostic={},include_encoded:bool=false,include_preview:bool=false,allocator:=context.allocator)->([]u8,Artifact_Diagnostic){
 result:=Inspection_Result{version=1,ok=artifact!=nil&&diagnostic.error==.None,
  diagnostic={error=fmt.tprintf("%v",diagnostic.error),field=diagnostic.field,definition_available=diagnostic.error==.Definition,definition=diagnostic.definition},
  preview={scope="AUTHORED_SHAPES_ONLY_NO_FRAME_NO_STAMP",error="NotRequested"}}
 if !result.ok{bytes,error:=json.marshal(result,allocator=allocator);if error!=nil{return nil,artifact_problem(.Allocation,"inspection.json")};return bytes,{}}
 scene:=&artifact.scene;data:=&scene.data
 result.metadata={artifact_version=ARTIFACT_VERSION,import_version=IMPORT_VERSION,schema_version=data.schema_version,
  namespace=data.namespace,scope="DETACHED_DEFINITION_SHARED_BAKE_NO_NATIVE_WORLD",importer=artifact.metadata.importer,source_uri=artifact.metadata.source_uri,source_revision=artifact.metadata.source_revision,source_revision_available=len(artifact.metadata.source_revision)>0,
  source_definition_bytes=len(artifact.definition_json),source_sha256=digest_text(artifact.source_hash),shared_bake_sha256=digest_text(artifact.shared_bake_hash),bake_sha256=digest_text(scene.content_hash),artifact_sha256=digest_text(bd.hash_bytes(artifact.encoded)),content_id_hex=fmt.tprintf("%016x",content_id64(scene)),
  counts={len(data.bodies),len(data.shapes),len(data.assets),len(data.resources),len(data.joints),len(data.characters)}}
 m:=&result.metadata;ok:=false
 defer {delete(m.bodies,allocator);delete(m.shapes,allocator);delete(m.assets,allocator);delete(m.resources,allocator);delete(m.joints,allocator);delete(m.characters,allocator);delete(result.preview.lines,allocator);delete(result.artifact_base64,allocator)}
 m.bodies,ok=allocate(Inspection_Id,len(data.bodies),allocator);if !ok{return nil,artifact_problem(.Allocation,"inspection.bodies")}
 m.shapes,ok=allocate(Inspection_Shape,len(data.shapes),allocator);if !ok{return nil,artifact_problem(.Allocation,"inspection.shapes")}
 m.assets,ok=allocate(Inspection_Resource,len(data.assets),allocator);if !ok{return nil,artifact_problem(.Allocation,"inspection.assets")}
 m.resources,ok=allocate(Inspection_Resource,len(data.resources),allocator);if !ok{return nil,artifact_problem(.Allocation,"inspection.resources")}
 m.joints,ok=allocate(Inspection_Joint,len(data.joints),allocator);if !ok{return nil,artifact_problem(.Allocation,"inspection.joints")}
 m.characters,ok=allocate(Inspection_Character,len(data.characters),allocator);if !ok{return nil,artifact_problem(.Allocation,"inspection.characters")}
 for body,i in data.bodies{m.bodies[i]={body.stable_key,fmt.tprintf("%016x",body.logical_id)}}
 for shape,i in data.shapes{m.shapes[i]={shape.stable_key,fmt.tprintf("%016x",shape.logical_id),fmt.tprintf("%016x",shape.body_id),fmt.tprintf("%08x",shape.asset_id)}}
 for asset,i in data.assets{m.assets[i]={asset.stable_key,fmt.tprintf("%016x",asset.logical_id),fmt.tprintf("%08x",asset.catalog_id)}}
 for resource,i in data.resources{m.resources[i]={resource.stable_key,fmt.tprintf("%016x",resource.logical_id),fmt.tprintf("%08x",resource.catalog_id)}}
 for joint,i in data.joints{m.joints[i]={joint.stable_key,fmt.tprintf("%016x",joint.logical_id),fmt.tprintf("%016x",joint.body_a_id),fmt.tprintf("%016x",joint.body_b_id)}}
 for character,i in data.characters{m.characters[i]={character.stable_key,fmt.tprintf("%016x",character.logical_id),fmt.tprintf("%016x",character.exclude_body_id)}}
 if include_encoded{result.artifact_base64=base64.encode(artifact.encoded,allocator=allocator)}
 if include_preview{
  required,preview_error:=debug_preview(scene,16,nil);result.preview.required=required
  if (preview_error==.Capacity||preview_error==.None)&&required<=dd.MAX_LINES{
   result.preview.lines,ok=allocate(dd.Line,int(required),allocator);if !ok{return nil,artifact_problem(.Allocation,"inspection.preview")}
   result.preview.required,preview_error=debug_preview(scene,16,result.preview.lines)
   result.preview.available=preview_error==.None
  }
  result.preview.error=fmt.tprintf("%v",preview_error)
  if !result.preview.available{delete(result.preview.lines,allocator);result.preview.lines=nil}
 }
 bytes,error:=json.marshal(result,allocator=allocator);if error!=nil{return nil,artifact_problem(.Allocation,"inspection.json")};return bytes,{}
}
