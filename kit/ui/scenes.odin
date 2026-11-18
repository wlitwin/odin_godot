package kit_ui

import gd "godot:godot"
import "godot:gdext"
import binding "bindings"
import "core:fmt"

// The report owns its message bytes. No borrowed scene/node survives failure.
Binding_Report :: binding.Report
binding_report_text :: binding.text

Prepared_Scenes :: struct {
    widgets: [binding.Kind]binding.Result,
    ready:   bool,
}

// Preflight every authored widget before adding nodes, connecting signals or
// initializing gameplay. Nil scenes request the stock controls.
prepare_scenes :: proc(lobby, chat, score: gd.Packed_Scene) -> (prepared: Prepared_Scenes, report: Binding_Report) {
    for scene, kind in ([binding.Kind]gd.Packed_Scene{.Lobby = lobby, .Chat = chat, .Scoreboard = score}) {
        if scene == nil {
            continue
        }

        node := gd.instantiate(scene)
        prepared.widgets[kind] = binding.resolve(node, kind)
        result := &prepared.widgets[kind]

        if result.report.count > 0 {
            path := gd.resource_get_path(cast(gd.Resource)scene)
            binding.problem(&report, fmt.tprintf("%s\n%s", gd.gd_string_to_odin(path), binding.text(&result.report)))
            gd.free_string(path)
        }
    }

    if report.count > 0 {
        prepared_destroy(&prepared)
        return
    }

    prepared.ready = true
    return
}

prepared_destroy :: proc(prepared: ^Prepared_Scenes) {
    for &widget in prepared.widgets {
        if widget.root != nil {
            gdext.object_destroy(cast(gdext.ObjectPtr)widget.root)
        }
    }

    prepared^ = {}
}

report_binding_error :: proc(report: ^Binding_Report) {
    message := gd.new_string_odin(binding.text(report))
    defer gd.free_string(message)
    value := gd.variant_from_string(&message)
    defer gd.variant_destroy(&value)
    gd.gd_push_error(value)
}

// Consumes a successful preflight. The parent owns the attached nodes afterward.
@(require_results)
attach_scenes :: proc(
    prepared: ^Prepared_Scenes,
    parent: gd.Node,
    title: string,
) -> (
    lobby: Lobby,
    chat: Chat,
    score: Score,
    ok: bool,
) {
    if !prepared.ready || parent == nil {
        return
    }

    if prepared.widgets[.Lobby].root != nil {
        lobby = lobby_bind(parent, prepared.widgets[.Lobby], title)
    } else {
        lobby = lobby_make(parent, title)
    }

    if prepared.widgets[.Chat].root != nil {
        chat = chat_bind(parent, prepared.widgets[.Chat])
    } else {
        chat = chat_make(parent)
    }

    if prepared.widgets[.Scoreboard].root != nil {
        score = score_bind(parent, prepared.widgets[.Scoreboard])
    } else {
        score = score_make(parent)
    }

    prepared^ = {}
    ok = true
    return
}
