package script_runtime

import bg "godot:box3d/godot"

// Optional pure metadata/host handoff. Importing the protocol registers no
// native profile and adds no foreign native dependency to ordinary scripts.
@(export)
odin_scripts_box3d_profile :: proc "c" () -> u32 {
    return bg.module_profile()
}

@(export)
odin_scripts_box3d_protocol :: proc "c" () -> u64 {
    return bg.protocol_fingerprint()
}

@(export)
odin_scripts_box3d_contract :: proc "c" (out: ^bg.Domain_Contract) -> bg.Status {
    return bg.module_contract(out)
}

@(export)
odin_scripts_box3d_install :: proc "c" (service: ^bg.Service) -> bg.Status {
    return bg.module_install(service)
}

box3d_host :: proc "contextless" () -> bg.Service {
    return bg.service_get()
}
