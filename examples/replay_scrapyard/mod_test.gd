extends "res://combat_test.gd"

var buff_seen := false
var resume_mode := false

func _initialize() -> void:
    super._initialize()
    resume_mode = OS.get_environment("RSY_MOD_PHASE") == "resume"
    timeout_ms = 70000

func catalog_valid() -> bool:
    return game.gun_name(0) == "junkcannon" and p("gun_damage", 0) == 9 and p("catalog_mob_hp", 1) == 30 and game.gun_name(9) == "spare" and p("gun_count") == 10 and p("ability_count") == 12

func _process(dt: float) -> bool:
    if phase == "hash" or phase == "finish": return super._process(dt)
    if Time.get_ticks_msec() - started > timeout_ms: return fail("mod timeout")
    if not p("ready"): return false
    if not catalog_valid(): return fail("authoritative catalog")
    if p("fx_mask", 1) & (1 << 12) or p("fx_mask", 2) & (1 << 12): buff_seen = true
    match phase:
        "join":
            seat = p("seat")
            if resume_mode:
                var saved := read("mod-saved")
                if p("epoch") != 2 or p("restored_hash") != int(saved.hash) or game.catalog_hash() != int(saved.catalog): return fail("saved mod catalog")
                if p("iron", 1) != 9 or p("ability0", 1) != 11: return fail("saved sparse choices")
                print("RSY_MOD_RESUME_OK catalog=", game.catalog_hash(), " iron=", p("iron", 1), " ability=", p("ability0", 1))
                quit(0); return true
            if seat == 0:
                write("observer-catalog", {"catalog": str(game.catalog_hash())}); phase = "fight"
            else:
                game.dev_loadout(seat, 6); game.dev_abilities(6, 6); phase = "cycle"
        "cycle":
            if p("iron", seat) == 6 and p("ability0", seat) == 6:
                game.on_iron(); game.on_ability0(); phase = "loadout"
        "loadout":
            if p("iron", seat) == 9 and p("ability0", seat) == 11:
                game.on_ready(); phase = "ready"
        "ready":
            if p("players") == 2 and p("marked_ready", 1) and p("marked_ready", 2):
                if mode == "host": game.on_start()
                phase = "world"
        "world":
            if p("in_yard", 1) and p("in_yard", 2):
                if mode == "host": write("mod-ready", {"ready": true})
                if not read("observer-catalog").is_empty():
                    if not game.dev_cast(0, 0.0, 0.0, false): return fail("sparse ability")
                    game.dev_combat(true); phase = "fight"
        "fight":
            if p("hp", 1) == 0 or p("hp", 2) == 0: return fail("mod combat killed crew")
            if p("kills", 1) + p("kills", 2) == 4 and p("mobs") == 0 and p("drops") == 0:
                if seat > 0: game.dev_combat(false)
                if not buff_seen or p("casts", 1) != 1 or p("casts", 2) != 1: return fail("sparse buff did not apply")
                if p("damage", 1) + p("damage", 2) != 39 or p("scrap", 1) + p("scrap", 2) != 12: return fail("mod combat totals")
                if mode == "host":
                    if not game.save_run(): return fail("save mod run")
                    write("mod-saved", {"hash": str(p("saved_hash")), "catalog": str(game.catalog_hash())})
                print("RSY_MOD_RESULT role=", mode, " catalog=", game.catalog_hash(), " damage=39 scrap=12 guns=10 abilities=12 buff=1")
                write("stopped-" + mode, {"ready": true}); phase = "hash"
    return false
