package core

import "godot:gdext"
import "godot:godot"

// GDExtension entry point. Referenced as `entry_symbol` in odin_godot.gdextension.
@(export)
odin_godot_init :: proc "c" (
    get_proc_address: gdext.ExtensionInterfaceGetProcAddress,
    library: gdext.ExtensionClassLibraryPtr,
    initialization: ^gdext.Initialization,
) -> bool {
    gdext.init(library, get_proc_address)
    godot.init()

    // WEB: run the Odin `@(init)` chain ourselves (a SIDE_MODULE has no CRT/entry
    // point to do it). This fires every linked-in script's `@(init) rt.register(...)`
    // self-registration. No-op on native (the scripts dll boots itself). See web.odin.
    web_startup()

    // Saved so we can forward the GDExtension interface to the scripts dll's boot
    // (it has its own copy of the gdext/godot globals — see core/scripts.odin).
    saved_get_proc_address = get_proc_address

    initialization.initialize = initialize_odin_module
    initialization.deinitialize = uninitialize_odin_module
    initialization.user_data = nil
    initialization.minimum_initialization_level = .Scene

    return true
}

initialize_odin_module :: proc "c" (user_data: rawptr, level: gdext.InitializationLevel) {
    context = gdext.godot_context()

    // `.Editor`-only: the export pipeline. Reached in the editor (incl. headless
    // `--export-*`), never in an exported game. See core/export_plugin.odin. Excluded
    // from WEB (there is no editor/export pipeline in the browser).
    when !WEB {
        if level == .Editor {
            odin_export_register()
            return
        }
    }

    if level != .Scene {
        return
    }

    // Fatal-signal crash reporter (core/crash.odin; no-op stub on Windows). Installed
    // at .Scene init, which runs in BOTH the editor and the game — the install gates
    // itself to the GAME (engine_is_editor_hint false), so the editor's own crash
    // behavior is never altered. Godot's crash handler went in during main setup,
    // before this, so we chain to it. Not applicable on web (no signals in wasm).
    when !WEB {
        crash_reporter_install()
    }

    // Register the GDExtension classes first (OdinScript is constructed by the
    // language + loader), then register the language with the engine and install
    // the resource-format loader.
    odin_script_register()
    odin_language_register()
    odin_loader_register()
    odin_saver_register()

    // Load the compiled scripts dll, boot its gdext/godot globals, and index the
    // classes it self-registered. After this, OdinScript instances can dispatch.
    odin_scripts_load()
}

uninitialize_odin_module :: proc "c" (user_data: rawptr, level: gdext.InitializationLevel) {
    context = gdext.godot_context()
    when !WEB {
        if level == .Editor {
            odin_export_unregister()
            return
        }
    }
    if level != .Scene {
        return
    }
    odin_loader_unregister()
    odin_language_unregister()
}
