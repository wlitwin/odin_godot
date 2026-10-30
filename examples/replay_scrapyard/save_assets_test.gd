extends "res://combat_test.gd"

var resumed := false
var expected: Dictionary = {}

func _initialize() -> void:
    super._initialize()
    resumed = OS.get_environment("RSY_SAVE_PHASE") == "resume"
    expected = read("expected")
    timeout_ms = 60000
    if resumed: participants = ["host", "observer"]

func has_saved_image() -> bool:
    return p("spray_cached", 2) and p("spray_visible", 2) and p("spray_stamp", 2) == 1 and game.spray_id(2) == str(expected.hash)

func _process(dt: float) -> bool:
    if phase == "hash" or phase == "finish": return super._process(dt)
    if Time.get_ticks_msec() - started > timeout_ms: return fail("asset save timeout")
    if not p("ready"): return false
    match phase:
        "join":
            seat = p("seat")
            game.dev_drive(0, 0, false)
            if resumed:
                if mode == "host":
                    var saved := read("saved")
                    if p("restored_tick") != int(saved.tick) or p("restored_hash") != int(saved.hash) or p("epoch") != 2: return fail("bundle checkpoint differs")
                    phase = "offline"
                else: phase = "image"
            elif seat == 0: phase = "active"
            else:
                game.dev_abilities(5 if seat == 1 else 4, 1 if seat == 1 else 6); phase = "loadout"
        "loadout":
            if p("ability0", seat) == (5 if seat == 1 else 4) and p("ability1", seat) == (1 if seat == 1 else 6):
                game.on_ready(); phase = "ready"
        "ready":
            if p("players") == 2 and p("marked_ready", 1) and p("marked_ready", 2):
                if seat == 1: game.on_start()
                phase = "world"
        "world":
            if p("in_yard", 1) and p("in_yard", 2):
                if seat == 2:
                    if p("spray_bytes", 2) == 0: return false
                    if not game.stamp() or not game.dev_cast(0, 0.0, 0.0, false): return fail("client setup")
                phase = "assets"
        "assets":
            if has_saved_image():
                if seat == 1:
                    if not game.dev_cast(0, 500.0, 1040.0, true) or not game.dev_cast(1, 800.0, 1040.0, true): return fail("combat setup")
                phase = "active"
        "active":
            if has_saved_image() and p("casts", 1) == 2 and p("casts", 2) == 1 and p("lobs") == 1 and p("zones") == 1:
                write("active-" + mode, {"ready": true})
                if mode == "host" and not read("active-client").is_empty() and not read("active-observer").is_empty():
                    if not game.save_run(): return fail("bundle write")
                    write("saved", {"tick": str(p("saved_tick")), "hash": str(p("saved_hash"))})
                    game.set_process(false)
                    print("RSY_ASSET_SAVE_READY tick=", p("saved_tick"), " image_bytes=", p("spray_bytes", 2))
                    phase = "kill"
        "offline":
            if has_saved_image() and p("players") == 1:
                if p("spray_x", 2) != 600 or p("spray_y", 2) != 1040: return fail("offline decal position")
                print("RSY_ASSET_OFFLINE_RESTORED cached=1 visible=1 players=1")
                write("restored-offline", {"ready": true}); phase = "image"
        "image":
            if has_saved_image():
                write("image-" + mode, {"ready": true}); phase = "continue"
        "continue":
            if p("landed") == 1 and not read("image-host").is_empty() and not read("image-observer").is_empty():
                if mode == "host": game.dev_aim(1.0, 0.0, true)
                phase = "finished"
        "finished":
            if p("shots", 1) > 0 and p("damage", 1) > 0:
                if mode == "host": game.dev_aim(1.0, 0.0, false)
                print("RSY_ASSET_SAVE_RESULT role=", mode, " epoch=", p("epoch"), " players=", p("players"), " cached=", p("spray_cached", 2), " visible=", p("spray_visible", 2), " landed=", p("landed"))
                write("stopped-" + mode, {"ready": true}); phase = "hash"
    return false
