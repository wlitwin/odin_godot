extends Node
var request := {}
var started := false
func _ready() -> void:
	if not OS.has_feature("web"):
		assert(not get_parent().begin(true,"native",0,0,0,16))
		assert(get_parent().probe("error")==9)
		print("REPLAY_BROWSER_STORE_NATIVE_OK")
		get_tree().quit()
	else:
		print("BROWSER_STORE_READY")
func _process(_delta: float) -> void:
	if not OS.has_feature("web"): return
	var pending = JavaScriptBridge.eval("globalThis.storeRequest?JSON.stringify(globalThis.storeRequest):''",true)
	if pending and not str(pending).is_empty():
		var parsed = JSON.parse_string(str(pending))
		if parsed.id!=request.get("id",0):
			request=parsed
			started=get_parent().begin(request.reading,request.key,request.expected,request.size,request.pattern,request.limit)
	if request.is_empty(): return
	var result := {"id":request.id,"started":started}
	for key in ["phase","error","revision","size"]: result[key]=get_parent().probe(key)
	result.hash=str(get_parent().probe("hash"))
	JavaScriptBridge.eval("globalThis.storeResult="+JSON.stringify(result)+";0",true)
