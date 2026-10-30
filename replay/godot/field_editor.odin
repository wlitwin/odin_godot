package replay_godot

import "core:fmt"
import gd "godot:godot"
import "godot:gdext"
import r "godot:replay"
import sc "godot:replay/schema"

// Owns a copied local preview. Keep this struct at a stable address until destroy.
// The application explicitly chooses whether to branch from the returned frame.
Debug_Field_Editor :: struct(State:typeid) {
 controls:Debug_Field_Controls,
 schema:sc.Schema,
 original,preview:r.Frame(State),
 valid:proc(State)->bool,
 epoch:u64,
 active,dirty:bool,
 selected:int,
}
@(private)
Debug_Field_Controls :: struct {
 layer:gd.Canvas_Layer,panel:gd.Panel_Container,label:gd.Label,
 fields:gd.Option_Button,value:gd.Line_Edit,apply,reset:gd.Button,
 pending,connected:[2]bool,callbacks:[2]Debug_Field_Callback,calls:[2]gd.Callable,call_count:int,
}
@(private)
Debug_Field_Callback :: struct {owner:^Debug_Field_Controls,index:int}

debug_field_editor_init :: proc(e:^Debug_Field_Editor($S),parent:gd.Node,valid:proc(S)->bool)->bool {
 if parent==nil || e.controls.layer!=nil || e.schema.ready {return false}
 if sc.init(&e.schema,S).error!=.None {sc.destroy(&e.schema);return false}
 e.valid=valid;e.selected=-1
 c:=&e.controls
 c.layer=gd.new_canvas_layer();gd.canvas_layer_set_layer(c.layer,1001);gd.add_child(parent,c.layer)
 c.panel=gd.new_panel_container();gd.add_child(c.layer,c.panel)
 box:=gd.new_v_box_container();gd.add_child(c.panel,box)
 c.label=gd.new_label();gd.add_child(box,c.label);gd.set_string(c.label,"name","ReplayFieldStatus")
 c.fields=gd.new_option_button();gd.add_child(box,c.fields)
 // Bounded menu. Large models can use schema.edit_scalar with their own search UI.
 for field,index in e.schema.fields[:min(len(e.schema.fields),2048)] {
  label:=gd.new_string_odin(field.path);gd.option_button_add_item(c.fields,label,gd.Int(index));gd.free_string(label)
 }
 row:=gd.new_h_box_container();gd.add_child(box,row)
 c.value=gd.new_line_edit();gd.add_child(row,c.value);gd.set_string(c.value,"name","ReplayFieldValue");gd.line_edit_set_max_length(c.value,128)
 gd.control_set_custom_minimum_size(c.value,{220,0})
 c.apply=gd.new_button();gd.add_child(row,c.apply);gd.set_string(c.apply,"text","Apply to preview")
 c.reset=gd.new_button();gd.add_child(row,c.reset);gd.set_string(c.reset,"text","Reset preview")
 pressed:=gd.new_string_name("pressed");defer gd.free_string_name(pressed)
 buttons:=[2]gd.Button{c.apply,c.reset}
 for button,index in buttons {
  gd.control_set_focus_mode(button,.Focus_None)
  c.callbacks[index]={c,index}
  info:=gdext.ExtensionCallableCustomInfo2{token=gdext.library,call_func=debug_field_editor_pressed,callable_userdata=&c.callbacks[index]}
  gdext.callable_custom_create2(&c.calls[index],&info);c.call_count+=1
  c.connected[index]=gd.object_connect(cast(gd.Object)button,pressed,c.calls[index],0)==.Ok
  if !c.connected[index] {debug_field_editor_destroy(e);return false}
 }
 gd.canvas_item_set_visible(c.panel,false)
 return true
}

debug_field_editor_end :: proc(e:^Debug_Field_Editor($S)) {
 e.active=false;e.dirty=false;e.controls.pending={};e.original={};e.preview={};e.selected=-1
 if e.controls.layer==nil {return}
 gd.control_release_focus(e.controls.value);gd.control_release_focus(e.controls.fields)
 gd.canvas_item_set_visible(e.controls.panel,false)
}

// Call after scrubber_frame and before acting on Branch. Changing the selected
// tick discards preview edits; ending inspection discards the entire preview.
debug_field_editor_frame :: proc(e:^Debug_Field_Editor($S),s:^Debug_Scrubber,t:^r.Timeline(S,$I,$E)) {
 c:=&e.controls
 if c.layer==nil {return}
 frame,ok:=debug_scrubber_read(s,t)
 if !ok {debug_field_editor_end(e);return}
 edges:=c.pending;c.pending={}
 refresh:=false
 if !e.active || e.epoch!=s.epoch || e.original.tick!=frame.tick {
  e.original=frame;e.preview=frame;e.epoch=s.epoch;e.active=true;e.dirty=false
  e.selected=-1;edges={};refresh=true
  gd.canvas_item_set_visible(c.panel,true)
 }
 size:=gd.viewport_get_visible_rect(gd.node_get_viewport(c.panel)).size
 gd.control_set_position(c.panel,{18,max(f32(0),size.y-218)},false)
 gd.control_set_size(c.panel,{max(f32(1),size.x-36),110},false)
 selected:=int(gd.option_button_get_selected(c.fields))
 if selected!=e.selected {e.selected=selected;refresh=true;edges[0]=false}
 if edges[1] {e.preview=e.original;e.dirty=false;refresh=true;edges[0]=false}
 if refresh {debug_field_editor_refresh(e)}
 if edges[0] {
  raw:=gd.line_edit_get_text(c.value);defer gd.free_string(raw)
  text:=gd.gd_string_to_odin(raw,context.allocator);defer delete(text)
  report:=sc.edit_scalar(&e.schema,&e.preview.state,e.selected,text,e.valid)
  if report.error==.None {e.dirty=true;debug_field_editor_refresh(e)}
  else {gd.set_string(c.label,"text",fmt.ctprintf("Edit rejected: %v — preview unchanged",report.error))}
 }
}

@(private)
debug_field_editor_refresh :: proc(e:^Debug_Field_Editor($S)) {
 c:=&e.controls
 text,error:=sc.scalar_text(&e.schema,e.preview.state,e.selected);defer delete(text)
 read_only:=error!=.None
 if !read_only {read_only=e.schema.fields[e.selected].kind==.Union_Tag}
 gd.set_string(c.value,"text",fmt.ctprintf("%s",text))
 gd.line_edit_set_editable(c.value,!read_only);gd.base_button_set_disabled(c.apply,read_only)
 status:=e.dirty ? "Edited preview — Branch accepts it; Resume discards it" : "Preview only — Apply validates; Branch starts a new timeline"
 if error==.Inactive_Field {status="Inactive union field — select a field in the active variant"}
 else if read_only {status="Read-only field — union variants require a complete value"}
 if len(e.schema.fields)>2048 {status="First 2048 fields shown — edits affect the preview only"}
 gd.set_string(c.label,"text",fmt.ctprintf("%s",status))
}

debug_field_editor_read :: proc(e:^Debug_Field_Editor($S))->(r.Frame(S),bool) {return e.preview,e.active}

debug_field_editor_destroy :: proc(e:^Debug_Field_Editor($S)) {
 c:=&e.controls
 if c.call_count>0 {
  pressed:=gd.new_string_name("pressed");defer gd.free_string_name(pressed)
  buttons:=[2]gd.Button{c.apply,c.reset}
  for index in 0..<c.call_count {
   if c.connected[index] {gd.object_disconnect(cast(gd.Object)buttons[index],pressed,c.calls[index])}
   gd.free_callable(c.calls[index])
  }
 }
 if c.layer!=nil {gd.node_queue_free(c.layer)}
 sc.destroy(&e.schema);e^={}
}

@(private)
debug_field_editor_pressed :: proc "c" (raw:rawptr,args:[^]gdext.VariantPtr,argc:i64,ret:gdext.VariantPtr,error:^gdext.CallError) {
 context=gdext.godot_context();gdext.variant_new_nil(ret);error^={}
 if argc!=0 {return}
 callback:=cast(^Debug_Field_Callback)raw;callback.owner.pending[callback.index]=true
}
