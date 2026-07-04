package cavecrawl_scripts

// Save / resume (phase 6). The session snapshot carries identity, stats, and
// every entity; the GAME BLOB carries what only this game knows — the wave
// director mid-campaign, each dweller's brain, the resurrection clocks.
// Forget the blob and a resumed run restarts wave 1 on top of the saved
// dwellers.

import gd "godot:godot"
import kcombat "godot:kit/combat"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import netgd "godot:kit/netgd"
import ksave "godot:kit/save"
import ksess "godot:kit/session"
import kui "godot:kit/ui"
import "core:fmt"

GAME_VERSION :: u16(8) // stamped into saves; bump when cave content shifts

// Where the save lives; tests point it somewhere disposable via env.
@(private = "file")
save_path :: proc() -> cstring {
	p := env_string("CAVE_SAVE", "")
	if p != "" {
		return fmt.ctprintf("%s", p)
	}
	return "user://cave_save.fslp"
}

@(private = "file")
write_game_blob :: proc(self: ^CaveLobby, w: ^knet.Writer) {
	knet.write_u64(w, u64(self.host_ticks))
	knet.write_u8(w, u8(self.last_wave))
	knet.write_u8(w, u8(self.dens_used))
	knet.write_u8(w, u8(self.director.wave))
	knet.write_u16(w, self.director.pending)
	knet.write_u16(w, u16(self.director.alive))
	knet.write_u64(w, self.director.rest_until)
	knet.write_bool(w, self.director.done)
	assert(len(self.brains) <= int(max(u16)))
	knet.write_u16(w, u16(len(self.brains)))
	for id, b in self.brains {
		knet.write_net_id(w, id)
		knet.write_f32(w, b.home.x)
		knet.write_f32(w, b.home.y)
		knet.write_u16(w, b.bite_cd)
	}
	knet.write_u16(w, u16(len(self.respawn_at)))
	for id, at in self.respawn_at {
		knet.write_net_id(w, id)
		knet.write_u64(w, u64(at))
	}
}

@(private = "file")
read_game_blob :: proc(self: ^CaveLobby, blob: []u8) -> bool {
	r := knet.reader_make(blob)
	self.host_ticks = int(knet.read_u64(&r))
	self.last_wave = int(knet.read_u8(&r))
	self.dens_used = int(knet.read_u8(&r))
	self.director.wave = int(knet.read_u8(&r))
	self.director.pending = knet.read_u16(&r)
	self.director.alive = int(knet.read_u16(&r))
	self.director.rest_until = knet.read_u64(&r)
	self.director.done = knet.read_bool(&r)
	brains := int(knet.read_u16(&r))
	if r.err {return false}
	for _ in 0 ..< brains {
		id := knet.read_net_id(&r)
		home := [3]f32{knet.read_f32(&r), knet.read_f32(&r), 0}
		cd := knet.read_u16(&r)
		if r.err {return false}
		self.brains[id] = Dweller_Brain{home = home, bite_cd = cd}
	}
	respawns := int(knet.read_u16(&r))
	if r.err {return false}
	for _ in 0 ..< respawns {
		id := knet.read_net_id(&r)
		at := int(knet.read_u64(&r))
		if r.err {return false}
		self.respawn_at[id] = at
	}
	return true
}

// Host: write the run to disk — one call, everything phases 0-5 built.
@(gd_method)
cave_lobby_save_run :: proc(self: ^CaveLobby) {
	if !self.ses.is_host || !self.started {return}
	blob := knet.writer_make()
	defer knet.writer_destroy(&blob)
	write_game_blob(self, &blob)
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	ksave.save_write(&self.ses, &w, GAME_VERSION, knet.writer_bytes(&blob))
	ok := ksave.write_file(save_path(), knet.writer_bytes(&w))
	gd.print_str(fmt.tprintf("CAVE_SAVED ok=%v bytes=%d", ok, len(knet.writer_bytes(&w))))
	kcomms.comms_system(&self.comms, "the run is etched in stone")
}

// Host a RESUMED run: the world, the roster (everyone reclaimable), the
// scoreboard, and this game's own campaign state, back from the file. The
// original host returns under its saved identity; friends rejoin with their
// persisted tokens like any reconnect.
@(gd_method)
cave_lobby_on_resume :: proc(self: ^CaveLobby) {
	if self.running {return}
	bytes, read_ok := ksave.read_file(save_path(), context.temp_allocator)
	if !read_ok {
		kui.lobby_set_status(&self.ui, "No saved run to resume")
		gd.print_str("CAVE_RESUME_FAIL no-file")
		return
	}
	r := knet.reader_make(bytes)
	h, hok := ksave.save_read_header(&r)
	if !hok || h.game_version != GAME_VERSION {
		kui.lobby_set_status(&self.ui, "That save is from another cave")
		gd.print_str("CAVE_RESUME_FAIL header")
		return
	}
	if !gd.host(self.owner, port()) {
		gd.print_str("CAVE_HOST_FAIL")
		return
	}
	if netgd.listen_packets(self.owner, "on_packet") != .Ok {return}
	self.ses.send = session_send
	self.ses.send_user = self
	if !ksave.save_restore(&self.ses, my_name(), &r, h) {
		gd.print_str("CAVE_RESUME_FAIL snapshot")
		return
	}
	if !read_game_blob(self, h.game_blob) {
		gd.print_str("CAVE_RESUME_FAIL blob")
		return
	}
	self.cols = kcombat.combat_columns(&self.ses) // find, not redeclare
	self.slain_col = ksess.session_stat_column(&self.ses, "slain")
	// The snapshot restored the depth; the resumed AUTHORITY needs the
	// floor's caches (scenery markers, wave plan) before its first tick.
	if self.level != nil {
		cave_cache_floor(self, int(self.level.depth))
	}
	self.running = true
	enter_the_cave(self)
	kui.chat_show(&self.chat, true)
	kcomms.comms_system(&self.comms, "the cave remembers")
	door_open := false
	for _, d in self.doors {door_open = d.open}
	gd.print_str(
		fmt.tprintf(
			"CAVE_RESUMED me=%d players=%d entities=%d reg=%d dwellers=%d gems=%d door=%v",
			u64(self.ses.me),
			ksess.session_count(&self.ses),
			len(self.nodes),
			knet.registry_count(&self.ses.reg),
			len(self.dwellers),
			int(cave_lobby_world_gems(self)),
			door_open,
		),
	)
	gd.print_str(fmt.tprintf("CAVE_BLOB wave=%d ticks=%d brains=%d", self.director.wave, self.host_ticks, len(self.brains)))
}
