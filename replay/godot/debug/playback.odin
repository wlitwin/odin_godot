package replay_godot_debug

import storagegd "godot:replay/godot/storage"

import "core:fmt"
import gd "godot:godot"
import "godot:gdext"
import r "godot:replay"
import d "godot:replay/diagnostic"

Debug_Playback_Action :: enum {None,Enter,Leave,Branch}
Debug_Playback :: struct($S,$I,$E:typeid) {
 controls:Debug_Playback_Controls,player:d.Playback(S,I,E),
 owns_pause:bool,loads,rejections:u64,last_load:d.Playback_Load,
}
@(private)
Debug_Playback_Controls :: struct {
 layer:gd.Canvas_Layer,bar,dock,report_panel:gd.Panel_Container,
 status,range_label,report:gd.Label,slider:gd.H_Slider,
 buttons:[5]gd.Button,callbacks:[5]Debug_Playback_Callback,calls:[5]gd.Callable,
 pending,connected:[5]bool,count:int,details:bool,importer:storagegd.File_Import,
}
@(private)
Debug_Playback_Callback :: struct {owner:^Debug_Playback_Controls,index:int}

debug_playback_init :: proc(p:^Debug_Playback($S,$I,$E),parent:gd.Node)->bool {
 c:=&p.controls;if parent==nil || c.layer!=nil {return false}
 c.layer=gd.new_canvas_layer();gd.canvas_layer_set_layer(c.layer,1002);gd.add_child(parent,c.layer)
 c.bar=gd.new_panel_container();gd.add_child(c.layer,c.bar)
 bar:=gd.new_h_box_container();gd.add_child(c.bar,bar)
 c.status=gd.new_label()
 c.dock=gd.new_panel_container();gd.add_child(c.layer,c.dock)
 box:=gd.new_v_box_container();gd.add_child(c.dock,box)
 c.range_label=gd.new_label();gd.add_child(box,c.range_label)
 c.slider=gd.new_h_slider();gd.add_child(box,c.slider);gd.set_string(c.slider,"name","ReplayPlaybackSlider");gd.range_set_step(c.slider,1)
 row:=gd.new_h_box_container();gd.add_child(box,row)
 c.report_panel=gd.new_panel_container();gd.add_child(c.layer,c.report_panel)
 scroll:=gd.new_scroll_container();gd.add_child(c.report_panel,scroll)
 c.report=gd.new_label();gd.add_child(scroll,c.report);gd.set_string(c.report,"name","ReplayPlaybackReport")
 labels:=[5]cstring{"Open recording","Play recording","Return to game","Continue from recording","Details"}
 names:=[5]cstring{"ReplayPlaybackOpen","ReplayPlaybackPlay","ReplayPlaybackClose","ReplayPlaybackBranch","ReplayPlaybackDetails"}
 pressed:=gd.new_string_name("pressed");defer gd.free_string_name(pressed)
 for label,index in labels {
  button:=gd.new_button();c.buttons[index]=button
  gd.add_child(index==0 || index==4 ? cast(gd.Node)bar : cast(gd.Node)row,button)
  gd.set_string(button,"text",label);gd.set_string(button,"name",names[index]);gd.control_set_focus_mode(button,.Focus_None)
  c.callbacks[index]={c,index}
  info:=gdext.ExtensionCallableCustomInfo2{token=gdext.library,call_func=debug_playback_pressed,callable_userdata=&c.callbacks[index]}
  gdext.callable_custom_create2(&c.calls[index],&info);c.count+=1
  c.connected[index]=gd.object_connect(cast(gd.Object)button,pressed,c.calls[index],0)==.Ok
  if !c.connected[index] {debug_playback_destroy(p);return false}
 }
 gd.add_child(bar,c.status);gd.set_string(c.status,"name","ReplayPlaybackStatus")
 gd.set_string(c.status,"text","Open an exported gameplay window")
 if !storagegd.file_import_init(&c.importer,parent,d.MAX_RECORDING_BYTES) {debug_playback_destroy(p);return false}
 gd.canvas_item_set_visible(c.dock,false);gd.canvas_item_set_visible(c.report_panel,false)
 gd.base_button_set_disabled(c.buttons[4],true)
 return true
}

debug_playback_end :: proc(p:^Debug_Playback($S,$I,$E)) {
 d.playback_destroy(&p.player);p.owns_pause=false;p.controls.pending={};p.controls.details=false
 storagegd.file_import_reset(&p.controls.importer)
 if p.controls.layer==nil {return}
 gd.canvas_item_set_visible(p.controls.dock,false);gd.canvas_item_set_visible(p.controls.report_panel,false)
 gd.base_button_set_disabled(p.controls.buttons[4],true);gd.base_button_set_disabled(p.controls.buttons[0],false)
 gd.set_string(p.controls.status,"text","Recording closed")
 if gd.node_is_inside_tree(p.controls.slider) {gd.control_release_focus(p.controls.slider)}
}

debug_playback_frame :: proc(p:^Debug_Playback($S,$I,$E),identity:d.Recording_Context,model:d.Recording_Model(S,I,E),dt:f64)->Debug_Playback_Action {
 c:=&p.controls;if c.layer==nil {return .None}
 was:=p.owns_pause;edges:=c.pending;c.pending={}
 size:=gd.viewport_get_visible_rect(gd.node_get_viewport(c.bar)).size
 gd.control_set_position(c.bar,{18,72},false);gd.control_set_size(c.bar,{max(f32(1),size.x-36),30},false)
 gd.control_set_position(c.dock,{18,max(f32(0),size.y-98)},false);gd.control_set_size(c.dock,{max(f32(1),size.x-36),82},false)
 gd.control_set_position(c.report_panel,{18,108},false);gd.control_set_size(c.report_panel,{max(f32(1),size.x-36),min(f32(130),max(f32(30),size.y-216))},false)
 if edges[2] {debug_playback_end(p);return was ? .Leave : .None}
 if edges[0] && c.importer.phase==.Idle {
  p.player.playing=false
  if storagegd.file_import_begin(&c.importer) {p.owns_pause=true;gd.set_string(c.status,"text","Choose a recording…")}
 }
 switch storagegd.file_import_poll(&c.importer) {
 case .Ready:
  bytes:=storagegd.file_import_take(&c.importer);defer delete(bytes,c.importer.allocator)
  result:=d.playback_load(&p.player,bytes,identity,model);p.last_load=result
  if result.accepted {
   p.loads+=1;c.details=p.player.capture.ready
   gd.set_string(c.report,"text",fmt.ctprintf("%s",p.player.report))
   gd.set_string(c.status,"text",p.player.capture.ready ? fmt.ctprintf("Replay mismatch at tick %d",p.player.capture.result.tick) : "Verified recording")
   gd.range_set_min(c.slider,0);gd.range_set_max(c.slider,f64(p.player.recording.header.head-p.player.recording.base.tick))
   gd.range_set_value(c.slider,f64(p.player.selected-p.player.recording.base.tick))
  } else {p.rejections+=1;gd.set_string(c.status,"text",fmt.ctprintf("Open rejected: %v",result.result.error))}
  p.owns_pause=p.player.recording.ready
 case .Canceled,.Failed:
  failed:=c.importer.phase==.Failed;storagegd.file_import_reset(&c.importer)
  if failed {p.rejections+=1}
  gd.set_string(c.status,"text",failed ? "Cannot read recording" : "Open canceled")
  p.owns_pause=p.player.recording.ready
 case .Idle,.Pending,.Selected:
 }
 ready:=p.owns_pause && p.player.recording.ready
 picking:=c.importer.phase!=.Idle
 gd.base_button_set_disabled(c.buttons[0],picking);gd.base_button_set_disabled(c.buttons[4],!ready)
 gd.base_button_set_disabled(c.buttons[1],!ready || picking);gd.base_button_set_disabled(c.buttons[3],!ready || picking)
 gd.canvas_item_set_visible(c.dock,p.owns_pause);gd.canvas_item_set_visible(c.report_panel,ready && c.details)
 gd.slider_set_editable(c.slider,ready && !picking)
 if p.owns_pause && !ready {gd.set_string(c.range_label,"text","Choosing a recording — Return to game cancels")}
 if ready && !picking {
  first,last:=p.player.recording.base.tick,p.player.recording.header.head
  selected:=first+u64(clamp(gd.range_get_value(c.slider),0,f64(last-first)))
  if selected!=p.player.selected {d.playback_seek(&p.player,selected);p.player.playing=false}
  if edges[1] {d.playback_play(&p.player,!p.player.playing)}
  if edges[4] {c.details=!c.details;gd.canvas_item_set_visible(c.report_panel,c.details)}
  d.playback_advance(&p.player,dt)
  gd.range_set_value(c.slider,f64(p.player.selected-first))
  gd.set_string(c.buttons[1],"text",p.player.playing ? "Pause recording" : "Play recording")
  gd.set_string(c.range_label,"text",fmt.ctprintf("Recording tick %d | %d..%d | expected frames",p.player.selected,first,last))
  if edges[3] {return .Branch}
 }
 if !was && p.owns_pause {return .Enter}
 if was && !p.owns_pause {return .Leave}
 return .None
}

debug_playback_read :: proc(p:^Debug_Playback($S,$I,$E))->(r.Frame(S),bool) {
 if !p.owns_pause {return {},false};return d.playback_read(&p.player)
}
debug_playback_destroy :: proc(p:^Debug_Playback($S,$I,$E)) {
 debug_playback_end(p);c:=&p.controls
 storagegd.file_import_destroy(&c.importer)
 if c.count>0 {
  pressed:=gd.new_string_name("pressed");defer gd.free_string_name(pressed)
  for index in 0..<c.count {
   if c.connected[index] {gd.object_disconnect(cast(gd.Object)c.buttons[index],pressed,c.calls[index])}
   gd.free_callable(c.calls[index])
  }
 }
 if c.layer!=nil {gd.node_queue_free(c.layer)}
 p^={}
}
@(private)
debug_playback_pressed :: proc "c" (raw:rawptr,args:[^]gdext.VariantPtr,argc:i64,ret:gdext.VariantPtr,error:^gdext.CallError) {
 context=gdext.godot_context();gdext.variant_new_nil(ret);error^={}
 if argc!=0 {return};callback:=cast(^Debug_Playback_Callback)raw;callback.owner.pending[callback.index]=true
}
