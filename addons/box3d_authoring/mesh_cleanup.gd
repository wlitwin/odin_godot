@tool
class_name Box3DMeshCleanup
extends RefCounted
## Turns triangles from Godot meshes into one clean Box3D mesh.
##
## Box3D smooths contacts across a triangle edge, so a fast body does not pop where
## pieces meet, only when exactly two triangles share that edge's two vertices.
## Meshes assembled from separate pieces (tiles, kit parts) break that rule, and
## `build` repairs each way it breaks:
##
## - Duplicate vertices where pieces meet: vertices within `weld_distance` become one.
## - Zero-area triangles: dropped; Box3D's baker rejects them.
## - Buried faces: closed pieces that touch leave faces inside the mesh, such as
##   back-to-back end caps or a bump's base under the bump. They can never be
##   touched but put extra triangles on the edges around them, so they are removed.
## - T-junctions: a vertex lying inside another triangle's edge means the two sides
##   share no edge; that triangle is split at the vertex. Every edge is checked, not
##   just open ones: where pieces of different widths meet (a lane's floor against a
##   corner's), a buried face can make the edge look shared while the two floors
##   still meet in a T. Once split, the buried face crowds the edge and is removed.
##
## Triangles must already be in Box3D order; `append_triangles` converts a Mesh.

## Appends `mesh`'s triangles, transformed, in Box3D order. Godot's front faces are
## clockwise and Box3D's counter-clockwise, and Box3D mesh collision is one-sided,
## so each triangle is reversed unless `transform` mirrors, which reverses it already.
static func append_triangles(out: PackedVector3Array, mesh: Mesh, transform: Transform3D) -> void:
	var faces := mesh.get_faces()
	var mirrored := transform.basis.determinant() < 0.0
	for t in range(0, faces.size(), 3):
		out.append(transform * faces[t])
		out.append(transform * (faces[t + 1] if mirrored else faces[t + 2]))
		out.append(transform * (faces[t + 2] if mirrored else faces[t + 1]))

## Welds and repairs `triangles` (three points per triangle, Box3D order). Returns
## {vertices, indices, zero_area, buried, t_junctions, crowded_edges}; crowded_edges
## counts edges still shared by more than two triangles (Box3D cannot smooth those).
static func build(triangles: PackedVector3Array, weld_distance: float = 0.001) -> Dictionary:
	var welded := {}
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var zero_area := 0
	for t in range(0, triangles.size() - 2, 3):
		var a := _weld(triangles[t], welded, vertices, weld_distance)
		var b := _weld(triangles[t + 1], welded, vertices, weld_distance)
		var c := _weld(triangles[t + 2], welded, vertices, weld_distance)
		if a == b or b == c or a == c or (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).length_squared() <= 1e-12:
			zero_area += 1
			continue
		indices.append_array([a, b, c])
	var twins := _remove_twins(indices)
	var covered := _remove_covered(twins[0], vertices, weld_distance)
	# Make every edge conforming first, so buried faces show up as crowded edges.
	var split := _split_t_junctions(covered[0], vertices, weld_distance)
	var twins_after := _remove_twins(split[0])
	var covered_after := _remove_covered(twins_after[0], vertices, weld_distance)
	var enclosed := _remove_enclosed(covered_after[0], vertices, weld_distance)
	indices = enclosed[0]
	return {
		"vertices": vertices,
		"indices": indices,
		"zero_area": zero_area,
		"buried": twins[1] + covered[1] + twins_after[1] + covered_after[1] + enclosed[1],
		"t_junctions": split[1],
		"crowded_edges": _crowded_edges(indices),
	}

# One index per weld cell; the first vertex seen keeps its exact position.
static func _weld(v: Vector3, welded: Dictionary, vertices: PackedVector3Array, weld_distance: float) -> int:
	var key := Vector3i((v / weld_distance).round())
	var found: Variant = welded.get(key)
	if found != null:
		return found
	welded[key] = vertices.size()
	vertices.append(v)
	return vertices.size() - 1

# Removes back-to-back pairs (same vertices, opposite winding) and exact duplicates.
# Returns [kept indices, removed triangle count].
static func _remove_twins(indices: PackedInt32Array) -> Array:
	var groups := {}
	for t in range(0, indices.size(), 3):
		var key := [indices[t], indices[t + 1], indices[t + 2]]
		key.sort()
		groups.get_or_add(Vector3i(key[0], key[1], key[2]), []).append(t)
	var kept := PackedInt32Array()
	var removed := 0
	for triangles: Array in groups.values():
		var forward := []
		var backward := []
		for t: int in triangles:
			if _rotation(indices, t) == _rotation(indices, triangles[0]):
				forward.append(t)
			else:
				backward.append(t)
		var pairs := mini(forward.size(), backward.size())
		var rest: Array = forward.slice(pairs) if forward.size() > pairs else backward.slice(pairs)
		removed += triangles.size()
		if not rest.is_empty():
			var t: int = rest[0]
			kept.append_array([indices[t], indices[t + 1], indices[t + 2]])
			removed -= 1
	return [kept, removed]

# Removes faces lying entirely on coplanar faces that point the opposite way, such
# as the end caps of touching pieces that triangulate their caps differently. A face
# is removed only when its corners and centre are all covered, so a partly exposed
# face (a step between pieces of different heights) stays.
static func _remove_covered(indices: PackedInt32Array, vertices: PackedVector3Array, weld_distance: float) -> Array:
	var planes := {}
	var keys := []
	for t in range(0, indices.size(), 3):
		var key := _plane_key(indices, vertices, t, false, weld_distance)
		keys.append(key)
		planes.get_or_add(key, []).append(t)
	var kept := PackedInt32Array()
	var removed := 0
	for i in keys.size():
		var t := i * 3
		var key := _plane_key(indices, vertices, t, true, weld_distance)
		var opposite: Array = []
		for step in [-1, 0, 1]:
			opposite.append_array(planes.get(Vector4i(key.x, key.y, key.z, key.w + step), []))
		var a := vertices[indices[t]]
		var b := vertices[indices[t + 1]]
		var c := vertices[indices[t + 2]]
		var covered := not opposite.is_empty()
		for point in [a, b, c, (a + b + c) / 3.0]:
			if not covered:
				break
			covered = false
			for o: int in opposite:
				if _inside(point, vertices[indices[o]], vertices[indices[o + 1]], vertices[indices[o + 2]], weld_distance):
					covered = true
					break
		if covered:
			removed += 1
		else:
			kept.append_array([indices[t], indices[t + 1], indices[t + 2]])
	return [kept, removed]

# Removes faces inside another solid, such as a bump's base, which leave three
# triangles on the bump's base edges. Only faces on an edge still shared by more
# than two triangles are considered, and one counts as enclosed only when rays
# leaving its front in five directions (along the normal and tilted 45 degrees four
# ways) all first meet the BACK of another triangle, starting either 1 weld
# distance or 1/50 of one off the face.
static func _remove_enclosed(indices: PackedInt32Array, vertices: PackedVector3Array, weld_distance: float) -> Array:
	var uses := _edge_uses(indices)
	var kept := PackedInt32Array()
	var removed := 0
	for t in range(0, indices.size(), 3):
		var crowded := false
		for k in 3:
			if uses[_edge(indices[t + k], indices[t + (k + 1) % 3])] > 2:
				crowded = true
		if crowded and _enclosed(indices, vertices, t, weld_distance):
			removed += 1
		else:
			kept.append_array([indices[t], indices[t + 1], indices[t + 2]])
	return [kept, removed]

static func _enclosed(indices: PackedInt32Array, vertices: PackedVector3Array, t: int, weld_distance: float) -> bool:
	var a := vertices[indices[t]]
	var b := vertices[indices[t + 1]]
	var c := vertices[indices[t + 2]]
	var n := (b - a).cross(c - a).normalized()
	var tangent := (b - a).normalized()
	var bitangent := n.cross(tangent)
	# The ray along the normal is tilted a fraction of a degree: a symmetric face
	# (a bump's rim sliver) has its centre exactly under the seam between two
	# triangles, and a ray along that seam can miss both.
	var normal := (n + tangent * 0.0123 + bitangent * 0.0071).normalized()
	var directions := [normal, (n + tangent).normalized(), (n - tangent).normalized(), (n + bitangent).normalized(), (n - bitangent).normalized()]
	# Rays start weld_distance off the face, or much closer: a thin sliver under a
	# shallow slope (a bump's rim) is buried by far less than weld_distance.
	for offset in [weld_distance, weld_distance * 0.02]:
		var from: Vector3 = (a + b + c) / 3.0 + n * offset
		var all_back := true
		for direction in directions:
			if not _first_hit_is_back_face(indices, vertices, t, from, direction):
				all_back = false
				break
		if all_back:
			return true
	return false

# Whether the nearest triangle the ray meets (other than `skip`) faces away from it.
static func _first_hit_is_back_face(indices: PackedInt32Array, vertices: PackedVector3Array, skip: int, from: Vector3, direction: Vector3) -> bool:
	var nearest := INF
	var back := false
	for o in range(0, indices.size(), 3):
		if o == skip:
			continue
		var oa := vertices[indices[o]]
		var ob := vertices[indices[o + 1]]
		var oc := vertices[indices[o + 2]]
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, direction, oa, ob, oc)
		if hit == null:
			continue
		var distance := from.distance_to(hit)
		if distance < nearest:
			nearest = distance
			back = (ob - oa).cross(oc - oa).dot(direction) > 0.0
	return back

# Splits every triangle whose edges have other vertices lying inside them, until no
# edge does. A triangle with points on one edge is fanned from the opposite corner;
# with points on several edges it is fanned from a new vertex at its centre. Both
# keep its winding. Returns [new indices, triangles split]; may append to `vertices`.
static func _split_t_junctions(indices: PackedInt32Array, vertices: PackedVector3Array, weld_distance: float) -> Array:
	var splits := 0
	for _round in 8:
		var grid := _vertex_grid(vertices)
		var out := PackedInt32Array()
		var changed := false
		for t in range(0, indices.size(), 3):
			var corners := [indices[t], indices[t + 1], indices[t + 2]]
			var points := []
			var edges_with_points := 0
			for k in 3:
				var inside := _vertices_inside(vertices, grid, corners[k], corners[(k + 1) % 3], weld_distance)
				points.append(inside)
				if not inside.is_empty():
					edges_with_points += 1
			if edges_with_points == 0:
				out.append_array(corners)
				continue
			changed = true
			splits += 1
			if edges_with_points == 1:
				for k in 3:
					if points[k].is_empty():
						continue
					var chain: Array = [corners[k]] + points[k] + [corners[(k + 1) % 3]]
					var apex: int = corners[(k + 2) % 3]
					for i in chain.size() - 1:
						out.append_array([chain[i], chain[i + 1], apex])
			else:
				var polygon := []
				for k in 3:
					polygon.append(corners[k])
					polygon.append_array(points[k])
				vertices.append((vertices[corners[0]] + vertices[corners[1]] + vertices[corners[2]]) / 3.0)
				var centre := vertices.size() - 1
				for i in polygon.size():
					out.append_array([polygon[i], polygon[(i + 1) % polygon.size()], centre])
		indices = out
		if not changed:
			break
	return [indices, splits]

const GRID_CELL := 0.25

static func _vertex_grid(vertices: PackedVector3Array) -> Dictionary:
	var grid := {}
	for v in vertices.size():
		grid.get_or_add(Vector3i((vertices[v] / GRID_CELL).floor()), PackedInt32Array()).append(v)
	return grid

# The vertices lying strictly inside segment a-b (within weld_distance of it and more
# than weld_distance from both ends), ordered from a to b.
static func _vertices_inside(vertices: PackedVector3Array, grid: Dictionary, a: int, b: int, weld_distance: float) -> Array:
	var origin := vertices[a]
	var span := vertices[b] - origin
	var length := span.length()
	if length <= 2.0 * weld_distance:
		return []
	var low := Vector3i(((origin.min(vertices[b]) - Vector3.ONE * weld_distance) / GRID_CELL).floor())
	var high := Vector3i(((origin.max(vertices[b]) + Vector3.ONE * weld_distance) / GRID_CELL).floor())
	var found := []
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for z in range(low.z, high.z + 1):
				var cell: Variant = grid.get(Vector3i(x, y, z))
				if cell == null:
					continue
				for v: int in cell:
					if v == a or v == b:
						continue
					var t := (vertices[v] - origin).dot(span) / (length * length)
					if t * length <= weld_distance or (1.0 - t) * length <= weld_distance:
						continue
					if (origin + span * t).distance_to(vertices[v]) <= weld_distance:
						found.append([t, v])
	found.sort_custom(func(p, q): return p[0] < q[0])
	return found.map(func(p): return p[1])

# The triangle's vertices rotated to start at the smallest index, keeping winding.
static func _rotation(indices: PackedInt32Array, t: int) -> Vector3i:
	var a := indices[t]
	var b := indices[t + 1]
	var c := indices[t + 2]
	if a < b and a < c:
		return Vector3i(a, b, c)
	if b < c:
		return Vector3i(b, c, a)
	return Vector3i(c, a, b)

# A triangle's plane, quantized: unit normal to 1/50 (about a degree) and the
# offset along that rounded normal to weld_distance. Kit pieces are rarely exact
# (a 1 m tile may span 0.9999 m), so faces that meet back to back can differ by a
# fraction of a millimetre; measuring the offset along the rounded normal keeps a
# hair of tilt from moving a face far from its partner. Callers also check the
# neighbouring offsets.
static func _plane_key(indices: PackedInt32Array, vertices: PackedVector3Array, t: int, flip: bool, weld_distance: float) -> Vector4i:
	var a := vertices[indices[t]]
	var n := (vertices[indices[t + 1]] - a).cross(vertices[indices[t + 2]] - a).normalized()
	if flip:
		n = -n
	var q := Vector3i((n * 50.0).round())
	return Vector4i(q.x, q.y, q.z, roundi(Vector3(q).normalized().dot(a) / weld_distance))

# Whether a coplanar point lies inside triangle abc, edges included.
static func _inside(p: Vector3, a: Vector3, b: Vector3, c: Vector3, weld_distance: float) -> bool:
	var n := (b - a).cross(c - a)
	for edge in [[a, b], [b, c], [c, a]]:
		var e: Vector3 = edge[1] - edge[0]
		if (p - edge[0]).dot(e.cross(n).normalized()) > weld_distance:
			return false
	return true

static func _edge(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))

static func _edge_uses(indices: PackedInt32Array) -> Dictionary:
	var uses := {}
	for t in range(0, indices.size(), 3):
		for k in 3:
			var edge := _edge(indices[t + k], indices[t + (k + 1) % 3])
			uses[edge] = uses.get(edge, 0) + 1
	return uses

static func _crowded_edges(indices: PackedInt32Array) -> int:
	var crowded := 0
	for count: int in _edge_uses(indices).values():
		if count > 2:
			crowded += 1
	return crowded
