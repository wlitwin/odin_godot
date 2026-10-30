package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import rgd "godot:replay/godot"
import a "godot:replay/assets"
import net "godot:replay/net"
import storagegd "godot:replay/godot/storage"

browser_data_namespace :: proc(self: ^ReplayScrapyard) -> string {
	return(
		self.local_profile[0].namespace != "" ? self.local_profile[0].namespace : scrap_param("RSY_PROFILE_NAMESPACE", "scrapyard") \
	)
}

browser_data_key :: proc(self: ^ReplayScrapyard, kind: string) -> string {
	key := fmt.tprintf("%s-", kind)
	for b in net.token_hash(self.local_profile[0].token) {
		key = fmt.tprintf("%s%02x", key, b)
	}
	return key
}

browser_run_key :: proc(self: ^ReplayScrapyard) -> string {
	slot := scrap_param("RSY_SAVE_SLOT", "run")
	return browser_data_key(self, slot == "" || slot == "run" ? "run" : fmt.tprintf("run/%s", slot))
}

open_new :: proc(self: ^ReplayScrapyard, role: rgd.Session_Role) {
	if self.session.ready || self.room.ready || self.online.party.active {
		return
	}
	self.resume_requested = false
	browser_run_close(&self.saved_run[0])
	self.saved_run[0].phase = .Idle
	open(self, role)
}

browser_run_close :: proc(record: ^Saved_Run) {
	storagegd.browser_store_close(&record.op)
	delete(record.bytes)
	record.bytes = nil
}

browser_run_error :: proc(self: ^ReplayScrapyard, loading: bool) {
	record := &self.saved_run[0]
	gd.print_str(fmt.tprintf("RSY_SAVE_ERROR browser=%v loading=%v", record.op.error, loading))
	browser_run_close(record)
	record.phase = loading ? .Failed : .Idle
	record.ok = false
	record.notice_until = gd.time_get_ticks_msec(gd.singleton_time()) + 3000
}

browser_run_write :: proc(self: ^ReplayScrapyard) -> bool {
	record := &self.saved_run[0]
	if !storagegd.browser_store_write(
		&record.op,
		browser_data_namespace(self),
		browser_run_key(self),
		record.bytes,
		record.revision,
		a.BUNDLE_LIMIT,
	) {
		browser_run_error(self, false)
		return false
	}
	delete(record.bytes)
	record.bytes = nil
	record.phase = .Writing
	return true
}

browser_run_submit :: proc(self: ^ReplayScrapyard) -> bool {
	record := &self.saved_run[0]
	if record.revision_known {
		return browser_run_write(self)
	}
	if !storagegd.browser_store_read(&record.op, browser_data_namespace(self), browser_run_key(self), a.BUNDLE_LIMIT) {
		browser_run_error(self, false)
		return false
	}
	record.phase = .Checking
	return true
}

browser_run_poll :: proc(self: ^ReplayScrapyard) {
	when gd.IS_WEB {
		record := &self.saved_run[0]
		if record.phase != .Checking && record.phase != .Writing {
			return
		}
		if storagegd.browser_store_poll(&record.op) != .Complete {
			return
		}
		if record.phase == .Checking {
			if record.op.error != .None && record.op.error != .Missing {
				browser_run_error(self, false)
				return
			}
			record.revision = record.op.error == .Missing ? 0 : record.op.revision
			record.revision_known = true
			storagegd.browser_store_close(&record.op)
			browser_run_write(self)
			return
		}
		if record.op.error != .None {
			browser_run_error(self, false)
			return
		}
		record.revision = record.op.revision
		record.saved_tick, record.saved_hash, record.ok = record.pending_tick, record.pending_hash, true
		record.phase = .Idle
		record.notice_until = gd.time_get_ticks_msec(gd.singleton_time()) + 3000
		storagegd.browser_store_close(&record.op)
		gd.print_str(
			fmt.tprintf(
				"RSY_RUN_SAVED tick=%d hash=%d revision=%d",
				record.saved_tick,
				record.saved_hash,
				record.revision,
			),
		)
	}
}

// Called before content loading or runner creation, allowing every render frame
// to keep pumping while the browser obtains the complete save blob.
browser_run_load_ready :: proc(self: ^ReplayScrapyard) -> bool {
	record := &self.saved_run[0]
	if record.phase == .Loaded {
		return true
	}
	if record.phase == .Failed {
		return false
	}
	if record.phase == .Idle {
		if !storagegd.browser_store_read(&record.op, browser_data_namespace(self), browser_run_key(self), a.BUNDLE_LIMIT) {
			browser_run_error(self, true)
			return false
		}
		record.phase = .Loading
		return false
	}
	if record.phase != .Loading || storagegd.browser_store_poll(&record.op) != .Complete {
		return false
	}
	if record.op.error != .None {
		browser_run_error(self, true)
		return false
	}
	bytes, err := storagegd.browser_store_bytes(&record.op)
	if err != .None {
		record.op.error = err
		browser_run_error(self, true)
		return false
	}
	record.bytes, record.revision, record.revision_known = bytes, record.op.revision, true
	storagegd.browser_store_close(&record.op)
	record.phase = .Loaded
	return true
}
