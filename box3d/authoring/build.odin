package box3d_authoring

import b "godot:box3d"

owned_bytes :: proc(scene:^Baked_Scene)->u64{
 if scene==nil{return 0}
 n:=len(scene.data.namespace)+len(scene.data.bodies)*size_of(Baked_Body)+len(scene.data.shapes)*size_of(Baked_Shape)+len(scene._asset_storage)*size_of(Baked_Asset)+len(scene._resource_storage)*size_of(Baked_Resource)
 for body in scene.data.bodies{n+=len(body.stable_key)}
 for shape in scene.data.shapes{n+=len(shape.stable_key)}
 for resource in scene.data.resources{n+=len(resource.stable_key)}
 n+=len(scene.data.joints)*size_of(Baked_Joint)+len(scene.data.characters)*size_of(Baked_Character)
 for joint in scene.data.joints{n+=len(joint.stable_key)}
 for character in scene.data.characters{n+=len(character.stable_key)}
 for asset in scene.data.assets{n+=len(asset.stable_key)+len(asset.vertices)*size_of(b.Vec3)+len(asset.indices)*size_of(u32)}
 return u64(n)
}
// No simulation step here: Kit/Replay retain exclusive tick ownership.
build :: proc(scene:^Baked_Scene,profile:u64)->(Built_Scene,Diagnostic){
 candidate:Built_Scene
 problem:=build_candidate(scene,profile,&candidate)
 if problem.error==.None{return candidate,{}}
 // Finish rollback BEFORE copying any output. Only an actual declined drop
 // returns a surviving owner, explicitly qualified as failed/retained.
 if status:=built_destroy(&candidate);status!=.Ok{
  problem.error=.Native;problem.field="build.rollback_retained_owner";problem.native_status=status
  return candidate,problem
 }
 return {},problem
}
@(private)
build_candidate :: proc(scene:^Baked_Scene,profile:u64,built:^Built_Scene)->(problem:Diagnostic){
 if scene==nil||!schema_supported(scene.data.schema_version)||profile==0{return fail(.Schema,"build.scene_profile")}
 problem=validate_ids(scene.data);if problem.error!=.None{return}
 hash,hashed:=scene_hash(scene.data);if !hashed{return fail(.Allocation,"build.identity")}
 if hash!=scene.content_hash||content_id64(scene)==0{return fail(.Corrupt,"build.content_hash")}
 if status:=b.authoring_asset_abi_check();status!=.Ok{return {error=.Native,field="asset.layout",native_status=status}}
 built.allocator=scene.allocator;built.content_hash=scene.content_hash
 ok:=false;built.bodies,ok=allocate(Body_Map,len(scene.data.bodies),built.allocator);if !ok{return fail(.Allocation,"build.bodies")}
 built.shapes,ok=allocate(Shape_Map,len(scene.data.shapes),built.allocator);if !ok{return fail(.Allocation,"build.shapes")}
 built.joints,ok=allocate(Joint_Map,len(scene.data.joints),built.allocator);if !ok{return fail(.Allocation,"build.joints")}
 built.characters,ok=allocate(Character_Map,len(scene.data.characters),built.allocator);if !ok{return fail(.Allocation,"build.characters")}
 charge:=owned_bytes(scene)+u64(len(built.bodies)*size_of(Body_Map)+len(built.shapes)*size_of(Shape_Map)+len(built.joints)*size_of(Joint_Map)+len(built.characters)*size_of(Character_Map))
 if _,status:=b.alpha_memory_check(charge);status!=.Ok{return {error=.Native,field="build.memory_preflight",native_status=status}}
 descriptors:[MAX_ASSETS]b.Recovery_Asset_V2
 for asset,i in scene.data.assets{
  descriptors[i]={version=b.AUTHORING_ASSET_VERSION,struct_bytes=u32(size_of(b.Recovery_Asset_V2)),
   base={id=asset.catalog_id,kind=b.Recovery_Asset_Kind(asset.native_kind),a=asset.a,b=asset.b,radius=asset.radius},
   vertices=raw_data(asset.vertices),indices=raw_data(asset.indices),vertex_count=u32(len(asset.vertices)),triangle_count=u32(len(asset.indices)/3)}
 }
 config:=b.recovery_config_default();config.profile=profile
 status:b.Status
 if scene.data.schema_version==LEGACY_SCHEMA_VERSION{built.catalog,status=b.recovery_catalog_create_v2(config,descriptors[:len(scene.data.assets)])}else{built.catalog,status=b.recovery_catalog_create_v3(config,descriptors[:len(scene.data.assets)])}
 if status!=.Ok{return {error=.Native,field="build.catalog",native_status=status}}
 built.world,status=b.world_create(scene.data.world);if status!=.Ok{return {error=.Native,field="build.world",native_status=status}}
 for body,i in scene.data.bodies{
  handle,s:=b.body_create(built.world,body.definition);if s!=.Ok{return {error=.Native,body=i,field="build.body",native_status=s}}
  key,ks:=b.body_key(handle);if ks!=.Ok{return {error=.Native,body=i,field="build.body_key",native_status=ks}}
  built.bodies[i]={body.logical_id,handle,key}
 }
 for shape,i in scene.data.shapes{
  body:b.Body;for mapping in built.bodies{if mapping.logical_id==shape.body_id{body=mapping.handle;break}}
  if body==0{return fail(.Reference,"build.shape_body",shape=i)}
  handle,s:=b.recovery_catalog_shape(&built.catalog,shape.asset_id,body,shape.definition)
  if s!=.Ok{return {error=.Native,shape=i,field="build.shape",native_status=s}}
  key,ks:=b.shape_key(handle);if ks!=.Ok{return {error=.Native,shape=i,field="build.shape_key",native_status=ks}}
  built.shapes[i]={shape.logical_id,shape.body_id,shape.asset_id,handle,key}
 }
 for joint,i in scene.data.joints{
  definition:=joint.definition
  for body in built.bodies{if body.logical_id==joint.body_a_id{definition.body_a=body.key};if body.logical_id==joint.body_b_id{definition.body_b=body.key}}
  key,js:=b.motion_joint_create(built.world,definition);if js!=.Ok{return {error=.Native,element=i,field="build.joint",native_status=js}}
  built.joints[i]={joint.logical_id,joint.body_a_id,joint.body_b_id,key}
 }
 for character,i in scene.data.characters{
  config:=character.config
  if character.exclude_body_id!=0{for body in built.bodies{if body.logical_id==character.exclude_body_id{config.filter.exclude_body=body.key;break}};if config.filter.exclude_body==0{return fail(.Reference,"build.character.exclude_body",element=i)}}
  built.characters[i]={character.logical_id,config,character.initial}
 }
 if _,status:=b.alpha_memory_check(charge);status!=.Ok{return {error=.Native,field="build.memory_final",native_status=status}}
 return {}
}
// Checked, ordered and idempotent. A failed drop preserves its surviving owner.
built_destroy :: proc(built:^Built_Scene)->b.Status{
 if built==nil{return .Invalid_Argument}
 if built.world!=0{if status:=b.world_destroy(&built.world);status!=.Ok{return status}}
 if built.catalog._handle!=nil{if status:=b.recovery_catalog_destroy(&built.catalog);status!=.Ok{return status}}
 delete(built.bodies,built.allocator);delete(built.shapes,built.allocator);delete(built.joints,built.allocator);delete(built.characters,built.allocator);built^={};return .Ok
}
