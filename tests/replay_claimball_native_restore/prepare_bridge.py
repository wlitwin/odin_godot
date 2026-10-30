from pathlib import Path
import sys
root=Path(__file__).resolve().parents[2]
s=(root/'tests/replay_claimball_online/bridge.gd').read_text().replace('extends Node','extends SceneTree',1)
start=s.index('func _ready():');end=s.index('func p(',start)
s=s[:start]+'''var directory:=""
var role:=""
func _initialize():
 directory=OS.get_environment("RCB_NATIVE_RESTORE_DIR");role=OS.get_environment("RCB_NATIVE_RESTORE_ROLE")
 root.size=Vector2i(640,360)
 game=load("res://claimball.tscn").instantiate();root.add_child(game)
'''+s[end:]
s=s.replace('func _process(_dt:float):\n var request=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(globalThis.claimballCommand||null)",true)))', '''func _process(_dt:float)->bool:
 var request_path:=directory+"/"+role+"-request.json"
 var request=JSON.parse_string(FileAccess.get_file_as_string(request_path)) if FileAccess.file_exists(request_path) else null''')
s=s.replace(' JavaScriptBridge.eval("globalThis.claimballStatus="+JSON.stringify(state),true)', ''' var file:=FileAccess.open(directory+"/"+role+"-status.json.tmp",FileAccess.WRITE);file.store_string(JSON.stringify(state));file.close();file=null
 assert(DirAccess.rename_absolute(directory+"/"+role+"-status.json.tmp",directory+"/"+role+"-status.json")==OK)
 return false''')
Path(sys.argv[1]).write_text(s)
