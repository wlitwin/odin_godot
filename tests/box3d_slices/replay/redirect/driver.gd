extends SceneTree
var node
var frames := 0
var redirected := false
var started := false
var authority := false
func _initialize():
    authority = OS.get_environment("B3_ROLE") == "host"
    call_deferred("boot")
func boot():
    node = load("res://slice.tscn").instantiate()
    root.add_child(node)
func _process(_dt):
    frames += 1
    if frames == 100 and authority:
        var status = node.probe_archive()
        print("REDIRECT_ARCHIVE_STATUS ",status)
        if status != 0: quit(1)
    if frames == 120 and not authority:
        var status = node.probe_redirect()
        print("REDIRECT_BEGIN_STATUS ",status)
        if status != 0: quit(1)
        redirected = status == 0
    if redirected and frames > 180 and node.probe_running() == 1:
        var status = node.probe_close()
        print("REDIRECT_CLOSE_STATUS ",status)
        quit(0 if status == 0 else 1)
    if frames > 600: quit(1)
    return false
