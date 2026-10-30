package replay_scrapyard

import "core:fmt"
import "core:reflect"
import gd "godot:godot"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import game "../shared/game"
import a "godot:replay/assets"

Saved_Run :: struct {
	saved_tick, restored_tick: u64,
	saved_hash, restored_hash: gd.Int,
	notice_until: u64,
	ok: bool,
	phase: Browser_Run_Phase,
	op: rgd.Browser_Store_Op,
	revision: u64,
	revision_known: bool,
	bytes: []u8,
	pending_tick: u64,
	pending_hash: gd.Int,
}

Browser_Run_Phase :: enum {
	Idle,
	Checking,
	Writing,
	Loading,
	Loaded,
	Failed,
}

resume_run :: proc(self: ^ReplayScrapyard, options: rgd.Session_Options) -> net.Error {
	if options.role != .Solo && options.role != .Host && options.role != .Server {
		return .Wrong_Phase
	}
	cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
	defer net.checkpoint_destroy(&cp)
	bytes: []u8
	bundle: a.Bundle_View
	result: rgd.Storage_Result
	when gd.IS_WEB {
		if self.saved_run[0].phase != .Loaded {
			return .Wrong_Phase
		}
		bytes = self.saved_run[0].bytes
		self.saved_run[0].bytes = nil
		self.saved_run[0].phase = .Idle
		bundle, result = rgd.checkpoint_bundle_decode(&cp, game.model(), bytes, game.CONTENT)
	} else {
		bytes, bundle, result = rgd.checkpoint_bundle_read(
			&cp,
			game.model(),
			scrap_param("RSY_SAVE", "user://run.replay"),
			game.CONTENT,
		)
	}
	defer delete(bytes)
	if result.error != .None {
		gd.print_str(fmt.tprintf("RSY_SAVE_ERROR load=%v network=%v", result.error, result.network))
		return .Invalid_Checkpoint
	}
	// A file does not grant a coordinator lease. Such worlds recover through Room.
	if cp.settings.require_permit || cp.header.epoch == max(u64) {
		return .Invalid_Checkpoint
	}
	seat, found := net.checkpoint_seat(&cp, options.token)
	if options.role == .Server {
		seat = 0
	} else if !found || seat == 0 {
		gd.print_str("RSY_SAVE_ERROR identity")
		return .Invalid_Input
	}
	for player in cp.frame.state.players {
		if !a.bundle_has(&bundle, player.spray.image) {
			gd.print_str("RSY_SAVE_ERROR load=Codec missing asset")
			return .Invalid_Checkpoint
		}
	}
	if installed := a.bundle_install(&bundle, &self.assets[0].cache, rgd.asset_png_valid); installed != .None {
		gd.print_str(fmt.tprintf("RSY_SAVE_ERROR load=Codec assets=%v", installed))
		return .Invalid_Checkpoint
	}
	err := rgd.session_resume(
		self.session,
		&cp,
		session_model(self),
		options,
		{epoch = cp.header.epoch + 1, local_seat = seat},
	)
	if err != .None {
		return err
	}
	installed, ok := rgd.session_authority_state(self.session)
	if !ok || !reflect.equal(installed, cp.frame) {
		rgd.session_close(self.session)
		return .Invalid_Frame
	}
	self.saved_run[0].restored_tick = installed.tick
	self.saved_run[0].restored_hash = replay_scrapyard_probe_hash(self, gd.Int(installed.tick))
	// Resuming a complete world preserves its own decal, even if the user's
	// separately stored spray preference changed after this checkpoint.
	self.spray_local[0].loaded = true
	if seat > 0 && cp.frame.state.players[seat - 1].spray.image != (a.Ref{}) {
		image, available := a.cache_copy(&self.assets[0].cache, cp.frame.state.players[seat - 1].spray.image)
		defer delete(image)
		if available != .None || !spray_adopt(self, image, false) {
			rgd.session_close(self.session)
			return .Invalid_Checkpoint
		}
	}
	gd.print_str(fmt.tprintf("RSY_RUN_ASSETS_RESTORED count=%d bytes=%d", bundle.count, self.assets[0].cache.bytes))
	gd.print_str(
		fmt.tprintf(
			"RSY_RUN_RESTORED tick=%d epoch=%d hash=%d",
			installed.tick,
			self.session.server.cfg.epoch,
			self.saved_run[0].restored_hash,
		),
	)
	return .None
}

@(gd_method)
replay_scrapyard_save_run :: proc(self: ^ReplayScrapyard) -> bool {
	record := &self.saved_run[0]
	if record.phase != .Idle {
		return false
	}
	if !self.session.ready || !self.session.authority {
		return false
	}
	if self.room.ready {
		return self.online.enabled && rgd.room_save(&self.room) == .None
	}
	record.ok, record.notice_until = false, gd.time_get_ticks_msec(gd.singleton_time()) + 3000
	frame, ok := rgd.session_authority_state(self.session)
	if !ok {
		return false
	}
	cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
	defer net.checkpoint_destroy(&cp)
	if err := net.checkpoint_capture(&self.session.server, &cp); err != .None {
		return false
	}
	refs: [game.SEATS]a.Ref
	for player, i in cp.frame.state.players {
		refs[i] = player.spray.image
	}
	codec := self.session.link.publish_codec.ready ? &self.session.link.publish_codec : nil
	when gd.IS_WEB {
		bytes, encoded_result := rgd.checkpoint_bundle_encode(&cp, game.model(), &self.assets[0].cache, refs[:], codec)
		if encoded_result.error != .None {
			gd.print_str(
				fmt.tprintf("RSY_SAVE_ERROR encode=%v network=%v", encoded_result.error, encoded_result.network),
			)
			return false
		}
		record.bytes, record.pending_tick, record.pending_hash =
			bytes, frame.tick, replay_scrapyard_probe_hash(self, gd.Int(frame.tick))
		return browser_run_submit(self)
	}
	result := rgd.checkpoint_bundle_write(
		&cp,
		game.model(),
		&self.assets[0].cache,
		refs[:],
		scrap_param("RSY_SAVE", "user://run.replay"),
		codec,
	)
	if result.error != .None {
		gd.print_str(fmt.tprintf("RSY_SAVE_ERROR write=%v network=%v", result.error, result.network))
		return false
	}
	record.saved_tick, record.saved_hash, record.ok =
		frame.tick, replay_scrapyard_probe_hash(self, gd.Int(frame.tick)), true
	gd.print_str(fmt.tprintf("RSY_RUN_SAVED tick=%d hash=%d", record.saved_tick, record.saved_hash))
	return true
}

@(gd_method)
replay_scrapyard_on_resume :: proc(self: ^ReplayScrapyard) {
	if self.session.ready || self.room.ready || self.online.party.active {
		return
	}
	self.resume_requested = true
	when gd.IS_WEB {
		browser_run_close(&self.saved_run[0])
		self.saved_run[0].phase = .Idle
	}
	open(self, .Solo)
}
