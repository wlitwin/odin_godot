package replay_scrapyard

import "core:fmt"
import "core:strings"
import "core:reflect"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import game "../shared/game"
import profile "../shared/profile"
import storagegd "godot:replay/godot/storage"

Local_Profile :: struct {
	automatic, confirmed_automatic: u8,
	enabled, loaded, has_record: bool,
	path: string,
	token: net.Token,
	record: profile.Record,
	writes: u32,
	error: bool,
	waiting, writing: bool,
	web_phase: int,
	namespace: string,
	revision: u64,
	op: storagegd.Browser_Store_Op,
	writing_record: profile.Record,
}

profile_open :: proc(local: ^Local_Profile) -> (net.Token, bool) {
	if local.loaded {
		return local.token, true
	}
	label := scrap_param("RSY_TOKEN", "")
	local.enabled = scrap_int("RSY_PERSIST", len(label) == 0 ? 1 : 0) != 0
	if !local.enabled {
		local.automatic, local.confirmed_automatic = profile.AUTOMATIC_ALL, profile.AUTOMATIC_ALL
		local.token = storagegd.session_token(label)
		local.loaded = true
		return local.token, true
	}
	when gd.IS_WEB {
		return local.token, profile_web_open(local, label)
	}
	directory := strings.trim_suffix(scrap_param("RSY_PROFILE_DIR", "user://"), "/")
	if len(label) > 0 {
		local.token = storagegd.session_token(label)
	} else {
		var_token, err := storagegd.session_profile(fmt.tprintf("%s/replay_identity", directory))
		if err != .None {
			gd.print_str(fmt.tprintf("RSY_PROFILE_ERROR identity=%v", err))
			return {}, false
		}
		local.token = var_token
	}
	identity := net.token_hash(local.token)
	name := ""
	for b in identity {
		name = fmt.tprintf("%s%02x", name, b)
	}
	local.path = strings.clone(fmt.tprintf("%s/replay_profile_%s", directory, name))
	local.record.identity = identity
	path := gd.new_string_odin(local.path)
	defer gd.free_string(path)
	if gd.file_access_file_exists(path) {
		bytes, storage := storagegd.storage_read(local.path, 4096)
		defer delete(bytes)
		if storage != .None {
			gd.print_str(fmt.tprintf("RSY_PROFILE_ERROR read=%v", storage))
			return {}, false
		}
		record, result := profile.decode(bytes, identity)
		if result != .None {
			gd.print_str(fmt.tprintf("RSY_PROFILE_ERROR decode=%v", result))
			return {}, false
		}
		local.record, local.has_record = record, true
		local.automatic, local.confirmed_automatic = record.automatic, record.automatic
	} else {
		local.automatic, local.confirmed_automatic = profile.AUTOMATIC_ALL, profile.AUTOMATIC_ALL
		local.record.profile = {
			name = game.name(scrap_param("RSY_NAME", "runner")),
			abilities = {1, 2},
		}
	}
	local.loaded = true
	gd.print_str(
		fmt.tprintf(
			"RSY_PROFILE_LOADED cores=%d parts=%d",
			local.record.profile.meta.cores,
			local.record.profile.meta.parts,
		),
	)
	return local.token, true
}

profile_sync :: proc(self: ^ReplayScrapyard, truth: ^r.Frame(game.World)) {
	local := &self.local_profile[0]
	seat := rgd.session_seat(self.session)
	if seat == 0 || !local.loaded {
		return
	}
	player := truth.state.players[seat - 1]
	if !player.meta_claimed {
		return
	}
	fresh := player.profile
	fresh.meta, fresh.ready = {player.cores, player.parts}, false
	// Publish preference intent only when its resolved choice matches authority.
	// A late acknowledgement must not persist an obsolete explicit choice.
	if !player.in_yard && self.selected {
		wanted, valid := profile.resolve(self.choices[0], local.automatic, seat, &truth.state.catalog)
		if !valid || !profile.matching_choices(wanted, fresh) {
			if scrap_int("RSY_TRACE", 0) == 1 && local.automatic != local.confirmed_automatic {
				gd.print_str(
					fmt.tprintf(
						"RSY_AUTO_WAIT mode=%d confirmed=%d q=%d want_q=%d",
						local.automatic,
						local.confirmed_automatic,
						fresh.abilities[0],
						wanted.abilities[0],
					),
				)
			}
			return
		}
	}
	if scrap_int("RSY_TRACE", 0) == 1 && local.automatic != local.confirmed_automatic {
		gd.print_str(fmt.tprintf("RSY_AUTO_CONFIRMED mode=%d q=%d", local.automatic, fresh.abilities[0]))
	}
	local.confirmed_automatic = local.automatic
	if !local.enabled || local.error {
		return
	}
	when gd.IS_WEB {
		if !profile_web_finish_write(local) {
			return
		}
	}
	if local.has_record && reflect.equal(fresh, local.record.profile) && local.record.automatic == local.automatic {
		return
	}
	record := local.record
	record.profile = fresh
	record.tick = truth.tick
	record.automatic = local.automatic
	record.epoch = self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
	bytes, err := profile.encode(record)
	defer delete(bytes)
	if err != .None {
		local.error = true
		gd.print_str(fmt.tprintf("RSY_PROFILE_ERROR encode=%v", err))
		return
	}
	when gd.IS_WEB {
		if !storagegd.browser_store_write(&local.op, local.namespace, local.path, bytes, local.revision, 4096) {
			profile_web_error(local)
			return
		}
		local.writing_record, local.writing = record, true
		return
	}
	if storage := storagegd.storage_write(local.path, bytes, 4096); storage != .None {
		local.error = true
		gd.print_str(fmt.tprintf("RSY_PROFILE_ERROR write=%v", storage))
		return
	}
	local.record, local.has_record = record, true
	local.writes += 1
	gd.print_str(
		fmt.tprintf(
			"RSY_PROFILE_SAVED cores=%d parts=%d epoch=%d tick=%d",
			fresh.meta.cores,
			fresh.meta.parts,
			record.epoch,
			record.tick,
		),
	)
}

profile_close :: proc(local: ^Local_Profile) {
	storagegd.browser_store_close(&local.op)
	delete(local.namespace)
	delete(local.path)
	local^ = {}
}
