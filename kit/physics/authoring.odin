package kit_physics

import ba "godot:box3d/authoring"
import b "godot:box3d"
import sim "godot:kit/sim"

// Attaches a shared authored native candidate through the existing Kit provider.
// Only world ownership transfers on success. The caller still owns the copied
// logical maps/catalog in built and destroys them with ba.built_destroy.
// Bind network mode with that catalog through the existing network_configure.
authoring_attach :: proc(a:^Instance($Side),lane:^sim.Lane,built:^ba.Built_Scene,
                         initial:Side,fields:[]sim.World_Field_Type,cfg:Config,
                         settle:sim.Step_Proc=nil)->sim.World_Error {
 if built==nil || built.world==0{return .Invalid}
 identity,status:=b.recovery_catalog_identity(&built.catalog)
 if status!=.Ok || identity.profile==0{return .Incompatible}
 asset_id:=authoring_content_id(built.content_hash)
 if asset_id==0{return .Invalid}
 effective:=cfg
 if effective.asset_id!=0 && effective.asset_id!=asset_id{return .Incompatible}
 effective.asset_id=asset_id
 return attach(a,lane,&built.world,initial,fields,effective,settle)
}

@(private)
authoring_content_id :: proc(hash:[32]u8)->u64 {
 value:u64
 for i in 0..<8{value|=u64(hash[i])<<uint(8*i)}
 return value
}
