extends Node
var probe: Node
func _ready() -> void:
	var query = {}
	var text = str(JavaScriptBridge.eval("location.search || ''", true))
	for kv in text.trim_prefix("?").split("&", false):
		var parts = kv.split("=", true, 1)
		if parts.size() == 2: query[parts[0]] = parts[1].uri_decode()
	probe = Node.new()
	probe.set_script(load("res://scripts/game.odin" if query.get("mode", "wire") == "game" else "res://scripts/probe.odin"))
	add_child(probe)
	probe.call("start", query.get("role", "host"), query.get("url", ""), query.get("room", ""))

func _process(_delta: float) -> void:
	if probe == null or not probe.has_method("restart"): return
	var command = JavaScriptBridge.eval("globalThis.replayCommand || ''", true)
	if command == "restart":
		JavaScriptBridge.eval("globalThis.replayCommand = ''", true)
		probe.call("restart")
