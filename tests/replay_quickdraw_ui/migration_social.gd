extends "res://migration_test.gd"
var sent_before:=false
var sent_after:=false
func history()->String:return str(game.get_node("UI/Chat/Column/Lines").text)
func names_ready()->bool:
 var grid:=game.get_node("UI/Scoreboard/Column/Grid")
 for seat in [1,2,3]:
  if not str(grid.get_child(5+(seat-1)*5).text).begins_with("Member "+str(seat)):return false
 return true
func _process(dt:float)->bool:
 if Time.get_ticks_msec()-started>38000:return fail("social migration deadline")
 if p("epoch")==1 and p("steady") and game.ui_probe("chat_ready",1) and names_ready():
  if member==1 and not sent_before:game.on_chat("before handoff");sent_before=true
  if "Member 1: before handoff" in history() and not exists("chat_before_%d"%member):put("chat_before_%d"%member)
 if phase=="combat" and member==1:
  for seat in [1,2,3]:
   if not exists("chat_before_%d"%seat):return false
 if phase!="join" and game.get_node("UI/Lobby").visible:return fail("live duel replaced by staging during recovery")
 if p("epoch")==2 and p("steady") and game.ui_probe("chat_ready",1) and names_ready() and not sent_after:
  game.on_chat("epoch two from %d"%member);sent_after=true
 if phase in ["final","wait_clients"]:
  if not names_ready() or not "Member 1: before handoff" in history():return false
  var peers:=[1,2,3] if mode=="planned" else [2,3]
  for seat in peers:
   if not ("Member %d: epoch two from %d"%[seat,seat]) in history():return false
  if not exists("chat_after_%d"%member):
   put("chat_after_%d"%member,{"history":history(),"epoch":p("epoch"),"tick":p("head")})
 return super._process(dt)
