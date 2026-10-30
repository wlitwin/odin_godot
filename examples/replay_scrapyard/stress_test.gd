extends "res://combat_test.gd"

var peak := 0
var measurement_started := 0
var finished_at := 0
var next_cast := 0
var statuses_seen := 0
var sampled_statuses := 0

func _initialize() -> void:
    super._initialize()
    participants = ["host", "client"]
    timeout_ms = 100000

func _process(dt: float) -> bool:
    if phase == "hash" or phase == "finish": return super._process(dt)
    var now := Time.get_ticks_msec()
    if now - started > timeout_ms: return fail("stress timeout")
    if not p("ready"): return false
    peak = maxi(peak, p("mobs"))
    statuses_seen |= game.stress_statuses()
    if measurement_started > 0 and phase == "swarm": sampled_statuses |= game.stress_statuses()
    match phase:
        "join":
            seat = p("seat")
            game.on_ready(); phase = "ready"
        "ready":
            if p("players") == 2 and p("marked_ready", 1) and p("marked_ready", 2):
                if mode == "host": game.on_start()
                phase = "world"
        "world":
            if p("in_yard", 1) and p("in_yard", 2):
                game.dev_stress_fire(); phase = "swarm"
        "swarm", "linger":
            game.dev_stress_fire()
            if now >= next_cast:
                var slot := int(now / 400) % 2
                if p("cd0" if slot == 0 else "cd1", seat) == 0: game.dev_stress_cast(slot)
                next_cast = now + 100
            if measurement_started == 0 and peak >= 30:
                game.bench_start(); measurement_started = now
                write("measuring-" + mode, {"tick": p("head"), "unix": Time.get_unix_time_from_system()})
            if phase == "swarm" and measurement_started > 0 and now - measurement_started >= 3000:
                if not game.bench_finish(): return fail("benchmark capture")
                write("sampled-" + mode, {"tick": p("head"), "unix": Time.get_unix_time_from_system()})
                finished_at = now; phase = "linger"
            if phase == "linger" and now - finished_at >= 4000 and (statuses_seen & 6) == 6:
                game.dev_combat(false)
                print("RSY_FEEDBACK_STRESS role=", mode, " spawned=", game.feedback_probe("spawned"), " dropped=", game.feedback_probe("dropped"), " canceled=", game.feedback_probe("canceled"), " duplicates=", game.feedback_probe("duplicates"))
                print("RSY_STRESS_RESULT role=", mode, " peak=", peak, " reactions=", p("reactions"), " statuses=", p("status_applied"), " shots=", p("shots", 1) + p("shots", 2), " run=", p("run"), " status_mask=", statuses_seen, " sampled_status_mask=", sampled_statuses)
                write("stopped-" + mode, {"ready": true}); phase = "hash"
    return false
