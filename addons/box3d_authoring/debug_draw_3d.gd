@tool
class_name Box3DDebugDraw3D
extends MeshInstance3D

const MAX_LINES := 8192
const MAX_JSON_BYTES := 2097152
@export var enabled: bool=false:
	set(value):
		enabled=value
		if not enabled:mesh=null
var _status: Dictionary={"ok":true,"enabled":false,"lines":0}
func debug_draw_status() -> Dictionary:return _status.duplicate(true)
func _reject(error: String,clear_old: bool=false) -> Dictionary:
	if clear_old:mesh=null
	_status={"ok":false,"error":error,"lines":0 if clear_old else _status.get("lines",0)};return debug_draw_status()
func _stamp(stamp: Dictionary) -> bool:
	if stamp.get("version",0)!=1 or stamp.get("source","") not in ["Predicted","Confirmed","Observed"]:return false
	for field in ["epoch_hex","tick_hex","revision_hex"]:
		var value: Variant=stamp.get(field)
		if not value is String or value.length()!=16:return false
		for byte in value.to_utf8_buffer():
			if not (byte>=48 and byte<=57) and not (byte>=97 and byte<=102):return false
	return true
func submit_batch(points: PackedVector3Array,colors: PackedColorArray,stamp: Dictionary,expected: Dictionary) -> Dictionary:
	if not enabled:mesh=null;_status={"ok":true,"enabled":false,"lines":0};return debug_draw_status()
	if not _stamp(stamp) or not _stamp(expected):return _reject("InvalidStamp")
	if stamp!=expected:return _reject("Stale",true)
	if points.size()%2!=0 or (points.size()>>1)>MAX_LINES or colors.size()!=(points.size()>>1):return _reject("CapacityOrCount")
	for value in points:
		if not value.is_finite():return _reject("Nonfinite")
	for color in colors:
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):return _reject("Nonfinite")
	var candidate:=ImmediateMesh.new()
	if not points.is_empty():
		candidate.surface_begin(Mesh.PRIMITIVE_LINES)
		for i in range(points.size()):candidate.surface_set_color(colors[i>>1]);candidate.surface_add_vertex(points[i])
		candidate.surface_end()
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.vertex_color_use_as_albedo=true
	material_override=material;mesh=candidate
	_status={"ok":true,"enabled":true,"lines":(points.size()>>1),"stamp":stamp.duplicate(true)};return debug_draw_status()
func submit_frame_json(encoded: String,expected: Dictionary) -> Dictionary:
	if not enabled:mesh=null;_status={"ok":true,"enabled":false,"lines":0};return debug_draw_status()
	if encoded.to_utf8_buffer().size()>MAX_JSON_BYTES:return _reject("Capacity")
	var parsed: Variant=JSON.parse_string(encoded)
	if not parsed is Dictionary:return _reject("InvalidJSON")
	var stamp: Dictionary={}
	for field in ["version","epoch_hex","tick_hex","revision_hex","source"]:stamp[field]=parsed.get(field)
	var raw_points: Variant=parsed.get("points");var raw_colors: Variant=parsed.get("colors")
	if not raw_points is Array or not raw_colors is Array or raw_points.size()>2*MAX_LINES or raw_points.size()%2!=0 or raw_colors.size()!=(raw_points.size()>>1):return _reject("CapacityOrCount")
	var points:=PackedVector3Array();var colors:=PackedColorArray()
	for raw in raw_points:
		if not raw is Array or raw.size()!=3:return _reject("InvalidPoint")
		for value in raw:
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):return _reject("InvalidPoint")
		points.append(Vector3(raw[0],raw[1],raw[2]))
	for raw in raw_colors:
		if not raw is Array or raw.size()!=4:return _reject("InvalidColor")
		for value in raw:
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):return _reject("InvalidColor")
		colors.append(Color(raw[0],raw[1],raw[2],raw[3]))
	return submit_batch(points,colors,stamp,expected)
