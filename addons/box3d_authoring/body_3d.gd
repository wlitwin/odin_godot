@tool
class_name Box3DBody3D
extends Node3D

@export var stable_key: String = ""
@export_enum("Static","Kinematic","Dynamic") var body_type: int = 0
@export var linear_velocity: Vector3 = Vector3.ZERO
@export var angular_velocity: Vector3 = Vector3.ZERO
@export var linear_damping: float = 0.0
@export var angular_damping: float = 0.0
@export var gravity_scale: float = 1.0
@export var sleep_threshold: float = 0.05
@export var enable_sleep: bool = true
@export var is_awake: bool = true
@export var is_bullet: bool = false
@export var is_enabled: bool = true
@export var sensor: bool = false
@export var shapes: Array[Box3DShape3D] = []
@export_group("Motion")
## Lift Box3D's spin cap (a quarter turn per physics step, 47 rad/s at 60 Hz) for
## round bodies that roll fast, such as wheels and balls.
@export var allow_fast_rotation: bool = false
## Axes the body cannot move along or turn about.
@export_flags("Move X", "Move Y", "Move Z", "Turn X", "Turn Y", "Turn Z") var motion_locks: int = 0
## Continuous-collision margin, as a fraction of the shape's size; 0 keeps Box3D's 0.5.
@export var safety_factor: float = 0.0
## Recycling contacts between steps saves work; turn it off only to diagnose contact issues.
@export var disable_contact_recycling: bool = false

func _sensor_body() -> bool:
	return sensor

func box3d_body_definition(world: Node3D, path: String, errors: Array) -> Dictionary:
	var d:=Box3DAuthoringData
	d.key(stable_key,path+".stable_key",errors)
	if body_type<0 or body_type>2:
		d.issue(errors,path+".body_type","Unsupported","Choose Static, Kinematic or Dynamic.")
	var kind: String = ["static","kinematic","dynamic"][clampi(body_type,0,2)]
	for field in ["linear_damping","angular_damping","sleep_threshold"]:
		d.scalar(get(field),path+"."+field,errors,true)
	d.scalar(gravity_scale,path+".gravity_scale",errors)
	d.scalar(safety_factor,path+".safety_factor",errors,true)
	if motion_locks<0 or motion_locks>63:
		d.issue(errors,path+".motion_locks","Dimension","Motion locks are six axis flags.")
	var shape_data: Array = []
	var keys: Dictionary = {}
	if shapes.size()>d.MAX_SHAPES:
		d.issue(errors,path+".shapes","Capacity","Shape count exceeds35.")
	for i in range(mini(shapes.size(),d.MAX_SHAPES)):
		var shape:=shapes[i]
		var shape_path:=path+".shapes[%d]"%i
		if shape==null:
			d.issue(errors,shape_path,"Reference","Shape resource is missing.")
			continue
		if keys.has(shape.stable_key):
			d.issue(errors,shape_path+".stable_key","Duplicate","Duplicate shape key on this body: "+shape.stable_key)
		keys[shape.stable_key]=true
		shape_data.append(shape.box3d_shape_definition(shape_path,errors,kind,_sensor_body()))
	shape_data.sort_custom(func(a,b):return a.stable_key<b.stable_key)
	return {"stable_key":stable_key,"body_type":kind,"pose":d.relative_pose(self,world,path,errors),
		"linear_velocity":d.vector(linear_velocity,path+".linear_velocity",errors),"angular_velocity":d.vector(angular_velocity,path+".angular_velocity",errors),
		"linear_damping":linear_damping,"angular_damping":angular_damping,"gravity_scale":gravity_scale,"sleep_threshold":sleep_threshold,
		"enable_sleep":enable_sleep,"is_awake":is_awake,"is_bullet":is_bullet,"is_enabled":is_enabled,"allow_fast_rotation":allow_fast_rotation,"motion_locks":motion_locks,"safety_factor":safety_factor,
		"disable_contact_recycling":disable_contact_recycling,"sensor":_sensor_body(),"shapes":shape_data}

func _get_configuration_warnings() -> PackedStringArray:
	var current:=get_parent()
	while current!=null:
		if current.has_method("box3d_diagnostics"):
			return Box3DAuthoringData.warnings(current.call("box3d_diagnostics"))
		current=current.get_parent()
	return PackedStringArray(["Place this authoring body below a Box3DWorld3D."])
