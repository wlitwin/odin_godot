package replay_cavecrawl

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import game "../shared/cave"

Cave_Browser :: struct {
	identity:rgd.Browser_Identity,
	save:rgd.Browser_Checkpoint(game.World,game.Control,game.Action,game.Event,game.SEATS),
	token:net.Token,token_ready:bool,
	pending_role:string,pending_resume:bool,seen_receipt:u64,
}
browser_cave_ready :: proc(self:^ReplayCave) {
	when gd.IS_WEB {
		io:=&self.browser
		label:=cave_param("REPLAY_CAVE_TOKEN","")
		if label!="" {io.token=rgd.session_token(label);io.token_ready=rgd.browser_identity_valid(io.token)} else {
			rgd.browser_identity_open(&io.identity,cave_param("REPLAY_CAVE_PROFILE_NAMESPACE","replay-cavecrawl"))
		}
	}
}
browser_cave_configured :: proc()->bool {return cave_param("REPLAY_CAVE_COORD_URL","")!="" || cave_int("REPLAY_CAVE_COORD_PORT",0)>0}
browser_cave_slot_open :: proc(self:^ReplayCave) {
	io:=&self.browser
	if !io.token_ready || browser_cave_configured() || io.save.phase!=.Closed {return}
	key:="save/";for b in net.token_hash(io.token) {key=fmt.tprintf("%s%02x",key,b)}
	key=fmt.tprintf("%s/%s",key,cave_param("REPLAY_CAVE_SAVE_SLOT","cave"))
	rgd.browser_checkpoint_open(&io.save,cave_param("REPLAY_CAVE_PROFILE_NAMESPACE","replay-cavecrawl"),key,game.model(),game.CONTENT,io.token)
}
browser_cave_prepared :: proc(self:^ReplayCave)->bool {
	when !gd.IS_WEB {return true} else {
		if !self.browser.token_ready {return false}
		if browser_cave_configured() {return true}
		return self.browser.save.phase==.Ready || self.browser.save.phase==.Failed
	}
}
browser_cave_prepare :: proc(self:^ReplayCave,role:string,resume:bool)->bool {
	when !gd.IS_WEB {return true} else {
		browser_cave_slot_open(self)
		if browser_cave_prepared(self) {return true}
		delete(self.browser.pending_role);self.browser.pending_role=strings.clone(role);self.browser.pending_resume=resume
		return false
	}
}
browser_cave_frame :: proc(self:^ReplayCave) {
	when gd.IS_WEB {
		io:=&self.browser
		if !io.token_ready && io.identity.phase!=.Closed {
			rgd.browser_identity_frame(&io.identity)
			if token,ok:=rgd.browser_identity_token(&io.identity);ok {io.token=token;io.token_ready=true}
		}
		browser_cave_slot_open(self);rgd.browser_checkpoint_frame(&io.save)
		if io.save.receipt_serial!=io.seen_receipt {
			io.seen_receipt=io.save.receipt_serial;self.save_ok=io.save.last_success
			self.save_notice_until=gd.time_get_ticks_msec(gd.singleton_time())+4000
			if self.save_ok {
				self.saved_tick,self.saved_hash=io.save.saved_tick,io.save.saved_hash
				gd.print_str(fmt.tprintf("REPLAY_CAVE_BROWSER_SAVED tick=%d hash=%d revision=%d",self.saved_tick,self.saved_hash,io.save.revision))
			} else {gd.print_str(fmt.tprintf("REPLAY_CAVE_BROWSER_SAVE_FAILED error=%v store=%v network=%v",io.save.error,io.save.store_error,io.save.network_error))}
		}
		if io.pending_role!="" && browser_cave_prepared(self) {
			role:=io.pending_role;io.pending_role="";defer delete(role)
			replay_cave_connect(self,role,io.pending_resume)
		}
	}
}
browser_cave_status :: proc(self:^ReplayCave) {
	when gd.IS_WEB {
		io:=&self.browser
		status:=gd.get_node(self.owner,"Lobby/Panel/Column/SaveStatus")
		message:cstring=""
		if io.identity.phase==.Failed {message="Browser identity could not be loaded. Existing data was kept."}
		else if !io.token_ready {message="Loading browser identity…"}
		else if io.save.phase==.Reading {message="Loading saved run…"}
		else if io.save.phase==.Writing {message="Saving…"}
		else if io.save.phase==.Failed {message=io.save.store_error==.Conflict ? "Another page saved this run. Leave and resume the latest save." : "Saved run could not be read or written. Existing data was kept."}
		else if self.saved_tick>0 && self.save_ok {message="Game saved in this browser."}
		gd.set_string(status,"text",message)
		for name in ([4]cstring{"Solo","Host","Join","Resume"}) {
			button:=cast(gd.Base_Button)gd.get_node(self.owner,fmt.ctprintf("Lobby/Panel/Column/Buttons/%s",name))
			if !browser_cave_prepared(self) {gd.base_button_set_disabled(button,true)}
		}
		resume:=cast(gd.Base_Button)gd.get_node(self.owner,"Lobby/Panel/Column/Buttons/Resume")
		gd.base_button_set_disabled(resume,!self.name_loaded || io.save.phase!=.Ready || !io.save.has_checkpoint)
		leave:=cast(gd.Base_Button)gd.get_node(self.owner,"Lobby/Panel/Column/Buttons/Leave")
		gd.base_button_set_disabled(leave,io.save.phase==.Writing)
		save:=cast(gd.Base_Button)gd.get_node(self.owner,"Lobby/Panel/Column/Buttons/Save")
		gd.canvas_item_set_visible(save,self.ready && self.session.authority && !self.room.ready)
		gd.base_button_set_disabled(save,io.save.phase!=.Ready || self.session.fenced)
	}
}
browser_cave_close :: proc(self:^ReplayCave) {rgd.browser_identity_close(&self.browser.identity);rgd.browser_checkpoint_close(&self.browser.save);delete(self.browser.pending_role);self.browser={}}
@(gd_method)
replay_cave_browser_probe :: proc(self:^ReplayCave,key:string)->gd.Int {
	switch key {
	case "ready":return gd.Int(browser_cave_prepared(self))
	case "identity_ready":return gd.Int(self.browser.token_ready)
	case "identity_error":return gd.Int(self.browser.identity.error)
	case "save_phase":return gd.Int(self.browser.save.phase)
	case "save_error":return gd.Int(self.browser.save.error)
	case "store_error":return gd.Int(self.browser.save.store_error)
	case "has_save":return gd.Int(self.browser.save.has_checkpoint)
	case "revision":return gd.Int(self.browser.save.revision)
	case "receipt":return gd.Int(self.browser.save.receipt_serial)
	case "save_ok":return gd.Int(self.save_ok)
	}
	return -1
}

@(gd_method)
replay_cave_browser_slot :: proc(self:^ReplayCave)->string {return strings.clone(self.browser.save.key,context.temp_allocator)}
