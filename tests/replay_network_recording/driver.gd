extends "res://combat_test.gd"
var world_tick:=0
var export_pending:=false
var export_done:=false
var record_button:Button
var observations:=[]
func _initialize():
 super._initialize();participants=["host","client"];timeout_ms=30000
 record_button=game.find_child("ReplayRecordingExport",true,false)
func note(label:String):
 observations.append({"name":label,"head":p("head"),"prediction":p("predhead"),"shots1":p("shots",1),"shots2":p("shots",2),"casts1":p("casts",1),"casts2":p("casts",2),"mobs":p("mobs"),"effects":p("shot_effects"),"resyncs":p("resyncs")})
func click_recording():
 game.on_menu();await process_frame;await process_frame
 var scroll:ScrollContainer=game.get_node("UI/Menu/Scroll");scroll.ensure_control_visible(record_button);await process_frame
 var point:=record_button.get_global_rect().get_center()
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
  Input.parse_input_event(event)
  if DisplayServer.get_name()=="headless":root.push_input(event,true)
 export_pending=true
func _process(_dt:float)->bool:
 if closing:return false
 if Time.get_ticks_msec()-started>timeout_ms:return fail("recording timeout")
 if not p("ready"):return false
 if record_button==null:record_button=game.find_child("ReplayRecordingExport",true,false)
 if record_button==null:return fail("missing recording control")
 match phase:
  "join":
   seat=p("seat");game.dev_loadout(0,0 if seat==1 else 5);game.dev_abilities(1,5);phase="loadout"
  "loadout":
   if p("iron",seat)==(0 if seat==1 else 5) and p("ability0",seat)==1 and p("ability1",seat)==5:game.on_ready();phase="ready"
  "ready":
   if p("players")==2 and p("marked_ready",1) and p("marked_ready",2):
    if mode=="host":game.on_start()
    phase="world"
  "world":
   if p("in_yard",1) and p("in_yard",2):
    world_tick=p("head");note("yard")
    game.dev_aim(1,0,true)
    if not game.dev_cast(0,800,1040,true) or not game.dev_cast(1,1,0,false):return fail("cast submission")
    if game.dev_grant_scrap(1,100 if mode=="host" else 999)<=0:return fail("development submission")
    phase="combat"
  "combat":
   if p("head")-world_tick>=70 and p("shots",1)>0 and p("shots",2)>0 and p("casts",1)>=2 and p("casts",2)>=2:
    if p("dev_result")!=(1 if mode=="host" else -1):return false
    if mode=="client" and p("dev_reason")!=2:return fail("admission rejection reason")
    note("before_export");phase="export";click_recording()
  "export":
   if export_pending and FileAccess.file_exists(OS.get_environment("RSY_RECORDING_PATH")):
    note("exported");write("recording-"+mode,{"pass":true,"observations":observations,"button":record_button.text})
    game.on_resume_menu();game.dev_aim(1,0,false);acted=Time.get_ticks_msec();phase="continue"
  "continue":
   if Time.get_ticks_msec()-acted>500 and p("head")>int(observations[-1].head):
    if p("resyncs")!=0:return fail("export caused resync")
    note("continued");write("recording-"+mode,{"pass":true,"observations":observations,"button":record_button.text})
    phase="wait"
  "wait":
   var other=read("recording-"+("client" if mode=="host" else "host"))
   if not other.is_empty() and other.observations[-1].name=="continued":
    print("RSY_NETWORK_RECORDING_OK role=",mode," ticks=",p("head")-world_tick," effects=",p("shot_effects"))
    finish_game(0)
 return false
