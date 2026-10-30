extends Node
var game:Node
func _ready():
 if not OS.has_feature("web"):set_process(false);return
 game=get_parent()
func _process(_dt:float):
 var command:String=str(JavaScriptBridge.eval("globalThis.moderationCommand||''",true))
 if not command.is_empty():
  JavaScriptBridge.eval("globalThis.moderationCommand='';0",true)
  match command:
   "remove":game.kick(2)
   "guest_remove":game.kick(1)
   "handoff":game.moderation_handoff()
   "walk":game.walk_to(300,180)
   "loot":game.loot(0)
 var state:={"ready":bool(game.probe_ready()),"players":int(game.probe_players()),"removed":int(game.moderation_probe("removed")),"removal_phase":int(game.moderation_probe("phase")),"epoch":int(game.moderation_probe("epoch")),"owner":int(game.moderation_probe("owner")),"nominee":int(game.moderation_probe("nominee")),"prepared":int(game.moderation_probe("prepared")),"enabled2":int(game.moderation_probe("member2_enabled")),"bans":int(game.moderation_probe("ban_count")),"near":bool(game.probe_near(300,180)),"bag":int(game.probe_bag()),"status":str(game.get_node("Lobby/Panel/Column/Status").text)}
 JavaScriptBridge.eval("globalThis.moderationState="+JSON.stringify(state)+";0",true)
