//gd:extends Node
//gd:class AuthoringTools
//gd:tool
package box3d_authoring_tools

import base "base:runtime"
import gd "godot:godot"
import ga "godot:box3d/godot/authoring"

// Install this source as res://modules/box3d_authoring_tools/tools.odin and use
// the ordinary project module build. It owns no world, scene, node or bake cache.
AuthoringTools :: struct {
    owner: gd.Node,
}

// Identify the source actually compiled into this loaded module, not merely a
// binary on disk. The editor can then refuse stale code after a source update.
@(gd_method = "owned_return")
authoring_tools_source_hash :: proc(self: ^AuthoringTools) -> gd.String {
    source := gd.new_string_odin(#load("tools.odin"))
    defer gd.free_string(source)
    return gd.string_sha256_text(&source)
}

@(gd_method = "owned_return")
authoring_tools_inspect_definition_json :: proc(self: ^AuthoringTools, definition_json: gd.String) -> gd.String {
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)
    return ga.editor_inspect_definition(definition_json)
}

@(gd_method = "owned_return")
authoring_tools_preview_shapes_json :: proc(self: ^AuthoringTools, request_json: gd.String) -> gd.String {
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)
    return ga.editor_preview_shapes(request_json)
}

@(gd_method = "owned_return")
authoring_tools_validate_definition_json :: proc(self: ^AuthoringTools, definition_json: gd.String) -> gd.String {
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)
    return ga.editor_inspect_definition(definition_json, false)
}

@(gd_method = "owned_return")
authoring_tools_bake_definition_json :: proc(
    self: ^AuthoringTools,
    definition_json, source_uri, source_revision: gd.String,
) -> gd.String {
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)
    return ga.editor_bake_definition(definition_json, source_uri, source_revision)
}

@(gd_method = "owned_return")
authoring_tools_inspect_artifact_base64 :: proc(self: ^AuthoringTools, artifact_base64: gd.String) -> gd.String {
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)
    return ga.editor_inspect_artifact(artifact_base64)
}
