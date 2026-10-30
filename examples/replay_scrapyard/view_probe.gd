extends RefCounted
# Read actual geometry and its base tint, independent of the node representation.
# Hierarchy/modulate animation remains separately observable on the node.
static var cache:Dictionary={}
static var reads:=0
static var read_us:=0
static var hits:=0
static func polygon(node) -> bool:
	return node is Polygon2D or node is MeshInstance2D
static func tint(node) -> Color:
	return (Color.WHITE if node is MeshInstance2D else node.color) * node.self_modulate
static func vertices(node) -> PackedVector2Array:
	if node is Polygon2D:return node.polygon
	var mesh:Mesh=node.mesh;var key:=mesh.get_instance_id()
	if cache.has(key):hits+=1;return cache[key]
	var began:=Time.get_ticks_usec();var points:=PackedVector2Array()
	for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:points.append(Vector2(vertex.x,vertex.y))
	reads+=1;read_us+=Time.get_ticks_usec()-began
	if cache.size()>=1024:cache.clear()
	cache[key]=points
	return points
