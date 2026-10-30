extends "res://combat_test.gd"

var pending_seen := false
var fixtures: Dictionary = {}
var first_x := 0
var first_y := 0

func _initialize() -> void:
    super._initialize()
    mode = OS.get_environment("RSY_NAME")
    participants = ["host", "client", "observer", "after"]
    fixtures = read("fixtures")
    timeout_ms = 90000

func loaded(player: int, fixture: String) -> bool:
    var expected: Dictionary = fixtures[fixture]
    return game.spray_id(player) == str(expected.hash) and p("spray_bytes", player) == int(expected.bytes) and p("spray_cached", player) and p("spray_visible", player)

func _process(dt: float) -> bool:
    if phase == "hash" or phase == "finish": return super._process(dt)
    if Time.get_ticks_msec() - started > timeout_ms: return fail("spray timeout")
    if not p("ready"): return false
    pending_seen = pending_seen or bool(p("spray_pending", 1)) or bool(p("spray_pending", 2))
    match phase:
        "join":
            seat = p("seat")
            game.dev_drive(0, 0, false)
            if mode == "after": phase = "updated"
            elif seat == 0: phase = "original"
            else:
                game.on_ready(); phase = "ready"
        "ready":
            if p("players") == 2 and p("marked_ready", 1) and p("marked_ready", 2):
                if mode == "host": game.on_start()
                phase = "world"
        "world":
            if p("in_yard", seat) and p("spray_bytes", seat) > 0:
                first_x = p("x", seat); first_y = p("y", seat)
                if not game.stamp(): return fail("queue first stamp")
                phase = "stamped"
        "stamped":
            if p("spray_stamp", seat) == 1:
                if p("spray_x", seat) != first_x or p("spray_y", seat) != first_y: return fail("stamp origin")
                game.dev_drive(-1, 0, false); phase = "move"
        "move":
            if p("x", seat) <= first_x - 65:
                game.dev_drive(0, 0, false); phase = "original"
        "original":
            if loaded(1, "host") and loaded(2, "client"):
                if mode == "host": write("initial-ready", {"ready": true})
                if mode == "observer": write("late-before", {"ready": true})
                phase = "replace"
        "replace":
            if not read("late-before").is_empty():
                if mode == "host": game.on_spray_file(directory + "/replacement.png")
                phase = "updated"
        "updated":
            if loaded(1, "replacement") and loaded(2, "client"):
                if p("spray_stamp", 1) != 1 or p("spray_x", 1) != 500 or p("spray_y", 1) != 1040: return fail("replacement moved the existing decal")
                for player in [1, 2]:
                    var decal: Sprite2D = game.get_node("World/Spray" + str(player))
                    if decal.texture == null or decal.texture.get_width() != 128 or decal.texture.get_height() != 128: return fail("decoded texture dimensions")
                write("updated-" + mode, {"ready": true})
                phase = "restamp"
        "restamp":
            for participant in participants:
                if read("updated-" + participant).is_empty(): return false
            if mode == "host":
                if not game.stamp(): return fail("queue replacement stamp")
                game.on_spray_file(directory + "/bad.png")
            phase = "finished_stamps"
        "finished_stamps":
            if p("spray_stamp", 1) == 2 and loaded(1, "replacement") and loaded(2, "client"):
                if p("spray_x", 1) >= 500 or p("spray_stamp", 2) != 1: return fail("decal movement/count")
                if not captured and OS.get_environment("RSY_SCREENSHOT") != "":
                    captured = true; capture_scene(OS.get_environment("RSY_SCREENSHOT"))
                print("RSY_SPRAY_RESULT role=", mode, " bytes1=", p("spray_bytes", 1), " bytes2=", p("spray_bytes", 2), " stamps1=", p("spray_stamp", 1), " stamps2=", p("spray_stamp", 2), " pending=", int(pending_seen), " installs=", p("asset_installs"), " tx=", p("asset_tx"), " rx=", p("asset_rx"))
                write("stopped-" + mode, {"ready": true}); phase = "hash"
    return false
