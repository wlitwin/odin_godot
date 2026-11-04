@tool
class_name Box3DEditorMeshBaker
extends RefCounted

const VERSION := 1
static func bake_mesh(mesh: Mesh,stable_key: String,transform: Transform3D=Transform3D.IDENTITY,template: Box3DMeshShape3D=null,source_uri: String="",source_revision: String="") -> Dictionary:
	var errors: Array=[];var d:=Box3DAuthoringData
	d.key(stable_key,"mesh.stable_key",errors)
	if mesh==null:d.issue(errors,"mesh","Reference","Source Mesh is missing.")
	if not transform.origin.is_finite() or not transform.basis.x.is_finite() or not transform.basis.y.is_finite() or not transform.basis.z.is_finite() or absf(transform.basis.determinant())<=0.0000001:d.issue(errors,"mesh.transform","Pose","Source transform must be finite and nonsingular; actual affine transform is baked into copied vertices.")
	if not errors.is_empty():return {"ok":false,"errors":errors}
	if mesh.get_blend_shape_count()!=0:d.issue(errors,"mesh.blend_shapes","Unsupported","Blend shapes require an explicit static source; they are never silently omitted.")
	var vertices:=PackedVector3Array();var indices:=PackedInt32Array();var mirrored: bool=transform.basis.determinant()<0.0
	var surfaces: int=mesh.get_surface_count()
	if surfaces==0 or surfaces>35:d.issue(errors,"mesh.surfaces","Capacity","Source needs1..35 surfaces.")
	for surface in range(mini(surfaces,35)):
		var path: String="mesh.surfaces[%d]"%surface
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:d.issue(errors,path+".primitive","Unsupported","Every source surface must contain triangles.");continue
		var arrays: Array=mesh.surface_get_arrays(surface)
		if arrays.size()!=Mesh.ARRAY_MAX or typeof(arrays[Mesh.ARRAY_VERTEX])!=TYPE_PACKED_VECTOR3_ARRAY:d.issue(errors,path+".vertices","Geometry","Surface has no3D vertex array.");continue
		for slot in [Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:
			var extra: Variant=arrays[slot]
			if extra!=null and extra.size()!=0:d.issue(errors,path,"Unsupported","Skinned source geometry cannot be baked as an undeformed static mesh.")
		var source_vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var source_indices:=PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX]!=null:source_indices=arrays[Mesh.ARRAY_INDEX]
		if source_indices.is_empty():
			for i in range(source_vertices.size()):source_indices.append(i)
		if source_indices.size()%3!=0:d.issue(errors,path+".indices","Geometry","Triangle index count must be divisible by3.")
		if vertices.size()+source_vertices.size()>d.MAX_VERTICES or indices.size()+source_indices.size()>d.MAX_INDICES:d.issue(errors,path,"Capacity","Combined source exceeds shared vertex/index limits.");break
		var offset: int=vertices.size()
		for i in range(source_vertices.size()):
			var value: Vector3=transform*source_vertices[i]
			if not source_vertices[i].is_finite() or not value.is_finite():d.issue(errors,path+".vertices[%d]"%i,"Nonfinite","Source/transformed vertex must be finite.")
			vertices.append(value)
		for i in range(0,source_indices.size()-2,3):
			var triangle: Array[int]=[source_indices[i],source_indices[i+1],source_indices[i+2]]
			for index in triangle:
				if index<0 or index>=source_vertices.size():d.issue(errors,path+".indices[%d]"%i,"Reference","Source index is out of bounds.")
			indices.append(offset+triangle[0]);indices.append(offset+triangle[2] if mirrored else offset+triangle[1]);indices.append(offset+triangle[1] if mirrored else offset+triangle[2])
	var shape:=Box3DMeshShape3D.new();shape.stable_key=stable_key
	if template!=null:
		for field in ["density","friction","restitution","category_bits","mask_bits","group_index","is_sensor","enable_sensor_events","enable_contact_events"]:shape.set(field,template.get(field))
	shape.vertices=vertices;shape.indices=indices
	shape.box3d_shape_definition("baked_shape",errors,"static",false)
	if not errors.is_empty():return {"ok":false,"errors":errors}
	shape.authoring_metadata={"import_version":VERSION,"source_uri":source_uri,"source_revision":source_revision,"surfaces":surfaces,"vertices":vertices.size(),"indices":indices.size(),"source_transform":{"origin":[transform.origin.x,transform.origin.y,transform.origin.z],"basis":[[transform.basis.x.x,transform.basis.x.y,transform.basis.x.z],[transform.basis.y.x,transform.basis.y.y,transform.basis.y.z],[transform.basis.z.x,transform.basis.z.y,transform.basis.z.z]]},"mirrored_winding_corrected":mirrored,"render_only_channels":"normals/UV/tangents/materials not collision identity; no skinned/blend source accepted","identity":"shared Odin bake only; no frontend ID/hash algorithm"}
	return {"ok":true,"resource":shape,"errors":[]}
