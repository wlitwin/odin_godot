extends SceneTree
var game:Node
var folder:=""
var role:=""
var command:=0
func _initialize():
 folder=OS.get_environment("RSL_STATUS_DIR");role=OS.get_environment("RSL_STATUS_ROLE")
 root.size=Vector2i(640,360);game=load("res://slopball.tscn").instantiate();root.add_child(game)
func p(key:String)->int:return int(game.party_probe(key))
func b(key:String)->int:return int(game.backup_probe(key))
func _process(_dt:float)->bool:
 var path:=folder+"/"+role+"-request.json"
 var request=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
 if request is Dictionary and int(request.id)!=command:
  command=int(request.id)
  match str(request.kind):
   "press":game.get_node(str(request.value)).pressed.emit()
   "name":game.get_node("UI/Lobby/Column/Name/Value").text=str(request.value)
   "invite":game.get_node("UI/Lobby/Column/Party/Code").text=str(request.value)
   "watch":game.get_node("UI/Lobby/Column/Party/Choices/Watch").button_pressed=bool(request.value)
   "allow":game.allow_backup(bool(request.value))
   "handoff":game.handoff()
   "quit":game.queue_free();game=null;quit(0);return true
 var state={"command":command,"ready":int(game.ui_probe("state_ready",1)),"profile":p("profile_ready"),"recent":p("recent"),"failed":p("failed"),"invite":game.get_node("UI/Lobby/Column/Party/Code").text,"invited":p("invited"),"epoch":int(game.probe("epoch")),"authority":int(game.probe("authority")),"phase":b("phase"),"age":b("age"),"limit":b("limit"),"tick":b("tick"),"proof_epoch":b("epoch"),"pending":b("pending"),"raw_prepared":b("raw_prepared"),"notice":game.get_node("UI/Recovery").text,"seat":int(game.ui_probe("seat",1))}
 var file:=FileAccess.open(folder+"/"+role+"-status.json.tmp",FileAccess.WRITE);file.store_string(JSON.stringify(state));file.close();file=null
 assert(DirAccess.rename_absolute(folder+"/"+role+"-status.json.tmp",folder+"/"+role+"-status.json")==OK)
 return false
