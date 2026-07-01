package godot

// Ergonomic helpers for loading resources / instancing scenes — hand-written and owned here
// (binding regeneration only rewrites *.gen.odin).

// load loads a resource by `res://` (or absolute) path through ResourceLoader, reusing the
// cache (Cache_Mode_Reuse). Collapses the singleton + two-String + cache-mode dance
// (`path` may be dynamic; the temporary Strings are freed here):
//
//     tex := gd.load("res://icon.png")
load :: proc "contextless" (path: cstring) -> Resource {
	p := new_string_cstring(path)
	defer free_string(p)
	hint := new_string_cstring("")
	defer free_string(hint)
	return resource_loader_load(singleton_resource_loader(), p, hint, .Cache_Mode_Reuse)
}

// load_scene loads a PackedScene by path (Packed_Scene is an alias of Resource):
//
//     scene := gd.load_scene("res://enemy.tscn")
load_scene :: proc "contextless" (path: cstring) -> Packed_Scene {
	return cast(Packed_Scene)load(path)
}

// instantiate creates a fresh node tree from a PackedScene (Gen_Edit_State_Disabled —
// the normal runtime instancing state):
//
//     enemy := gd.instantiate(scene)
instantiate :: proc "contextless" (scene: Packed_Scene) -> Node {
	return packed_scene_instantiate(scene, Packed_Scene_Gen_Edit_State(0))
}

// spawn is the very common load + instantiate + add_child pattern in one call: loads the
// PackedScene at `path`, instances it, parents it under `parent`, and returns the instance:
//
//     enemy := gd.spawn(self.owner, "res://enemy.tscn")
spawn :: proc "contextless" (parent: Object, path: cstring) -> Node {
	inst := instantiate(load_scene(path))
	add_child(parent, inst)
	return inst
}
