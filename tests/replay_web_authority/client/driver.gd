extends Node
var probe: Node
var signal_mode := false
func _ready() -> void:
	signal_mode = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('mode') || ''", true)) == "signal"
	var node := Node.new()
	node.set_script(load("res://scripts/signal_probe.odin" if signal_mode else "res://scripts/probe.odin"))
	probe=node
	add_child(node)

func _process(_delta: float) -> void:
	if not signal_mode or probe == null: return
	var command = str(JavaScriptBridge.eval("globalThis.rzaCommand || ''",true))
	if command == "drop_signal":
		JavaScriptBridge.eval("globalThis.rzaCommand = ''",true)
		probe.call("drop_signal")
	elif command in ["hold_signal", "resume_signal"]:
		JavaScriptBridge.eval("globalThis.rzaCommand = ''",true)
		probe.call("hold_signal", command == "hold_signal")
	var stats := {"id":probe.call("stat",0,0),"resumes":probe.call("stat",1,0),"packets":probe.call("stat",2,0),"during_loss":probe.call("stat",3,0),"lost":probe.call("stat",5,0),"connections":[probe.call("stat",4,1),probe.call("stat",4,2),probe.call("stat",4,3)]}
	JavaScriptBridge.eval("globalThis.rzaStats = "+JSON.stringify(stats)+";0",true)
