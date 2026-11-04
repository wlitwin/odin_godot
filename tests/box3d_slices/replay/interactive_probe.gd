extends SceneTree
# Input-only probe: no Game/native/Timeline mutation or controller truth.
var frames := 0
var role := "host"
var baseline := Vector3.ZERO
var moved := false
var mode := "opposed"
func _initialize():
    role = OS.get_environment("B3_ROLE")
    mode = OS.get_environment("B3_PROBE_MOTION")
    if mode == "": mode = "opposed"
    call_deferred("boot")
func boot():
    var scene = load("res://slice.tscn").instantiate()
    root.add_child(scene)
func motion_key():
    if mode == "outward_host": return KEY_A if role == "host" else 0
    if mode == "outward_client": return KEY_D if role == "client" else 0
    return KEY_D if role == "host" else KEY_A
func key(code: int, pressed: bool):
    var event := InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = pressed
    Input.parse_input_event(event)
func _process(_dt):
    frames += 1
    var proxies = get_nodes_in_group("box3d_proxy")
    if frames == 60 and proxies.size() == 33:
        baseline = root.get_child(0).get_node("Body0" if role == "host" else "Body1").position
        print("REPLAY_INTERACTIVE_BASELINE ",role," ",baseline)
        if motion_key() != 0: key(motion_key(), true)
    if frames == 120:
        if motion_key() != 0: key(motion_key(), false)
        if proxies.size() == 33:
            var current = root.get_child(0).get_node("Body0" if role == "host" else "Body1").position
            moved = current.distance_to(baseline) > 0.01
            print("REPLAY_INTERACTIVE_CURRENT ",role," ",current)
    for item in [[140, KEY_SPACE], [160, KEY_M], [180, KEY_J], [200, KEY_K], [220, KEY_Q], [240, KEY_BACKSPACE]]:
        if frames == item[0]: key(item[1], true)
        if frames == item[0] + 1: key(item[1], false)
    if frames == 260:
        var path := OS.get_environment("B3_SCREENSHOT")
        if path != "":
            root.get_texture().get_image().save_png(path)
        print("REPLAY_INTERACTIVE_PROBE ", role, " moved=", moved, " proxies=", proxies.size(), " input_only=true")
    if frames == 300: key(KEY_ESCAPE, true)
    if frames > 360: quit(1)
    return false
