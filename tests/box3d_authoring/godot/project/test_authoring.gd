extends SceneTree

var probe: Node

func fail(message: String) -> void:
	push_error("BOX3D_AUTHORING_FAIL: "+message)
	if probe!=null: probe.call("close")
	quit(1)

func extract(world: Node) -> Dictionary:
	return JSON.parse_string(String(probe.call("extract",world)))

func detached(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if not key is String or not detached(value[key]):return false
		return true
	if value is Array:
		for item in value:
			if not detached(item):return false
		return true
	return typeof(value) in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING]

func make_world() -> Dictionary:
	var world:=Box3DWorld3D.new()
	world.name="AuthoringPresentation";world.stable_key="sample.world";world.gravity=Vector3(0,-10,0)
	root.add_child(world)
	world.transform=Transform3D(Basis(Vector3.UP,0.2),Vector3(10,0,20))
	var box:=Box3DBoxShape3D.new();box.stable_key="box";box.half_extents=Vector3(0.4,0.5,0.6)
	box.local_pose=Transform3D(Basis(Vector3.UP,0.25),Vector3(0.125,0,0));box.scale=Vector3(1,2,1)
	var sphere:=Box3DSphereShape3D.new();sphere.stable_key="sphere";sphere.center=Vector3(0.125,0,0);sphere.radius=0.375
	var capsule:=Box3DCapsuleShape3D.new();capsule.stable_key="capsule";capsule.centers_a=Vector3(-0.25,-0.5,0);capsule.centers_b=Vector3(0.25,0.75,0)
	var hull:=Box3DHullShape3D.new();hull.stable_key="hull";hull.points=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP,Vector3.BACK])
	var mesh:=Box3DMeshShape3D.new();mesh.stable_key="mesh";mesh.vertices=PackedVector3Array([Vector3(-1,0,-1),Vector3(1,0,-1),Vector3(1,0,1),Vector3(-1,0,1)]);mesh.indices=PackedInt32Array([0,1,2,0,2,3])
	var heightfield:=Box3DHeightfieldShape3D.new();heightfield.stable_key="terrain";heightfield.heights=PackedFloat32Array([0,0.25,0.5,0])
	var resources: Array[Box3DShape3D]=[box,sphere,capsule,hull,mesh,heightfield]
	for i in range(resources.size()):
		var body:=Box3DBody3D.new();body.name="Presentation%d"%i;body.stable_key="body.%d"%i
		body.body_type=2 if i==0 else (1 if i==1 else 0)
		body.linear_velocity=Vector3(0.25,0,0);body.angular_velocity=Vector3(0,0.125,0)
		body.shapes.append(resources[i]);world.add_child(body);body.owner=world;body.position=Vector3(i*3,2,0)
	var sensor:=Box3DSensor3D.new();sensor.name="SensorPresentation";sensor.stable_key="sensor";sensor.shapes.append(sphere)
	world.add_child(sensor);sensor.owner=world;sensor.position=Vector3(0,4,0)
	# Same immutable geometry on another body, with different instance sensor flags.
	return {"world":world,"resources":resources}

func invalid(world: Box3DWorld3D, label: String) -> bool:
	var errors:=world.box3d_diagnostics()
	if errors.is_empty() or not world.box3d_definition_json().is_empty():fail(label+" diagnostics/export");return false
	for error in errors:
		if String(error.path).is_empty():fail(label+" missing field path");return false
	var answer:=extract(world)
	if answer.get("ok",true):fail(label+" accepted invalid authoring");return false
	if not probe.call("close"):fail(label+" failed checked cleanup");return false
	print("BOX3D_AUTHORING_INVALID ",label," ",JSON.stringify(errors))
	return true

func detached_transforms() -> bool:
	var offline:=Box3DWorld3D.new();offline.stable_key="offline"
	var parent:=Node3D.new();parent.name="LocalParent";parent.position=Vector3(1,0,0);offline.add_child(parent)
	var body:=Box3DBody3D.new();body.name="LocalBody";body.stable_key="body";body.position=Vector3(0,2,0);parent.add_child(body)
	var box:=Box3DBoxShape3D.new();box.stable_key="shape";body.shapes.append(box)
	var definition: Dictionary = offline.box3d_definition()
	var good: bool = not definition.is_empty() and definition.bodies[0].pose.position==[1.0,2.0,0.0]
	parent.scale=Vector3(2,1,1);body.scale=Vector3(0.5,1,1)
	good=good and not offline.box3d_diagnostics().is_empty() and offline.box3d_definition_json().is_empty()
	parent.scale=Vector3.ONE;body.scale=Vector3.ONE;body.top_level=true
	good=good and not offline.box3d_diagnostics().is_empty() and offline.box3d_definition_json().is_empty()
	offline.free()
	if not good:fail("detached local ancestry/scale/top-level contract")
	return good

func asset_geometry_boundary() -> bool:
	var offline:=Box3DWorld3D.new();offline.stable_key="asset.boundary"
	var body:=Box3DBody3D.new();body.stable_key="body";offline.add_child(body)
	for i in range(9):
		var shape:=Box3DBoxShape3D.new();shape.stable_key="resource.%d"%i;body.shapes.append(shape)
	var frontend_ok: bool = offline.box3d_diagnostics().is_empty() and not offline.box3d_definition_json().is_empty()
	var aliases: Dictionary = extract(offline)
	var aliases_ok: bool = frontend_ok and aliases.get("ok",false) and aliases.get("assets",0)==1 and aliases.get("shapes",0)==9 and aliases.get("bodies",0)==1
	var aliases_closed: bool = bool(probe.call("close"))
	var aliases_clean: bool = bool(probe.call("clean"))
	if not aliases_ok or not aliases_closed or not aliases_clean:
		offline.free();fail("nine logical aliases must share one baked geometry with checked cleanup: "+JSON.stringify(aliases));return false
	for i in range(9):
		body.shapes[i].set("half_extents",Vector3(0.5+float(i)*0.125,0.5,0.5))
	frontend_ok=offline.box3d_diagnostics().is_empty() and not offline.box3d_definition_json().is_empty()
	var distinct: Dictionary = extract(offline)
	# The existing probe wraps shared Diagnostic.error as Definition and exposes
	# its actual field. Shared fail(Capacity,"assets.count") is the exact site.
	var distinct_ok: bool = frontend_ok and not distinct.get("ok",true) and distinct.get("error","")=="Definition" and distinct.get("field","")=="assets.count"
	var distinct_closed: bool = bool(probe.call("close"))
	var distinct_clean: bool = bool(probe.call("clean"))
	offline.free()
	if not distinct_ok or not distinct_closed or not distinct_clean:
		fail("nine distinct geometries must reach shared assets.count Capacity with checked cleanup: "+JSON.stringify(distinct));return false
	print("BOX3D_AUTHORING_ASSET_BOUNDARY aliases=",JSON.stringify(aliases)," distinct=",JSON.stringify(distinct)," frontend_resourcecount_not_catalog=true cleanup=0")
	return true

func _initialize() -> void:
	var script=load("res://modules/authoring_probe/probe.odin")
	if script==null:fail("ordinary SDK module load");return
	probe=Node.new();probe.set_script(script);root.add_child(probe)
	if not detached_transforms():return
	if not asset_geometry_boundary():return
	var data:=make_world();var world:Box3DWorld3D=data.world
	var resources:Array[Box3DShape3D]=data.resources
	if not world.box3d_diagnostics().is_empty() or not detached(world.box3d_definition()):fail("valid detached definition");return
	var result:=extract(world)
	if not result.get("ok",false) or result.bodies!=7 or result.shapes!=7 or result.assets!=6 or result.baked_sensor_shapes!=1:fail("shared extraction: "+JSON.stringify(result));return
	var expected_hash:=String(probe.call("hash"));var expected_ids:=String(probe.call("logical_ids"))
	for i in range(resources.size()):
		var path:="res://shape-%d.tres"%i
		if ResourceSaver.save(resources[i],path)!=OK:fail("ordinary .tres save");return
		var loaded=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
		var errors:Array=[]
		if loaded==null or loaded==resources[i] or loaded.box3d_shape_definition("shape",errors,"static",false)!=resources[i].box3d_shape_definition("shape",errors,"static",false) or not errors.is_empty():fail(".tres exact exported values");return
	for child in world.get_children():
		child.name="RenamedPresentation"+child.name
		world.move_child(child,0)
	result=extract(world)
	if not result.get("ok",false) or String(probe.call("hash"))!=expected_hash or String(probe.call("logical_ids"))!=expected_ids:fail("stable IDs/content after child order/name changes");return
	var packed:=PackedScene.new()
	if packed.pack(world)!=OK or ResourceSaver.save(packed,"res://authored.tscn")!=OK:fail("ordinary .tscn save");return
	var loaded_packed=ResourceLoader.load("res://authored.tscn","",ResourceLoader.CACHE_MODE_IGNORE)
	var loaded_world:Box3DWorld3D=loaded_packed.instantiate();root.add_child(loaded_world)
	result=extract(loaded_world)
	if not result.get("ok",false) or String(probe.call("hash"))!=expected_hash or String(probe.call("logical_ids"))!=expected_ids:fail("ordinary .tscn reload identity");return
	loaded_world.free();loaded_packed=null;packed=null
	var body:Box3DBody3D=world.get_children()[0]
	var prior_key:=body.stable_key;body.stable_key=""
	if not invalid(world,"empty key"):return
	body.stable_key=prior_key
	var other:Box3DBody3D=world.get_children()[1];body.stable_key=other.stable_key
	if not invalid(world,"duplicate body key"):return
	body.stable_key=prior_key
	body.scale=Vector3(2,1,1)
	if not invalid(world,"body scale loss rejected"):return
	body.scale=Vector3.ONE
	var mesh:Box3DMeshShape3D=resources[4];mesh.enable_sensor_events=true
	if not invalid(world,"mesh sensor events explicit unsupported"):return
	mesh.enable_sensor_events=false
	var terrain:Box3DHeightfieldShape3D=resources[5];terrain.width=3
	if not invalid(world,"heightfield count"):return
	terrain.width=2
	var sphere:Box3DSphereShape3D=resources[1];sphere.radius=NAN
	if not invalid(world,"nonfinite radius"):return
	sphere.radius=0.375
	result=extract(world)
	if not result.get("ok",false) or String(probe.call("hash"))!=expected_hash:fail("restored valid source");return
	var world_weak:WeakRef=weakref(world);var resource_weak:WeakRef=weakref(resources[1])
	world.free();data.clear();resources.clear();sphere=null;mesh=null;terrain=null
	if world_weak.get_ref()!=null or resource_weak.get_ref()!=null:fail("source nodes/resources not actually freed");return
	# No authoring source remains. The copied bake alone constructs actual Native.
	var built:Dictionary=JSON.parse_string(String(probe.call("build")))
	if not built.get("ok",false) or built.body_count!=7 or built.shape_count!=7:fail("source-free Native construction: "+JSON.stringify(built));return
	if int(probe.call("native_images"))!=1:fail("actual one Native image census");return
	if not probe.call("close") or not probe.call("clean"):fail("checked Native/Meter cleanup0");return
	probe.free();probe=null
	print("BOX3D_AUTHORING_OK source_free=true tres=true tscn=true shapes=6 sensor=true ids_stable=true NativeImages=1 cleanup=0")
	quit(0)
