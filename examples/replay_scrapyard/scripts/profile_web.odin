package replay_scrapyard

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import game "../shared/game"
import profile "../shared/profile"

// Open identity before a runner exists. Creation is CAS(0): two tabs loading a
// new origin agree on the winning token instead of independently overwriting it.
profile_web_open :: proc(local: ^Local_Profile, label: string) -> bool {
	if local.error {
		return false
	}
	local.waiting = true
	switch local.web_phase {
	case 0:
		if local.namespace == "" {
			local.namespace = strings.clone(scrap_param("RSY_PROFILE_NAMESPACE", "scrapyard"))
		}
		if label != "" {
			local.token = rgd.session_token(label)
			local.web_phase = 3
			return false
		}
		if !rgd.browser_store_read(&local.op, local.namespace, "identity", 16) {
			profile_web_error(local)
			return false
		}
		local.web_phase = 1
	case 1:
		if rgd.browser_store_poll(&local.op) != .Complete {
			return false
		}
		if local.op.error == .Missing {
			rgd.browser_store_close(&local.op)
			local.token = rgd.session_token()
			if !profile_web_token_valid(local.token) {
				profile_web_error(local, .Corrupt)
				return false
			}
			if !rgd.browser_store_write(&local.op, local.namespace, "identity", local.token[:], 0, 16) {
				profile_web_error(local)
				return false
			}
			local.web_phase = 2
			return false
		}
		if local.op.error != .None {
			profile_web_error(local)
			return false
		}
		bytes, err := rgd.browser_store_bytes(&local.op)
		defer delete(bytes)
		if err != .None || len(bytes) != 16 {
			profile_web_error(local, err != .None ? err : .Corrupt)
			return false
		}
		copy(local.token[:], bytes)
		if !profile_web_token_valid(local.token) {
			profile_web_error(local, .Corrupt)
			return false
		}
		rgd.browser_store_close(&local.op)
		local.web_phase = 3
	case 2:
		if rgd.browser_store_poll(&local.op) != .Complete {
			return false
		}
		if local.op.error == .Conflict {
			rgd.browser_store_close(&local.op)
			local.web_phase = 0
			return false
		}
		if local.op.error != .None {
			profile_web_error(local)
			return false
		}
		rgd.browser_store_close(&local.op)
		local.web_phase = 3
	case 3:
		identity := net.token_hash(local.token)
		local.record.identity = identity
		key := "profile-"
		for b in identity {
			key = fmt.tprintf("%s%02x", key, b)
		}
		local.path = strings.clone(key)
		if !rgd.browser_store_read(&local.op, local.namespace, local.path, 4096) {
			profile_web_error(local)
			return false
		}
		local.web_phase = 4
	case 4:
		if rgd.browser_store_poll(&local.op) != .Complete {
			return false
		}
		if local.op.error == .Missing {
			local.automatic, local.confirmed_automatic = profile.AUTOMATIC_ALL, profile.AUTOMATIC_ALL
			local.record.profile = {
				name = game.name(scrap_param("RSY_NAME", "runner")),
				abilities = {1, 2},
			}
		} else if local.op.error == .None {
			bytes, err := rgd.browser_store_bytes(&local.op)
			defer delete(bytes)
			if err != .None {
				profile_web_error(local, err)
				return false
			}
			record, result := profile.decode(bytes, local.record.identity)
			if result != .None {
				gd.print_str(fmt.tprintf("RSY_PROFILE_ERROR decode=%v", result))
				profile_web_error(local, .Corrupt)
				return false
			}
			local.record, local.has_record, local.revision = record, true, local.op.revision
			local.automatic, local.confirmed_automatic = record.automatic, record.automatic
		} else {
			profile_web_error(local)
			return false
		}
		rgd.browser_store_close(&local.op)
		local.loaded, local.waiting = true, false
		gd.print_str(
			fmt.tprintf(
				"RSY_PROFILE_LOADED cores=%d parts=%d revision=%d",
				local.record.profile.meta.cores,
				local.record.profile.meta.parts,
				local.revision,
			),
		)
		return true
	}
	return false
}

profile_web_token_valid :: proc(token: net.Token) -> bool {
	bits := u8(0)
	for b in token {
		bits |= b
	}
	return bits != 0
}

profile_web_error :: proc(local: ^Local_Profile, error: rgd.Browser_Store_Error = .None) {
	if error != .None {
		local.op.error = error
	}
	local.error, local.waiting, local.writing = true, false, false
	gd.print_str(fmt.tprintf("RSY_PROFILE_ERROR browser=%v", local.op.error))
	rgd.browser_store_close(&local.op)
}

profile_web_finish_write :: proc(local: ^Local_Profile) -> bool {
	if !local.writing {
		return true
	}
	if rgd.browser_store_poll(&local.op) != .Complete {
		return false
	}
	if local.op.error != .None {
		profile_web_error(local)
		return false
	}
	local.record, local.has_record, local.revision = local.writing_record, true, local.op.revision
	local.writing = false
	local.writes += 1
	rgd.browser_store_close(&local.op)
	gd.print_str(
		fmt.tprintf(
			"RSY_PROFILE_SAVED cores=%d parts=%d epoch=%d tick=%d revision=%d",
			local.record.profile.meta.cores,
			local.record.profile.meta.parts,
			local.record.epoch,
			local.record.tick,
			local.revision,
		),
	)
	return true
}
