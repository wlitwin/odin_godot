@tool
class_name Box3DWorld3D
extends Node3D

@export var stable_key: String = "world"
@export var gravity: Vector3 = Vector3(0,-9.81,0)
@export var enable_sleep: bool = true

func _snapshot() -> Dictionary:
	var d:=Box3DAuthoringData
	var errors: Array = []
	d.key(stable_key,"namespace",errors)
	var gravity_data:=d.vector(gravity,"gravity",errors)
	var bodies: Array = []
	var joints: Array = []
	var characters: Array = []
	var body_types: Dictionary = {}
	var joint_keys: Dictionary = {}
	var character_keys: Dictionary = {}
	var keys: Dictionary = {}
	var shapes_count:=0
	var dynamic_count:=0
	d.validate_world_frame(self,errors)
	if errors.is_empty():
		var pending: Array[Node] = [self]
		var visited:=0
		while not pending.is_empty():
			var node: Node = pending.pop_back()
			visited+=1
			if visited>4096:
				d.issue(errors,"world.children","Capacity","Authoring traversal exceeds4096 nodes.")
				break
			if node!=self and node.has_method("box3d_definition"):
				continue # nested worlds have their own explicit namespace
			if node is Box3DBody3D:
				var path: String = "bodies["+d.relative_name(node,self)+"]"
				if keys.has(node.stable_key):
					d.issue(errors,path+".stable_key","Duplicate","Duplicate body key: "+node.stable_key)
				keys[node.stable_key]=true
				if bodies.size()>=d.MAX_BODIES:
					d.issue(errors,path,"Capacity","Body count exceeds35.")
					break
				var body: Dictionary = node.box3d_body_definition(self,path,errors)
				bodies.append(body)
				body_types[body.stable_key]=body.body_type
				if body.body_type=="dynamic":dynamic_count+=1
				shapes_count+=body.shapes.size()
			elif node is Box3DJoint3D:
				var path: String = "joints["+d.relative_name(node,self)+"]"
				if joint_keys.has(node.stable_key):d.issue(errors,path+".stable_key","Duplicate","Duplicate joint key.")
				joint_keys[node.stable_key]=true
				if joints.size()>=d.MAX_JOINTS:d.issue(errors,path,"Capacity","Current profile permits one joint at a time.")
				else:joints.append(node.box3d_joint_definition(self,path,errors))
			elif node is Box3DCharacterMover3D:
				var path: String = "characters["+d.relative_name(node,self)+"]"
				if character_keys.has(node.stable_key):d.issue(errors,path+".stable_key","Duplicate","Duplicate character key.")
				character_keys[node.stable_key]=true
				if characters.size()>=d.MAX_CHARACTERS:d.issue(errors,path,"Capacity","Character count exceeds35.")
				else:characters.append(node.box3d_character_definition(self,path,errors))
			for child in node.get_children():pending.append(child)
	if shapes_count>d.MAX_SHAPES:d.issue(errors,"bodies.shapes","Capacity","Total shape count exceeds35.")
	if dynamic_count>32:d.issue(errors,"bodies.body_type","Capacity","Dynamic body count exceeds32.")
	for joint in joints:
		if not body_types.has(joint.body_a) or not body_types.has(joint.body_b):
			d.issue(errors,"joints["+joint.stable_key+"].body_a/body_b","Reference","References must name bodies in this World namespace, not another World/NodePath.")
		elif body_types[joint.body_a]=="static" and body_types[joint.body_b]=="static":
			d.issue(errors,"joints["+joint.stable_key+"].body_a/body_b","Unsupported","A native constraint cannot join two Static bodies.")
	for character in characters:
		if not character.exclude_body.is_empty() and not body_types.has(character.exclude_body):
			d.issue(errors,"characters["+character.stable_key+"].exclude_body","Reference","Self exclusion must name a body in this World, or be empty.")
	joints.sort_custom(func(a,b):return a.stable_key<b.stable_key)
	characters.sort_custom(func(a,b):return a.stable_key<b.stable_key)
	# Shared bake alone deduplicates geometry and enforces the Native8-asset limit.
	bodies.sort_custom(func(a,b):return a.stable_key<b.stable_key)
	var definition: Dictionary = {"schema_version":d.SCHEMA_VERSION,"namespace":stable_key,"gravity":gravity_data,"enable_sleep":enable_sleep,"bodies":bodies}
	if not joints.is_empty() or not characters.is_empty():
		definition.schema_version=d.MOTION_SCHEMA_VERSION
		definition["joints"]=joints
		definition["characters"]=characters
	var encoded: String = ""
	if errors.is_empty():
		encoded=JSON.stringify(definition,"",true,true)
		if encoded.to_utf8_buffer().size()>d.MAX_BYTES:
			d.issue(errors,"definition","Capacity","Detached definition exceeds the shared2MiB input limit.")
	return {"definition":definition,"errors":errors,"encoded":encoded}

func box3d_diagnostics() -> Array:
	return _snapshot().errors.duplicate(true)

func box3d_diagnostics_json() -> String:
	return JSON.stringify(box3d_diagnostics(),"",true,true)

func box3d_definition() -> Dictionary:
	var snapshot:=_snapshot()
	return snapshot.definition.duplicate(true) if snapshot.errors.is_empty() else {}

func box3d_definition_json() -> String:
	var snapshot:=_snapshot()
	if not snapshot.errors.is_empty():return ""
	# Preserve the actual Godot values' precision. Shared bake owns geometry,
	# stable IDs, collisions and canonical content; this does not build physics.
	return snapshot.encoded

func _get_configuration_warnings() -> PackedStringArray:
	return Box3DAuthoringData.warnings(box3d_diagnostics())
