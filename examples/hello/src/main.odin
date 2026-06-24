package hello

import "godot:gdext"
import "godot:godot"

// GDExtension entry point. Referenced as `entry_symbol` in example.gdextension.
@(export)
odin_hello_init :: proc "c" (
    get_proc_address: gdext.ExtensionInterfaceGetProcAddress,
    library: gdext.ExtensionClassLibraryPtr,
    initialization: ^gdext.Initialization,
) -> bool {
    // gdext procs MUST be initialized before using the binding.
    gdext.init(library, get_proc_address)

    // MUST be called before using any core classes, singletons, or utility functions.
    godot.init()

    initialization.initialize = initialize_hello_module
    initialization.deinitialize = uninitialize_hello_module
    initialization.user_data = nil
    initialization.minimum_initialization_level = .Scene

    return true
}

initialize_hello_module :: proc "c" (user_data: rawptr, level: gdext.InitializationLevel) {
    context = gdext.godot_context()

    if level != .Scene {
        return
    }

    hello_class_register()
}

uninitialize_hello_module :: proc "c" (user_data: rawptr, level: gdext.InitializationLevel) {
    context = gdext.godot_context()

    if level != .Scene {
        return
    }
}
