@tool
class_name Box3DAuthoringData
extends RefCounted

const SCHEMA_VERSION := 1
const MOTION_SCHEMA_VERSION := 2
const MAX_JOINTS := 1
const MAX_CHARACTERS := 35
const MAX_KEY_BYTES := 128
const MAX_BODIES := 35
const MAX_SHAPES := 35
const MAX_ASSETS := 8
const MAX_HULL_POINTS := 256
const MAX_VERTICES := 4096
const MAX_INDICES := 24576
const MAX_GRID_SIDE := 64
const MAX_BYTES := 2097152
const MAX_ERRORS := 64
const EPS := 0.00001

static func issue(errors: Array, path: String, code: String, message: String) -> void:
	if errors.size()<MAX_ERRORS:
		errors.append({"path": path, "code": code, "message": message})

static func key(value: String, path: String, errors: Array) -> void:
	if value.strip_edges().is_empty() or value.to_utf8_buffer().size() > MAX_KEY_BYTES:
		issue(errors, path, "Key", "Use a nonempty explicit stable key of at most 128 UTF-8 bytes.")

static func scalar(value: float, path: String, errors: Array, nonnegative := false) -> void:
	if not is_finite(value):
		issue(errors, path, "Nonfinite", "Value must be finite.")
	elif nonnegative and value < 0.0:
		issue(errors, path, "Dimension", "Value must be nonnegative.")

static func vector(value: Vector3, path: String, errors: Array) -> Array:
	if not value.is_finite():
		issue(errors, path, "Nonfinite", "Vector components must be finite.")
	return [value.x, value.y, value.z]

static func rigid(value: Transform3D) -> bool:
	var b := value.basis
	return value.origin.is_finite() and b.x.is_finite() and b.y.is_finite() and b.z.is_finite() and absf(b.x.length_squared()-1.0) <= EPS and absf(b.y.length_squared()-1.0) <= EPS and absf(b.z.length_squared()-1.0) <= EPS and absf(b.x.dot(b.y)) <= EPS and absf(b.x.dot(b.z)) <= EPS and absf(b.y.dot(b.z)) <= EPS and absf(b.determinant()-1.0) <= EPS

static func pose(value: Transform3D, path: String, errors: Array) -> Dictionary:
	if not rigid(value):
		issue(errors, path, "Pose", "A finite unit rigid transform is required; scale/shear/reflection is not discarded. Use shape.scale for supported baked scale.")
		return {"position": [0.0,0.0,0.0], "rotation": [0.0,0.0,0.0,1.0]}
	var q := value.basis.get_rotation_quaternion()
	return {"position": [value.origin.x,value.origin.y,value.origin.z], "rotation": [q.x,q.y,q.z,q.w]}

# Ancestry queries/local transforms work for detached PackedScene instances.
# Diagnostic paths are names only and never enter stable identity/baked data.
static func relative_name(node: Node, ancestor: Node) -> String:
	var parts: PackedStringArray = []
	var current: Node = node
	while current!=null and current!=ancestor:
		parts.insert(0,String(current.name))
		current=current.get_parent()
	return "/".join(parts)

static func validate_world_frame(world: Node3D, errors: Array) -> void:
	var current: Node = world
	while current!=null:
		if current is Node3D:
			if current.top_level:
				issue(errors,"world.ancestry["+String(current.name)+"].top_level","Pose","Top-level authoring transforms are unsupported; use a rigid local ancestry.")
			if not rigid(current.transform):
				issue(errors,"world.ancestry["+String(current.name)+"].transform","Pose","Every World presentation transform must be finite and rigid; scale/shear/reflection is not discarded.")
		current=current.get_parent()

static func relative_pose(node: Node3D, world: Node3D, path: String, errors: Array) -> Dictionary:
	var chain: Array[Node3D] = []
	var current: Node = node
	while current!=null and current!=world:
		if current is Node3D:
			var field: String = path+".ancestry["+relative_name(current,world)+"]"
			if current.top_level:
				issue(errors,field+".top_level","Pose","Top-level detaches from the authored World frame and is unsupported.")
			if not rigid(current.transform):
				issue(errors,field+".transform","Pose","Every local transform must be finite and rigid; cancelling scale/shear is not silently accepted.")
			chain.append(current)
		current=current.get_parent()
	if current!=world:
		issue(errors,path+".pose","Reference","Body is not a descendant of the supplied World.")
		return {"position":[0.0,0.0,0.0],"rotation":[0.0,0.0,0.0,1.0]}
	var relative: Transform3D = Transform3D.IDENTITY
	for i in range(chain.size()-1,-1,-1):
		relative=relative*chain[i].transform
	return pose(relative,path+".pose",errors)

static func warnings(errors: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for error in errors:
		result.append("%s: %s" % [error.path, error.message])
	return result
