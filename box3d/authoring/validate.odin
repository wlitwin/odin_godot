package box3d_authoring

// Check the immutable bake before native construction or presentation binding.
// Callers cannot turn edited baked data into a valid scene by keeping its hash.
baked_validate :: proc(scene: ^Baked_Scene) -> Diagnostic {
    if scene == nil || !schema_supported(scene.data.schema_version) {
        return fail(.Schema, "scene.schema")
    }
    if problem := validate_ids(scene.data); problem.error != .None { return problem }
    hash, hashed := scene_hash(scene.data)
    if !hashed { return fail(.Allocation, "scene.identity") }
    if hash != scene.content_hash || content_id64(scene) == 0 {
        return fail(.Corrupt, "scene.content_hash")
    }
    return {}
}
