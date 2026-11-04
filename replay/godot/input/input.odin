package replay_godot_input

import gd "godot:godot"

// InputMap retains the binding event; release the constructor's reference after
// registering it. These helpers avoid leaving input resources alive at shutdown.
bind_key :: proc(action: cstring, key: gd.Key) {
    gd.action_add_key(action, i64(key))
}

bind_mouse :: proc(action: cstring, button: gd.Mouse_Button) {
    gd.action_add_mouse_button(action, i64(button))
}
