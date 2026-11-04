package ptrcall_abi
import "base:runtime"
import checks "checks"
import gd "godot:godot"
import ext "godot:gdext"

@(export, link_name = "odin_godot_init")
odin_godot_init :: proc "c" (
    get: ext.ExtensionInterfaceGetProcAddress,
    library: ext.ExtensionClassLibraryPtr,
    initialization: ^ext.Initialization,
) -> bool {
    initialization.minimum_initialization_level = .Scene
    initialization.initialize = initialize
    initialization.deinitialize = deinitialize
    ext.init(library, get)
    return true
}

deinitialize :: proc "c" (user: rawptr, level: ext.InitializationLevel) {}

initialize :: proc "c" (user: rawptr, level: ext.InitializationLevel) {
    if level != .Scene {
        return
    }

    context = runtime.default_context()
    gd.init()
    checks.run()
}
