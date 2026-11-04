extends SceneTree
var services: Box3DEditorServices
var probe: Node
func fail(message: String) -> void:
	push_error("BOX3D_EDITOR_RUNTIME_FAIL: "+message)
	if services!=null:services.dispose()
	if probe!=null:probe.free()
	quit(1)
func native_stats() -> Dictionary:return JSON.parse_string(String(probe.call("stats")))
func frame_case(path: String,label: String) -> bool:
	var encoded: String=FileAccess.get_file_as_string(path)
	var data: Variant=JSON.parse_string(encoded)
	if not data is Dictionary:fail(label+" actual frame JSON unavailable");return false
	var expected: Dictionary={}
	for field in ["version","epoch_hex","tick_hex","revision_hex","source"]:expected[field]=data.get(field)
	var draw:=Box3DDebugDraw3D.new();root.add_child(draw)
	var disabled: Dictionary=draw.submit_frame_json(encoded,expected)
	if not disabled.get("ok",false) or draw.mesh!=null:draw.free();fail("defaultOFF");return false
	draw.enabled=true
	var before: Dictionary=native_stats();var result: Dictionary=draw.submit_frame_json(encoded,expected)
	if not result.get("ok",false) or result.lines!=data.colors.size() or draw.mesh==null or draw.mesh.get_surface_count()!=1:draw.free();fail(label+" actual line draw: "+JSON.stringify(result));return false
	var after: Dictionary=native_stats()
	if before!=after:draw.free();fail(label+" drawing changed actual Native stats");return false
	var stale: Dictionary=expected.duplicate(true);stale.tick_hex="ffffffffffffffff"
	var rejected: Dictionary=draw.submit_frame_json(encoded,stale)
	if rejected.get("ok",true) or rejected.get("error","")!="Stale" or draw.mesh!=null:draw.free();fail("stale clear");return false
	draw.enabled=false;draw.free();print("BOX3D_EDITOR_FRAME ",label," actual_file=",path," lines=",result.lines," NativeDelta=0");return true
func _initialize() -> void:
	probe=Node.new();probe.set_script(load("res://modules/editor_probe/probe.odin"));root.add_child(probe)
	services=Box3DEditorServices.new(root)
	var installed: Dictionary=services.install_once()
	if not installed.get("ok",false) or installed.get("copied",-1)!=0 or not services.available():fail("ordinary installed tools: "+JSON.stringify(installed));return
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.BACK]);arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2])
	var source:=ArrayMesh.new();source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var transform:=Transform3D(Basis.IDENTITY.scaled(Vector3(2,3,4)),Vector3(5,6,7))
	var flags:=Box3DMeshShape3D.new();flags.density=0.75;flags.friction=0.25;flags.category_bits=4;flags.mask_bits=31;flags.group_index=-1
	var first: Dictionary=Box3DEditorMeshBaker.bake_mesh(source,"mesh.imported",transform,flags,"procedural://actual-arraymesh","revision1")
	var second: Dictionary=Box3DEditorMeshBaker.bake_mesh(source,"mesh.imported",transform,flags,"procedural://actual-arraymesh","revision1")
	if not first.get("ok",false) or not second.get("ok",false):fail("actual ArrayMesh extraction");return
	var shape: Box3DMeshShape3D=first.resource;var errors: Array=[]
	if shape.vertices.size()!=6 or shape.indices!=PackedInt32Array([0,1,2,3,4,5]) or shape.vertices[0]!=Vector3(5,6,7) or shape.density!=0.75 or shape.enable_sensor_events or shape.box3d_shape_definition("shape",errors,"static",false)!=second.resource.box3d_shape_definition("shape",errors,"static",false):fail("actual surfaces/transform/flags/determinism");return
	if ResourceSaver.save(shape,"res://baked-mesh.tres")!=OK:fail("shape Resource save");return
	var loaded: Box3DMeshShape3D=ResourceLoader.load("res://baked-mesh.tres","",ResourceLoader.CACHE_MODE_IGNORE)
	if loaded==null or loaded==shape or loaded.authoring_metadata!=shape.authoring_metadata or loaded.vertices!=shape.vertices:fail("shape Resource metadata/data roundtrip");return
	var world:=Box3DWorld3D.new();world.stable_key="mesh.bake";var body:=Box3DBody3D.new();body.stable_key="body";body.shapes.append(shape);world.add_child(body)
	var result: Dictionary=services.bake_definition(world.box3d_definition(),"res://baked-mesh.tres","revision1")
	if not result.get("ok",false) or not result.get("artifact_base64","") is String or result.metadata.bake_sha256.length()!=64:world.free();fail("actual shared artifact bake: "+JSON.stringify(result));return
	var original_hash: String=result.metadata.bake_sha256
	world.free();source.clear_surfaces();source=null;arrays.clear();first.clear();second.clear();flags=null;shape=null;loaded=null
	var checked: Dictionary=services.inspect_artifact(result.artifact_base64)
	if not checked.get("ok",false) or checked.metadata.bake_sha256!=original_hash:fail("owning artifact source-free load");return
	var native: Dictionary=JSON.parse_string(String(probe.call("build_artifact",result.artifact_base64)))
	if not native.get("ok",false) or not native.get("cleanup",false):fail("actual imported ArrayMesh artifact Native construction/step/cleanup: "+JSON.stringify(native));return
	print("BOX3D_EDITOR_IMPORTED_NATIVE source_free=true body_count=",native.body_count," shape_count=",native.shape_count," step=true cleanup=0")
	var resource:=Box3DBakeArtifact.new();resource.artifact_base64=result.artifact_base64;resource.imported_metadata=checked.metadata
	if ResourceSaver.save(resource,"res://bake-artifact.tres")!=OK:fail("artifact Resource save");return
	var reloaded: Box3DBakeArtifact=ResourceLoader.load("res://bake-artifact.tres","",ResourceLoader.CACHE_MODE_IGNORE)
	if reloaded==null or not reloaded.inspect_with(services).get("ok",false):fail("artifact Resource strict reload");return
	var corrupt: PackedByteArray=Marshalls.base64_to_raw(resource.artifact_base64);corrupt[corrupt.size()-1]^=1
	if services.inspect_artifact(Marshalls.raw_to_base64(corrupt)).get("ok",true):fail("corrupt artifact accepted");return
	if int(probe.call("native_images"))!=1:fail("actual Native image census");return
	if not frame_case("res://data/kit-frame.json","Kit") or not frame_case("res://data/replay-frame.json","Replay"):return
	services.dispose();services=null;probe.free();probe=null
	print("BOX3D_EDITOR_RUNTIME_OK mesh=true artifact_source_free=true ResourceRoundtrip=true actual_Kit_Replay_frames=true NativeDelta=0 no_manual_pixel_claim=true")
	quit(0)
