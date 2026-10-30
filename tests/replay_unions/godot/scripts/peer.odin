//gd:extends Node
//gd:class ReplayUnionPeer
package union_peer

import "core:fmt"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import sc "godot:replay/schema"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import game "../shared/game"

ReplayUnionPeer :: struct {
	owner:gd.Node,
	session:rgd.Session(game.Union_World,game.Union_Control,game.Union_Action,game.Union_Event,2),
	host,ready,reported:bool,
	stage:int,
	started:u64,
	events,verdicts:u32,
}
replay_union_peer_ready :: proc(self:^ReplayUnionPeer) {
	self.host=gd.env_string("UNION_ROLE","")=="host";self.started=gd.time_get_ticks_msec(gd.singleton_time())
	options:=rgd.SESSION_OPTIONS;options.role=self.host ? .Host : .Client;options.port=u16(gd.env_int("UNION_PORT",49123))
	options.token=rgd.session_token(self.host ? "union-host" : "union-client");options.latency_ms=120;options.jitter_ms=20;options.loss_permyriad=500;options.duplicate_permyriad=500
	err:=rgd.session_open(&self.session,r.Frame(game.Union_World){state={chest=5}},game.union_model(),options)
	self.ready=err==.None;if !self.ready {gd.print_str(fmt.tprintf("UNION_NET_FAIL open=%v",err));gd.scene_tree_quit(gd.get_tree(self.owner),1)}
}
replay_union_peer_process :: proc(self:^ReplayUnionPeer,dt:f64) {
	if !self.ready {return}
	if gd.time_get_ticks_msec(gd.singleton_time())-self.started>20000 {gd.print_str(fmt.tprintf("UNION_NET_FAIL timeout stage=%d events=%d verdicts=%d phase=%v",self.stage,self.events,self.verdicts,self.session.client.phase));gd.scene_tree_quit(gd.get_tree(self.owner),1);return}
	control:game.Union_Control
	if gd.time_get_ticks_msec(gd.singleton_time())-self.started<1500 {control=game.Move{self.host ? 1 : -1}}
	if err:=rgd.session_frame(&self.session,dt,control);err!=.None {gd.print_str(fmt.tprintf("UNION_NET_FAIL frame=%v",err));gd.scene_tree_quit(gd.get_tree(self.owner),1);return}
	changes:[128]v.Change(net.Net_Event(game.Union_Event))
	for {
		count:=rgd.session_changes(&self.session,changes[:]);if count==0 {break}
		for change in changes[:count] {if (change.kind==.Begin && change.confirmed) || change.kind==.Confirm {
			event:=change.occurrence.value
			if event.kind==.Gameplay {self.events+=1}
			if event.kind==.Action_Result && event.applied {self.verdicts+=1}
		}}
	}
	frame,ok:=rgd.session_authority_state(&self.session);if !ok || !frame.state.players[0].active || !frame.state.players[1].active {return}
	left,_:=frame.state.players[0].pocket.(game.Coins);right,_:=frame.state.players[1].pocket.(game.Coins)
	if self.host {
		if self.stage==0 {_,err:=rgd.session_issue(&self.session,game.Union_Action(game.Take{3}));if err==.None {self.stage=1}}
		if self.stage==1 && right.amount==2 {_,err:=rgd.session_issue(&self.session,game.Union_Action(game.Put{1}));if err==.None {self.stage=2}}
	} else {
		if self.stage==0 && left.amount==3 {_,err:=rgd.session_issue(&self.session,game.Union_Action(game.Take{2}));if err==.None {self.stage=1}}
		if self.stage==1 && left.amount==2 {_,err:=rgd.session_issue(&self.session,game.Union_Action(game.Put{2}));if err==.None {self.stage=2}}
	}
	if !self.reported && frame.tick>180 && frame.state.chest==3 && left.amount==2 && frame.state.players[1].pocket==nil && self.events>=4 && self.verdicts>=4 {
		codec:sc.Schema;sc.init(&codec,game.Union_World);defer sc.destroy(&codec);bytes:=make([]u8,codec.wire_size);defer delete(bytes)
		sc.encode(&codec,frame.state,bytes)
		role:=self.host ? "host" : "client";path:=fmt.tprintf("%s/%s.txt",gd.env_string("UNION_DIR",""),role)
		text:=fmt.tprintf("%d",sc.digest(bytes));if rgd.storage_write(path,transmute([]u8)text)!=.None {return}
		self.reported=true;gd.print_str(fmt.tprintf("UNION_NET_RESULT role=%s hash=%s events=%d verdicts=%d",role,text,self.events,self.verdicts))
	}
	if self.reported {
		other:=self.host ? "client" : "host";path:=gd.new_string_odin(fmt.tprintf("%s/%s.txt",gd.env_string("UNION_DIR",""),other));found:=gd.file_access_file_exists(path);gd.free_string(path)
		if found {gd.print_str("REPLAY_UNION_ENET_OK");gd.scene_tree_quit(gd.get_tree(self.owner),0)}
	}
}
replay_union_peer_exit_tree :: proc(self:^ReplayUnionPeer) {rgd.session_close(&self.session)}
