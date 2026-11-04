package presentation_import

import p "godot:box3d/presentation"

// Compile this package to freestanding WASM to prove the optional value contract
// has no Godot, Native, platform transport or framework linkage requirement.
@(export)
presentation_import_probe :: proc "contextless" () -> u32 {
    bindings := [1]p.Binding{{id = {1, 2}, body = 3, asset = 1, alive = true}}
    samples := [1]p.Body_Sample{{body = 3, pose = {{}, {0, 0, 0, 1}}}}
    frame, error := p.frame_make(1, 0, 0, .Observed, bindings[:], samples[:])

    if error != .None {
        return 1
    }

    view: p.View
    changes: [70]p.Change
    _, error = p.present(&view, nil, &frame, .5, changes[:])
    return u32(error)
}
