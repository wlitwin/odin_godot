@tool
class_name Box3DEditorMeshBaker
extends RefCounted

const VERSION := 2
# Raw triangle data accepted before cleanup; welding and repair shrink it, and the
# cleaned mesh must still fit Box3D's vertex/index limits.
const MAX_RAW_INDICES := 4 * Box3DAuthoringData.MAX_INDICES

## Bakes `mesh`, transformed, into a Box3D mesh shape Resource. Triangles are
## converted from Godot's clockwise front faces to Box3D's counter-clockwise ones
## (Box3D mesh collision is one-sided), then welded and repaired by
## Box3DMeshCleanup so Box3D can smooth contacts across every shared edge.
static func bake_mesh(mesh: Mesh, stable_key: String, transform: Transform3D = Transform3D.IDENTITY, template: Box3DMeshShape3D = null, source_uri: String = "", source_revision: String = "", weld_distance: float = 0.001) -> Dictionary:
	var errors: Array = []
	var d := Box3DAuthoringData
	d.key(stable_key, "mesh.stable_key", errors)
	if mesh == null:
		d.issue(errors, "mesh", "Reference", "Source Mesh is missing.")
	if not transform.origin.is_finite() or not transform.basis.x.is_finite() or not transform.basis.y.is_finite() or not transform.basis.z.is_finite() or absf(transform.basis.determinant()) <= 0.0000001:
		d.issue(errors, "mesh.transform", "Pose", "Source transform must be finite and nonsingular; actual affine transform is baked into copied vertices.")
	if not (weld_distance > 0.0 and is_finite(weld_distance)):
		d.issue(errors, "mesh.weld_distance", "Geometry", "Weld distance must be a positive finite length.")
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	# Only ArrayMesh has blend shapes (primitive meshes such as BoxMesh have none).
	if mesh is ArrayMesh and (mesh as ArrayMesh).get_blend_shape_count() != 0:
		d.issue(errors, "mesh.blend_shapes", "Unsupported", "Blend shapes require an explicit static source; they are never silently omitted.")
	var mirrored: bool = transform.basis.determinant() < 0.0
	var triangles := PackedVector3Array()
	var surfaces: int = mesh.get_surface_count()
	if surfaces == 0 or surfaces > 35:
		d.issue(errors, "mesh.surfaces", "Capacity", "Source needs1..35 surfaces.")
	for surface in range(mini(surfaces, 35)):
		var path: String = "mesh.surfaces[%d]" % surface
		# Primitive meshes always produce triangles; only ArrayMesh reports its type.
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			d.issue(errors, path + ".primitive", "Unsupported", "Every source surface must contain triangles.")
			continue
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays.size() != Mesh.ARRAY_MAX or typeof(arrays[Mesh.ARRAY_VERTEX]) != TYPE_PACKED_VECTOR3_ARRAY:
			d.issue(errors, path + ".vertices", "Geometry", "Surface has no3D vertex array.")
			continue
		for slot in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
			var extra: Variant = arrays[slot]
			if extra != null and extra.size() != 0:
				d.issue(errors, path, "Unsupported", "Skinned source geometry cannot be baked as an undeformed static mesh.")
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			source_indices = arrays[Mesh.ARRAY_INDEX]
		if source_indices.is_empty():
			for i in range(source_vertices.size()):
				source_indices.append(i)
		if source_indices.size() % 3 != 0:
			d.issue(errors, path + ".indices", "Geometry", "Triangle index count must be divisible by3.")
		if triangles.size() + source_indices.size() > MAX_RAW_INDICES:
			d.issue(errors, path, "Capacity", "Combined source exceeds the raw triangle limit before cleanup.")
			break
		var placed := PackedVector3Array()
		for i in range(source_vertices.size()):
			var value: Vector3 = transform * source_vertices[i]
			if not source_vertices[i].is_finite() or not value.is_finite():
				d.issue(errors, path + ".vertices[%d]" % i, "Nonfinite", "Source/transformed vertex must be finite.")
			placed.append(value)
		for i in range(0, source_indices.size() - 2, 3):
			var a: int = source_indices[i]
			var b: int = source_indices[i + 1]
			var c: int = source_indices[i + 2]
			if mini(a, mini(b, c)) < 0 or maxi(a, maxi(b, c)) >= source_vertices.size():
				d.issue(errors, path + ".indices[%d]" % i, "Reference", "Source index is out of bounds.")
				continue
			# Godot's clockwise front face becomes Box3D's counter-clockwise one; a
			# mirroring transform already reversed it.
			triangles.append_array([placed[a], placed[b] if mirrored else placed[c], placed[c] if mirrored else placed[b]])
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var cleaned: Dictionary = Box3DMeshCleanup.build(triangles, weld_distance)
	var vertices: PackedVector3Array = cleaned.vertices
	var indices: PackedInt32Array = cleaned.indices
	if vertices.size() > d.MAX_VERTICES or indices.size() > d.MAX_INDICES:
		d.issue(errors, "mesh", "Capacity", "Cleaned mesh has %d vertices and %d indices; Box3D allows %d and %d." % [vertices.size(), indices.size(), d.MAX_VERTICES, d.MAX_INDICES])
		return {"ok": false, "errors": errors}
	var shape := Box3DMeshShape3D.new()
	shape.stable_key = stable_key
	if template != null:
		for field in ["density", "friction", "restitution", "category_bits", "mask_bits", "group_index", "is_sensor", "enable_sensor_events", "enable_contact_events"]:
			shape.set(field, template.get(field))
	shape.vertices = vertices
	shape.indices = indices
	shape.box3d_shape_definition("baked_shape", errors, "static", false)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	shape.authoring_metadata = {
		"import_version": VERSION,
		"source_uri": source_uri,
		"source_revision": source_revision,
		"surfaces": surfaces,
		"vertices": vertices.size(),
		"indices": indices.size(),
		"source_transform": {
			"origin": [transform.origin.x, transform.origin.y, transform.origin.z],
			"basis": [[transform.basis.x.x, transform.basis.x.y, transform.basis.x.z], [transform.basis.y.x, transform.basis.y.y, transform.basis.y.z], [transform.basis.z.x, transform.basis.z.y, transform.basis.z.z]],
		},
		"winding": "Godot clockwise front faces converted to Box3D counter-clockwise",
		"mirrored_source": mirrored,
		"cleanup": {
			"weld_distance": weld_distance,
			"zero_area_removed": cleaned.zero_area,
			"buried_removed": cleaned.buried,
			"t_junctions_split": cleaned.t_junctions,
			"crowded_edges": cleaned.crowded_edges,
		},
		"render_only_channels": "normals/UV/tangents/materials not collision identity; no skinned/blend source accepted",
		"identity": "shared Odin bake only; no frontend ID/hash algorithm",
	}
	return {"ok": true, "resource": shape, "errors": []}
