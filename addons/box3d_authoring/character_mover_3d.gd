@tool
class_name Box3DCharacterMover3D
extends Node3D

@export var stable_key: String=""
@export var exclude_body: String=""
@export var config: Box3DCharacterConfig3D=Box3DCharacterConfig3D.new()
@export var initial_velocity: Vector3=Vector3.ZERO
func box3d_character_definition(world: Node3D,path: String,errors: Array) -> Dictionary:
	var d:=Box3DAuthoringData;d.key(stable_key,path+".stable_key",errors)
	var initial_pose: Dictionary=d.relative_pose(self,world,path,errors)
	if absf(initial_pose.rotation[0])+absf(initial_pose.rotation[1])+absf(initial_pose.rotation[2])>d.EPS:d.issue(errors,path+".rotation","Unsupported","Character config vectors are explicit World-frame vectors; mover marker rotation must be identity.")
	var configuration: Dictionary={}
	if config==null:d.issue(errors,path+".config","Reference","Character config Resource is missing.")
	else:configuration=config.box3d_character_config(path+".config",errors)
	return {"stable_key":stable_key,"exclude_body":exclude_body,"config":configuration,"initial":{"position":initial_pose.position,"velocity":d.vector(initial_velocity,path+".initial.velocity",errors)}}
func _get_configuration_warnings() -> PackedStringArray:
	var current:=get_parent()
	while current!=null:
		if current.has_method("box3d_diagnostics"):return Box3DAuthoringData.warnings(current.call("box3d_diagnostics"))
		current=current.get_parent()
	return PackedStringArray(["Place the mover below a Box3DWorld3D. It authors POD only; the framework owns stepping."])
