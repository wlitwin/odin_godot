extends SceneTree

func _initialize():
    call_deferred("run")

func run():
    var packed = load("res://presentation.tscn")
    if packed == null:
        quit(1)
        return
    var node = packed.instantiate()
    root.add_child(node)
    if not node.has_method("verify"):
        push_error("Odin presentation script did not load")
        node.free()
        quit(4)
        return
    var result = node.verify()
    var label: Label = node.get_node("Overlay")
    if result != 0 or not label.text.contains("Accepted frontier unknown") or not label.text.contains("Tracked bytes unavailable"):
        push_error("Presentation values failed: %s" % result)
        node.free()
        quit(2)
        return
    if node.get_node("Proxy0").visible or node.get_node("Proxy1").visible:
        push_error("Retired proxy still visible")
        node.free()
        quit(3)
        return
    node.free()
    print("BOX3D_PRESENTATION_VALUES_OK ordinary_nodes=2 solver_calls=0")
    quit(0)
