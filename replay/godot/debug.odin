package replay_godot

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import diagnostic "godot:replay/diagnostic"

// Optional local developer UI. It samples metadata only; audits are explicit,
// bounded operations. It never sends state, invokes a game action, or writes files.
Debug_Overlay :: struct {
	layer:gd.Canvas_Layer,
	label:gd.Label,
	visible:bool,
	next_refresh:u64,
	audit_message:string,
	last_audit:r.Result,
	audits:u64,
}
debug_overlay_init :: proc(debug:^Debug_Overlay,parent:gd.Node,visible:bool=false)->bool {
	if parent==nil || debug.layer!=nil {return false}
	debug.layer=gd.new_canvas_layer();gd.canvas_layer_set_layer(debug.layer,1000);gd.add_child(parent,debug.layer)
	panel:=gd.new_panel_container();gd.add_child(debug.layer,panel);gd.control_set_position(panel,{18,105},false);gd.control_set_size(panel,{650,460},false)
	style:=gd.new_style_box_flat();gd.ref_counted_init_ref(style)
	gd.style_box_flat_set_bg_color(style,{0.03,0.04,0.05,0.96})
	sides:=[4]gd.Side{.Left,.Top,.Right,.Bottom}
	for side in sides {gd.style_box_set_content_margin(style,side,12)}
	name:=gd.new_string_name("panel");gd.control_add_theme_stylebox_override(panel,name,style);gd.free_string_name(name);gd.release_ref(style)
	scroll:=gd.new_scroll_container();gd.add_child(panel,scroll)
	debug.label=gd.new_label();gd.add_child(scroll,debug.label);gd.set_string(debug.label,"text","Replay diagnostics")
	bind_key("replay_debug_toggle",.F8);bind_key("replay_debug_audit",.F9)
	debug.visible=visible;gd.canvas_layer_set_visible(debug.layer,visible)
	return true
}
debug_overlay_destroy :: proc(debug:^Debug_Overlay) {
	if debug.layer!=nil {gd.node_queue_free(debug.layer)}
	delete(debug.audit_message);debug^={}
}
// Return true for an explicit audit request while this panel is visible.
debug_overlay_input :: proc(debug:^Debug_Overlay)->bool {
	if debug.layer==nil {return false}
	if gd.is_action_just_pressed("replay_debug_toggle") {debug.visible=!debug.visible;debug.next_refresh=0;gd.canvas_layer_set_visible(debug.layer,debug.visible)}
	return debug.visible && gd.is_action_just_pressed("replay_debug_audit")
}
debug_overlay_text :: proc(debug:^Debug_Overlay,status:string) {
	if debug.layer==nil || !debug.visible {return}
	now:=gd.time_get_ticks_msec(gd.singleton_time());if now<debug.next_refresh {return};debug.next_refresh=now+250
	text:=fmt.ctprintf("REPLAY DIAGNOSTICS  |  F8 hide  |  F9 audit recent history\n%s\n\n%s",status,debug.audit_message)
	gd.set_string(debug.label,"text",text)
}
debug_audit :: proc(debug:^Debug_Overlay,timeline:^r.Timeline($S,$I,$E),ticks:int=120) {
	capture:r.Audit_Capture(S,I,E);defer r.audit_capture_destroy(&capture)
	result:=r.audit_recent(timeline,&capture,ticks)
	delete(debug.audit_message);debug.audit_message=diagnostic.audit_text(result,&capture)
	debug.last_audit=result;debug.audits+=1;debug.next_refresh=0
}
debug_timeline_status :: proc(t:^r.Timeline($S,$I,$E))->string {
	from,to,err:=r.audit_window(t)
	return fmt.tprintf("Local timeline | epoch %d | head %d | confirmed %d\nReplayable window %d..%d (%v) | retained slots %d",t.epoch,t.head,t.confirmed,from,to,err,len(t.records))
}
debug_session_status :: proc(s:^Session($S,$C,$A,$E,$N))->string {
	if s==nil || !s.ready {return "Session closed"}
	if s.authority {
		peers:=0;for peer in s.server.peers {if peer.phase==.Running {peers+=1}}
		stats:=s.server.stats
		return fmt.tprintf("%v | authority | epoch %d | head %d | peers %d | fenced %v\nTX %d B | RX %d B | rejected packets %d / inputs %d\nSnapshots full %d / delta %d | deferred %d",s.role,s.server.cfg.epoch,s.server.timeline.head,peers,s.fenced,stats.tx_bytes,stats.rx_bytes,stats.rejected_packets,stats.rejected_inputs,stats.full_snapshots,stats.delta_snapshots,stats.egress_deferred)
	}
	c:=&s.client;stats:=c.stats
	reason:=c.resync_notice.serial==0 ? "none" : fmt.tprintf("%v",c.resync_notice.reason)
	return fmt.tprintf("%v | %v | rejection %v | epoch %d | seat %d\nHead %d | confirmed %d | facts %d | prediction %d ticks\nTX %d B | RX %d B | corrections %d | replayed %d\nResyncs %d | latest reason %s | pending actions %d",s.role,c.phase,c.rejection,c.cfg.epoch,c.seat,c.timeline.head,c.timeline.confirmed,c.facts_contiguous,c.timeline.head-c.timeline.confirmed,stats.tx_bytes,stats.rx_bytes,stats.corrections,stats.replayed_ticks,stats.resyncs,reason,c.action_count)
}
debug_session_audit :: proc(debug:^Debug_Overlay,s:^Session($S,$C,$A,$E,$N),ticks:int=120) {
	if s==nil || !s.ready {delete(debug.audit_message);debug.audit_message=strings.clone("Audit unavailable: session closed");debug.next_refresh=0;return}
	if s.authority {debug_audit(debug,&s.server.timeline,ticks)} else {debug_audit(debug,&s.client.timeline,ticks)}
}

// Convenience drivers avoid formatting/sampling when the overlay is disabled
// or not due for its 4 Hz refresh. Call after the application's simulation pump.
debug_timeline_frame :: proc(debug:^Debug_Overlay,t:^r.Timeline($S,$I,$E)) {
	if debug.layer==nil {return}
	if debug_overlay_input(debug) {debug_audit(debug,t)}
	if debug.visible && gd.time_get_ticks_msec(gd.singleton_time())>=debug.next_refresh {debug_overlay_text(debug,debug_timeline_status(t))}
}
debug_session_frame :: proc(debug:^Debug_Overlay,s:^Session($S,$C,$A,$E,$N)) {
	if debug.layer==nil {return}
	if debug_overlay_input(debug) {debug_session_audit(debug,s)}
	if debug.visible && gd.time_get_ticks_msec(gd.singleton_time())>=debug.next_refresh {debug_overlay_text(debug,debug_session_status(s))}
}
