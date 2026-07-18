package cavecrawl_scripts

// Save / resume (phase 6). The session snapshot carries identity, stats, and
// every entity; the GAME BLOB carries what only this game knows — the wave
// director mid-campaign, each dweller's brain, the resurrection clocks.
// Forget the blob and a resumed run restarts wave 1 on top of the saved
// dwellers.

import gd "godot:godot"
import kboot "godot:kit/boot"
import kcombat "godot:kit/combat"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import ksave "godot:kit/save"
import ksess "godot:kit/session"
import kui "godot:kit/ui"
import "core:fmt"

GAME_VERSION :: u16(11) // stamped into saves; bump when cave content shifts

// Where the save lives; tests point it somewhere disposable via env.
@(private = "file")
save_path :: proc() -> cstring {
	p := gd.env_string("CAVE_SAVE")
	if p != "" {
		return fmt.ctprintf("%s", p)
	}
	return "user://cave_save.fslp"
}

// The backup half (kboot.boot_migration's generated table calls it, host
// only): every backup that ships to the designated holder carries the same
// campaign bytes a save file does — a takeover resumes the RUN, not a
// diorama of it.
cave_lobby_backup :: proc(self: ^CaveLobby, w: ^knet.Writer) {
	if !self.started {return}
	write_game_blob(self, w)
}

// The campaign bytes are now DECLARED, not hand-serialized: the six gd:"backup"
// fields on CaveLobby (cavecrawl.odin) generate a version-hashed
// cave_lobby_backup_write/_read pair — POD scalars ride whole, the two maps get
// a length-prefixed loop, and there is no second hand-kept read list to drift
// out of order (the bug this shape exists to kill). These two adapters just
// bridge the generated codec to the blob call sites (a []u8 in, a Writer out).
@(private = "file")
write_game_blob :: proc(self: ^CaveLobby, w: ^knet.Writer) {
	cave_lobby_backup_write(self, w)
}

@(private = "file")
read_game_blob :: proc(self: ^CaveLobby, blob: []u8) -> bool {
	r := knet.reader_make(blob)
	return cave_lobby_backup_read(self, &r)
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
// persisted tokens like any reconnect. ksave.resume is the whole
// file-envelope-restore arc; the transport comes up after (a resume left
// standing by a failed host is fine — the next *_start re-inits).
@(gd_method)
cave_lobby_on_resume :: proc(self: ^CaveLobby) {
	if self.running {return}
	blob, err := ksave.resume(&self.ses, my_name(self), save_path(), GAME_VERSION)
	switch err {
	case .No_File:
		kui.lobby_set_status(&self.boot.ui, "No saved run to resume")
		gd.print_str("CAVE_RESUME_FAIL no-file")
		return
	case .Bad_Envelope, .Wrong_Version:
		kui.lobby_set_status(&self.boot.ui, "That save is from another cave")
		gd.print_str("CAVE_RESUME_FAIL header")
		return
	case .Corrupt:
		gd.print_str("CAVE_RESUME_FAIL snapshot")
		return
	case .Ok:
	}
	if !read_game_blob(self, blob) {
		gd.print_str("CAVE_RESUME_FAIL blob")
		return
	}
	if !gd.host(self.owner, port()) {
		gd.print_str("CAVE_HOST_FAIL")
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
	kui.chat_show(&self.boot.chat, true)
	kcomms.comms_system(&self.comms, "the cave remembers")
	door_open := false
	for _, d in self.doors {door_open = d.open}
	gd.print_str(
		fmt.tprintf(
			"CAVE_RESUMED me=%d players=%d entities=%d reg=%d dwellers=%d gems=%d door=%v",
			u64(self.ses.me),
			ksess.session_count(&self.ses),
			len(self.boot.ent_nodes),
			knet.registry_count(&self.ses.reg),
			len(self.dwellers),
			int(cave_lobby_world_gems(self)),
			door_open,
		),
	)
	gd.print_str(fmt.tprintf("CAVE_BLOB wave=%d ticks=%d brains=%d", self.director.wave, self.host_ticks, len(self.brains)))
}


// HOST MIGRATION, the stepping-stone shape: the designated backup holder
// becomes the new host of the run they were just playing. The MECHANICS —
// wipe, raise, resume, the window gates — are the kit's (boot_take_over
// runs them for the button exactly as the auto path does); this button is
// the manual door the driver presses.
@(gd_method)
cave_lobby_on_takeover :: proc(self: ^CaveLobby) {
	_ = kboot.boot_take_over(&self.boot)
}

// The heir's half, fired AFTER the kit resumed the run as ours: read the
// campaign blob back, re-find the columns (idempotent by name — never
// re-declare), and word the crown. The failure arms word through
// cave_lobby_migrating.
cave_lobby_took_over :: proc(self: ^CaveLobby, r: ^knet.Reader) {
	if !cave_lobby_backup_read(self, r) {
		gd.print_str("CAVE_TAKEOVER_FAIL blob")
		return
	}
	self.cols = kcombat.combat_columns(&self.ses)
	self.slain_col = ksess.session_stat_column(&self.ses, "slain")
	if self.level != nil {
		cave_cache_floor(self, int(self.level.depth))
	}
	self.host_gone = false
	kui.lobby_set_status(&self.boot.ui, "You carry the torch now")
	kcomms.comms_system(&self.comms, "the torch passes")
	gd.print_str(
		fmt.tprintf(
			"CAVE_TAKEOVER me=%d players=%d entities=%d dwellers=%d",
			u64(self.ses.me),
			ksess.session_count(&self.ses),
			knet.registry_count(&self.ses.reg),
			len(self.dwellers),
		),
	)
}
