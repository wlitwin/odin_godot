package replay_godot

import r "godot:replay"
import net "godot:replay/net"
import storagegd "godot:replay/godot/storage"

// Explicit complete-mode entry to the existing Session. The image is borrowed
// during initialization; the underlying Timeline owns its independent clone.
// Client/Observer roles use ordinary session_open and receive a complete Welcome.
// There is no additional stepping loop, history, or mutable model context here.
session_open_complete :: proc(s:^Session($S,$C,$A,$E,$N),initial:^r.Complete_Checkpoint(S,net.Net_Event(E)),model:net.Model(S,C,A,E,N),options:Session_Options,allocator:=context.allocator,ownership:Session_Ownership={})->net.Error {
	if s.ready || !model.complete_state || initial==nil || options.reuse_equal_corrections ||
	   (options.role!=.Solo && options.role!=.Host && options.role!=.Server) ||
	   (options.discover_epoch && options.network.require_permit){return .Invalid_Config}
 if error:=session_begin(s,model,options,allocator,ownership);error!=.None{return error}
	s.options=options;s.options.address=nil;s.options.rtc={};s.options.steam.peer=nil
	if error:=session_connect(s,options);error!=.None{return error}
	s.token=options.token;if s.token==(net.Token{}){s.token=storagegd.session_token()}
	if error:=net.server_init_complete(&s.server,initial,model,s.wire,options.network,local_seat=options.role==.Server?0:1,permit=options.permit,incarnation=options.incarnation,allocator=s.allocator,ownership=session_runner_ownership(s,true));error!=.None{session_close(s);return error}
	s.server.epoch_discovery=options.discover_epoch
	if s.server.local_seat!=0 {if error:=net.server_set_local_token(&s.server,s.token);error!=.None{session_close(s);return error}}
	r.clock_init(&s.clock,options.network.hz);s.ready=true;return .None
}

// These are explicitly game-value observations for presentation. Complete truth
// and durable exports must use session_checkpoint, never this projection.
session_values :: proc(s:^Session($S,$C,$A,$E,$N))->(r.Frame(S),bool){
	if !s.ready{return {},false}
	if s.authority{return r.current_values(&s.server.timeline)}
	if s.client.phase!=.Running && !(s.client.recovering && s.client.has_world){return {},false}
	return r.current_values(&s.client.timeline)
}

session_checkpoint :: proc(s:^Session($S,$C,$A,$E,$N),tick:u64)->(r.Complete_Checkpoint(S,net.Net_Event(E)),net.Error){
	if !s.ready{return {},.Not_Initialized}
	checkpoint:r.Complete_Checkpoint(S,net.Net_Event(E));error:r.Error
	if s.authority {checkpoint,error=r.capture_complete(&s.server.timeline,tick,s.allocator)}
	else {checkpoint,error=r.capture_complete(&s.client.timeline,tick,s.allocator)}
	return checkpoint,error==.None?net.Error.None:net.Error.Incomplete_State
}
