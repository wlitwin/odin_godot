extends SceneTree
# Reproduce the two authored loot polygons as immutable mesh resources.
func _initialize():
	var args:=OS.get_cmdline_user_args()
	if args.size()!=2:quit(2);return
	var packed:PackedScene=load(args[0]);var scene=packed.instantiate()
	for child in scene.get_children():
		if not child is Polygon2D:continue
		var arrays=[];arrays.resize(Mesh.ARRAY_MAX);var vertices:=PackedVector3Array()
		for point in child.polygon:vertices.append(Vector3(point.x,point.y,0))
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=Geometry2D.triangulate_polygon(child.polygon)
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var replacement:=MeshInstance2D.new();replacement.mesh=mesh;replacement.name=child.name;replacement.transform=child.transform;replacement.self_modulate=child.color*child.self_modulate;replacement.modulate=child.modulate
		var index:=child.get_index();scene.remove_child(child);scene.add_child(replacement);scene.move_child(replacement,index);replacement.owner=scene;child.free()
	var output:=PackedScene.new()
	if output.pack(scene)!=OK or ResourceSaver.save(output,args[1])!=OK:scene.free();quit(3);return
	scene.free();print("SCRAP_MESH_SCENE_CREATED");quit(0)
