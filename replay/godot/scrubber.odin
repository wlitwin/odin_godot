package replay_godot

import "core:fmt"
import gd "godot:godot"
import "godot:gdext"
import r "godot:replay"

Debug_Scrub_Action :: enum {None, Inspect, Resume, Branch, Invalidated}

// Optional controls for an exclusively paused LOCAL timeline. No simulation,
// journal, clock or network object is mutated by this widget. The owner handles
// each returned action and paints copies obtained through debug_scrubber_read.
Debug_Scrubber :: struct {
	layer:gd.Canvas_Layer,
	panel:gd.Panel_Container,
	label:gd.Label,
	slider:gd.H_Slider,
	toggle,branch:gd.Button,
	active:bool,
	first,last,selected,epoch:u64,
	pending,connected:[2]bool,
	callbacks:[2]Debug_Scrub_Callback,
	calls:[2]gd.Callable,
	call_count:int,
}
@(private)
Debug_Scrub_Callback :: struct {owner:^Debug_Scrubber,index:int}

debug_scrubber_init :: proc(s:^Debug_Scrubber,parent:gd.Node)->bool {
	if parent==nil || s.layer!=nil {return false}
	s.layer=gd.new_canvas_layer();gd.canvas_layer_set_layer(s.layer,1001);gd.add_child(parent,s.layer)
	s.panel=gd.new_panel_container();gd.add_child(s.layer,s.panel)
	box:=gd.new_v_box_container();gd.add_child(s.panel,box)
	s.label=gd.new_label();gd.add_child(box,s.label)
	s.slider=gd.new_h_slider();gd.add_child(box,s.slider)
	gd.range_set_step(s.slider,1);gd.slider_set_editable(s.slider,false)
	row:=gd.new_h_box_container();gd.add_child(box,row)
	s.toggle=gd.new_button();gd.add_child(row,s.toggle);gd.control_set_focus_mode(s.toggle,.Focus_None)
	s.branch=gd.new_button();gd.add_child(row,s.branch);gd.control_set_focus_mode(s.branch,.Focus_None)
	gd.set_string(s.toggle,"text","Pause & inspect (F10)")
	gd.set_string(s.branch,"text","Branch from this frame")
	gd.base_button_set_disabled(s.branch,true)
	gd.set_string(s.label,"text","Local history — inspect frames without changing the running world")
	buttons:=[2]gd.Button{s.toggle,s.branch}
	pressed:=gd.new_string_name("pressed");defer gd.free_string_name(pressed)
	for button,i in buttons {
		s.callbacks[i]={s,i}
		info:=gdext.ExtensionCallableCustomInfo2{token=gdext.library,call_func=debug_scrubber_pressed,callable_userdata=&s.callbacks[i]}
		gdext.callable_custom_create2(&s.calls[i],&info);s.call_count+=1
		s.connected[i]=gd.object_connect(cast(gd.Object)button,pressed,s.calls[i],0)==.Ok
		if !s.connected[i] {debug_scrubber_destroy(s);return false}
	}
	bind_key("replay_debug_inspect",.F10)
	return true
}

debug_scrubber_destroy :: proc(s:^Debug_Scrubber) {
	if s.call_count>0 {
		buttons:=[2]gd.Button{s.toggle,s.branch};pressed:=gd.new_string_name("pressed");defer gd.free_string_name(pressed)
		for i in 0..<s.call_count {
			if s.connected[i] {gd.object_disconnect(cast(gd.Object)buttons[i],pressed,s.calls[i])}
			gd.free_callable(s.calls[i])
		}
	}
	if s.layer!=nil {gd.node_queue_free(s.layer)}
	s^={}
}

debug_scrubber_end :: proc(s:^Debug_Scrubber) {
	s.active=false;s.pending={}
	if s.layer==nil {return}
	gd.slider_set_editable(s.slider,false);gd.base_button_set_disabled(s.branch,true)
	gd.control_release_focus(s.slider)
	gd.set_string(s.toggle,"text","Pause & inspect (F10)")
	gd.set_string(s.label,"text","Local history — inspect frames without changing the running world")
}

// Relative slider offsets stay exact even when absolute ticks exceed f64's
// integer range. A slider spans at most the core's 4096 retained slots.
debug_scrubber_frame :: proc(s:^Debug_Scrubber,t:^r.Timeline($S,$I,$E))->Debug_Scrub_Action {
	if s.layer==nil {return .None}
	viewport:=gd.node_get_viewport(s.panel);size:=gd.viewport_get_visible_rect(viewport).size
	gd.control_set_position(s.panel,{18,max(f32(0),size.y-98)},false)
	gd.control_set_size(s.panel,{max(f32(1),size.x-36),82},false)
	edges:=s.pending;s.pending={}
	if s.active && (t==nil || t.epoch!=s.epoch || t.head!=s.last) {
		debug_scrubber_end(s);gd.set_string(s.label,"text","History changed — inspection ended")
		return .Invalidated
	}
	if edges[0] || gd.is_action_just_pressed("replay_debug_inspect") {
		if s.active {debug_scrubber_end(s);return .Resume}
		first,last,err:=r.history_window(t)
		if err!=.None {gd.set_string(s.label,"text",fmt.ctprintf("History unavailable: %v",err));return .None}
		s.first,s.last,s.selected,s.epoch,s.active=first,last,last,t.epoch,true
		gd.range_set_min(s.slider,0);gd.range_set_max(s.slider,f64(last-first));gd.range_set_value(s.slider,f64(last-first))
		gd.slider_set_editable(s.slider,true);gd.base_button_set_disabled(s.branch,false)
		gd.set_string(s.toggle,"text","Resume original (F10)")
		gd.set_string(s.label,"text",fmt.ctprintf("Inspecting tick %d | retained %d..%d | original head %d",s.selected,s.first,s.last,s.last))
		return .Inspect
	}
	if s.active {
		selected:=s.first+u64(clamp(gd.range_get_value(s.slider),0,f64(s.last-s.first)))
		if selected!=s.selected {
			if _,ok:=r.read(t,selected);!ok {debug_scrubber_end(s);return .Invalidated}
			s.selected=selected
			gd.set_string(s.label,"text",fmt.ctprintf("Inspecting tick %d | retained %d..%d | original head %d",s.selected,s.first,s.last,s.last))
		}
		if edges[1] {return .Branch}
	}
	return .None
}

// Latch the UI event, including a complete click between two simulation pumps.
// The owner keeps this widget at a stable address until destroy disconnects it.
@(private)
debug_scrubber_pressed :: proc "c" (raw:rawptr,args:[^]gdext.VariantPtr,argc:i64,ret:gdext.VariantPtr,error:^gdext.CallError) {
	context=gdext.godot_context();gdext.variant_new_nil(ret);error^={}
	if argc!=0 {return}
	callback:=cast(^Debug_Scrub_Callback)raw
	callback.owner.pending[callback.index]=true
}

debug_scrubber_read :: proc(s:^Debug_Scrubber,t:^r.Timeline($S,$I,$E))->(r.Frame(S),bool) {
	if !s.active || t==nil || t.epoch!=s.epoch || t.head!=s.last {return {},false}
	return r.read(t,s.selected)
}
