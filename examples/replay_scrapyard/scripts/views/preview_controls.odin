package scrap_views

import gd "godot:godot"

// The UI is ordinary Godot scene tooling. Typed preview values/rules stay in Odin.
preview_controls :: proc(parent: gd.Node) {
    path := gd.new_string_cstring("res://addons/replay_authoring/preview_controls.gd")
    exists := gd.file_access_file_exists(path)
    gd.free_string(path)

    if !exists {
        return
    }

    script := gd.load("res://addons/replay_authoring/preview_controls.gd")

    if script == nil {
        return
    }

    defer gd.release_ref(script)
    overlay := gd.new_canvas_layer()
    object := cast(gd.Object)script
    variant := gd.variant_from_object(&object)
    gd.object_set_script(overlay, variant)
    gd.variant_destroy(&variant)
    gd.add_child_deferred(parent, overlay)
}
