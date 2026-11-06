@tool
class_name Box3DShape3D
extends Resource

@export var stable_key: String = ""
@export var authoring_metadata: Dictionary = {}
@export var local_pose: Transform3D = Transform3D.IDENTITY
@export var scale: Vector3 = Vector3.ONE
@export var density: float = 1.0
@export var friction: float = 0.5
@export var restitution: float = 0.0
@export var category_bits: int = 1
@export var mask_bits: int = 4294967295
@export var group_index: int = 0
@export var is_sensor: bool = false
@export var enable_sensor_events: bool = true
@export var enable_contact_events: bool = false
@export_group("Surface")
## A torque opposing rolling, scaled by the shape's radius (Box3D's rolling
## resistance); 0 rolls freely. Keep it well below the friction against the floor,
## or friction cannot start a pushed body rolling.
@export var rolling_resistance: float = 0.0
## Conveyor-belt surface velocity (Box3D's tangent velocity).
@export var tangent_velocity: Vector3 = Vector3.ZERO
@export_group("Contacts")
## Skip creating contacts with existing overlaps when the shape is added.
@export var skip_contact_creation: bool = false
## Turn off speculative contacts (they catch fast bodies before they touch).
@export var disable_speculative_contact: bool = false

func _shape_kind() -> String:
	return ""

func _geometry(path: String, errors: Array) -> Dictionary:
	Box3DAuthoringData.issue(errors, path+".kind", "Unsupported", "Choose a concrete box, sphere, capsule, hull, mesh or heightfield resource.")
	return {}

func box3d_shape_definition(path: String, errors: Array, body_type: String, body_sensor: bool) -> Dictionary:
	var d := Box3DAuthoringData
	d.key(stable_key, path+".stable_key", errors)
	var pose_data := d.pose(local_pose, path+".local_pose", errors)
	var scale_data := d.vector(scale, path+".scale", errors)
	if scale.x <= 0.0 or scale.y <= 0.0 or scale.z <= 0.0:
		d.issue(errors, path+".scale", "Scale", "Scale must be positive; mirrors/zero axes are unsupported.")
	var kind := _shape_kind()
	if kind in ["sphere", "capsule"] and (absf(scale.x-scale.y)>d.EPS or absf(scale.x-scale.z)>d.EPS):
		d.issue(errors, path+".scale", "Scale", "Sphere/capsule scale must be uniform.")
	for field in ["density", "friction", "restitution", "rolling_resistance"]:
		d.scalar(get(field), path+"."+field, errors, true)
	var tangent_data := d.vector(tangent_velocity, path+".tangent_velocity", errors)
	if category_bits < 0 or mask_bits < 0:
		d.issue(errors, path+".filter", "Dimension", "Godot integer filter fields must be nonnegative; negative values are not reinterpreted as unsigned bits.")
	if group_index < -2147483648 or group_index > 2147483647:
		d.issue(errors, path+".group_index", "Dimension", "Group index must fit signed32.")
	if kind in ["mesh", "heightfield"]:
		if body_type != "static":
			d.issue(errors, path+".kind", "Unsupported", "Triangle mesh/heightfield requires a Static body.")
		if is_sensor or body_sensor:
			d.issue(errors, path+".is_sensor", "Unsupported", "Triangle mesh/heightfield cannot be a sensor.")
		if enable_sensor_events:
			d.issue(errors, path+".enable_sensor_events", "Unsupported", "Native mesh geometry does not support sensor events; this flag is never silently removed.")
	var result := {"stable_key":stable_key, "kind":kind, "local_pose":pose_data, "scale":scale_data,
		"half_extents":[0.5,0.5,0.5], "center":[0.0,0.0,0.0], "radius":0.5,
		"centers_a":[0.0,-0.5,0.0], "centers_b":[0.0,0.5,0.0], "vertices":[], "indices":[],
		"columns":0, "rows":0, "spacing":[1.0,1.0], "heights":[],
		"density":density,"friction":friction,"restitution":restitution,"category_bits":category_bits,
		"mask_bits":mask_bits,"group_index":group_index,"is_sensor":is_sensor,
		"enable_sensor_events":enable_sensor_events,"enable_contact_events":enable_contact_events,
		"rolling_resistance":rolling_resistance,"tangent_velocity":tangent_data,
		"skip_contact_creation":skip_contact_creation,"disable_speculative_contact":disable_speculative_contact}
	result.merge(_geometry(path,errors), true)
	return result
