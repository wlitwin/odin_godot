extends SceneTree

const KINDS: Array[String]=["pin","hinge","slider","spherical","distance","motor","weld","wheel"]
var probe: Node
func fail(message: String) -> void:
	push_error("BOX3D_MOTION_FAIL: "+message)
	if probe!=null:probe.call("close")
	quit(1)
func extract(world: Node) -> Dictionary:
	return JSON.parse_string(String(probe.call("extract",world)))
func make_world() -> Box3DWorld3D:
	var world:=Box3DWorld3D.new();world.stable_key="motion";world.gravity=Vector3.ZERO
	var box:=Box3DBoxShape3D.new();box.stable_key="box"
	for i in range(2):
		var body:=Box3DBody3D.new();body.name="Presentation%d"%i;body.stable_key="body.a" if i==0 else "body.b";body.body_type=0 if i==0 else 2
		body.shapes.append(box);world.add_child(body);body.owner=world;body.position=Vector3(0,i*2,0)
	return world
func invalid(world: Box3DWorld3D,label: String) -> bool:
	var errors: Array=world.box3d_diagnostics()
	var result: Dictionary=extract(world)
	var good: bool=not errors.is_empty() and world.box3d_definition_json().is_empty() and not result.get("ok",true)
	var closed: bool=bool(probe.call("close"));var clean: bool=bool(probe.call("clean"))
	if not good or not closed or not clean:fail(label+" invalid path/cleanup: "+JSON.stringify(result));return false
	for error in errors:
		if String(error.path).is_empty():fail(label+" missing field path");return false
	print("BOX3D_MOTION_INVALID ",label," ",JSON.stringify(errors));return true
func joint_case(kind: String) -> bool:
	var world:=make_world();world.stable_key="motion."+kind
	var joint: Box3DJoint3D=load("res://addons/box3d_authoring/"+kind+"_joint_3d.gd").new()
	joint.name="JointPresentation";joint.stable_key="joint";joint.body_a="body.a";joint.body_b="body.b"
	joint.local_frame_a.origin=Vector3(0,2,0);world.add_child(joint);joint.owner=world
	var result: Dictionary=extract(world)
	if not result.get("ok",false) or result.joints!=1 or result.characters!=0:world.free();fail(kind+" actual schema2 extraction: "+JSON.stringify(result));return false
	var expected_hash:=String(probe.call("hash"));var expected_ids:=String(probe.call("logical_ids"))
	var errors: Array=[];var settings_data: Dictionary=joint.settings.definition(kind,"settings",errors)
	if not errors.is_empty() or ResourceSaver.save(joint.settings,"res://"+kind+".tres")!=OK:world.free();fail(kind+" .tres save");return false
	var loaded_settings: Box3DJointSettings3D=ResourceLoader.load("res://"+kind+".tres","",ResourceLoader.CACHE_MODE_IGNORE)
	if loaded_settings==null or loaded_settings==joint.settings or loaded_settings.definition(kind,"settings",errors)!=settings_data or not errors.is_empty():world.free();fail(kind+" .tres values");return false
	loaded_settings=null
	for child in world.get_children():world.move_child(child,0);child.name="Renamed"+child.name
	result=extract(world)
	if not result.get("ok",false) or String(probe.call("hash"))!=expected_hash or String(probe.call("logical_ids"))!=expected_ids:world.free();fail(kind+" order-independent IDs");return false
	var packed:=PackedScene.new()
	if packed.pack(world)!=OK or ResourceSaver.save(packed,"res://"+kind+".tscn")!=OK:world.free();fail(kind+" .tscn save");return false
	var loaded_packed: PackedScene=ResourceLoader.load("res://"+kind+".tscn","",ResourceLoader.CACHE_MODE_IGNORE)
	var loaded_world: Box3DWorld3D=loaded_packed.instantiate()
	result=extract(loaded_world)
	if not result.get("ok",false) or String(probe.call("hash"))!=expected_hash:loaded_world.free();world.free();fail(kind+" .tscn identity");return false
	loaded_world.free();loaded_packed=null;packed=null
	if kind=="hinge":
		joint.body_b="missing"
		if not invalid(world,"missing/cross-world body key"):world.free();return false
		joint.body_b=joint.body_a
		if not invalid(world,"self joint"):world.free();return false
		joint.body_b="body.b";joint.local_frame_b=Transform3D(Basis.IDENTITY.scaled(Vector3(2,1,1)),Vector3.ZERO)
		if not invalid(world,"nonrigid local frame"):world.free();return false
		joint.local_frame_b=Transform3D.IDENTITY
		result=extract(world)
		if not result.get("ok",false):world.free();fail("restore valid hinge");return false
	var source: WeakRef=weakref(world);var resource: WeakRef=weakref(joint.settings)
	world.free()
	if source.get_ref()!=null or resource.get_ref()!=null:fail(kind+" actual source destruction");return false
	var built: Dictionary=JSON.parse_string(String(probe.call("build")))
	if not built.get("ok",false) or built.joint_count!=1 or built.body_count!=2:fail(kind+" actual source-free native constraint: "+JSON.stringify(built));return false
	if int(probe.call("native_images"))!=1 or not probe.call("close") or not probe.call("clean"):fail(kind+" actual image/cleanup");return false
	print("BOX3D_MOTION_JOINT ",kind," native_joints=1 source_free=true tres=true tscn=true cleanup=0");return true
func character_case() -> bool:
	var world:=make_world();world.stable_key="motion.character"
	var mover:=Box3DCharacterMover3D.new();mover.stable_key="character";mover.exclude_body="body.b";mover.position=Vector3(3,4,0);mover.initial_velocity=Vector3(1,0,0)
	mover.config.max_slides=3;mover.config.radius=0.375;mover.config.floor_cosine=0.75;mover.config.category_bits=4;mover.config.mask_bits=31
	world.add_child(mover);mover.owner=world
	var errors: Array=[];var config_data: Dictionary=mover.config.box3d_character_config("config",errors)
	if not errors.is_empty() or ResourceSaver.save(mover.config,"res://character.tres")!=OK:world.free();fail("character .tres save");return false
	var loaded_config: Box3DCharacterConfig3D=ResourceLoader.load("res://character.tres","",ResourceLoader.CACHE_MODE_IGNORE)
	if loaded_config==null or loaded_config==mover.config or loaded_config.box3d_character_config("config",errors)!=config_data:world.free();fail("character .tres values");return false
	loaded_config=null
	var result: Dictionary=extract(world)
	if not result.get("ok",false) or result.characters!=1 or result.joints!=0:world.free();fail("actual character extraction");return false
	var expected_hash:=String(probe.call("hash"))
	var packed:=PackedScene.new()
	if packed.pack(world)!=OK or ResourceSaver.save(packed,"res://character.tscn")!=OK:world.free();fail("character .tscn save");return false
	var loaded_packed: PackedScene=ResourceLoader.load("res://character.tscn","",ResourceLoader.CACHE_MODE_IGNORE)
	var loaded_world: Box3DWorld3D=loaded_packed.instantiate();result=extract(loaded_world)
	if not result.get("ok",false) or String(probe.call("hash"))!=expected_hash:loaded_world.free();world.free();fail("character .tscn identity");return false
	loaded_world.free();loaded_packed=null;packed=null
	mover.config.max_slides=9
	if not invalid(world,"character slide bound"):world.free();return false
	mover.config.max_slides=3;result=extract(world)
	if not result.get("ok",false):world.free();fail("character restore valid");return false
	var source: WeakRef=weakref(world);var resource: WeakRef=weakref(mover.config);world.free()
	if source.get_ref()!=null or resource.get_ref()!=null:fail("character actual source destruction");return false
	var built: Dictionary=JSON.parse_string(String(probe.call("build")))
	var config: Dictionary=JSON.parse_string(String(probe.call("character")))
	if not built.get("ok",false) or built.joint_count!=0 or not config.get("ok",false) or config.max_slides!=3 or config.radius!=0.375 or config.position!=[3.0,4.0,0.0] or config.velocity!=[1.0,0.0,0.0] or not config.initial_grounding_zero or not config.exclude_resolved:fail("actual source-free config/POD: "+JSON.stringify(config));return false
	# Explicit fixture call only; authoring nodes never step or own this state.
	var moved: Dictionary=JSON.parse_string(String(probe.call("character_step")))
	if not moved.get("ok",false) or moved.displacement[0]<=0.0:fail("actual explicit fixed-step mover: "+JSON.stringify(moved));return false
	if not probe.call("close") or not probe.call("clean"):fail("character checked cleanup");return false
	print("BOX3D_MOTION_CHARACTER source_free=true config_copied=true explicit_native_step=true initial_grounding_zero=true cleanup=0");return true
func _initialize() -> void:
	var script=load("res://modules/motion_probe/probe.odin")
	if script==null:fail("ordinary SDK module");return
	probe=Node.new();probe.set_script(script);root.add_child(probe)
	for kind in KINDS:
		if not joint_case(kind):return
	if not character_case():return
	probe.free();probe=null
	print("BOX3D_MOTION_OK families=8 one_joint_at_once=true character=true NativeImages=1 cleanup=0")
	quit(0)
