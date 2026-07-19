package kit_boot

// boot_migration — the host-migration dance, danced by nobody.
//
// Every migrating game wrote the same file: the torch on Ev_Backup_Target,
// the `if successor == me` fork on Ev_Succession, the census wipe, the
// transport raise, session_host_resume, the capped chase with its retry
// pulse, `succession_done` on the welcome, and the kicked latch. The
// rendezvous itself was already kit (netgd.Succession); this driver absorbs
// the ORCHESTRATION, and the genuinely game-shaped pieces stay yours as
// name-paired halves scriptgen wires into the table:
//
//     my_game_backup    :: proc(self: ^G, w: ^knet.Writer)  // host: the blob
//     my_game_took_over :: proc(self: ^G, r: ^knet.Reader)  // heir: read blob, mend, word it
//     my_game_wiped     :: proc(self: ^G)                   // every peer: non-entity pools
//     my_game_migrating :: proc(self: ^G, step: kboot.Migrate_Step, target: string, try: int)
//
//     // ready(), AFTER boot_attach (it registers on the attached session):
//     kboot.boot_migration(&self.boot, self, my_game_succ_hooks)
//
// The wipe is CENSUS-DRIVEN: it fires the entity table's `_freed` hooks per
// live entity (the same code that fills the by-type maps empties them), then
// frees the nodes, then fires `_wiped` for the non-entity pools. Census
// hooks stay bookkeeping-only — never present from `_freed`.
//
// Ordering contract: boot_pump only NOTES a succession; the mechanics run in
// boot_migrate_pending, which the generated `<snake>_events` calls after the
// words halves — so `<game>_succession` words a world that still exists, and
// `<game>_took_over` words the one that was just resumed.
//
// Arming follows the SESSION's backup config (it names the targets); the
// halves only supply bytes and words. No session backups = nothing here runs.

import knet "godot:kit/net"
import netgd "godot:kit/netgd"
import ksess "godot:kit/session"
import "core:fmt"
import "core:strings"

// THE STATE MACHINE — one owner for the window that used to be latches here
// (host_gone) plus live-chase state in netgd (chase_code/tries/next). Boot
// holds the whole record now; netgd is stateless per-transport verbs.
//
//   Idle ──Ev_Host_Left/Ev_Succession──▶ Host_Gone ──chase arms──▶ Chasing
//     ▲                                      │  ▲                     │
//     └────────── Ev_Welcomed ◀──────────────┘  └───── give-up ◀──────┘
//
// A takeover collapses Host_Gone → Idle directly (the crown sits). The
// kicked latch is orthogonal — a permanent no that outlives phases until the
// next door re-arms the config.
Succ_Phase :: enum u8 {
	Idle, // no window: host alive (or we ARE the host)
	Host_Gone, // the takeover/rejoin window is open; no mechanics running
	Chasing, // a chase is live (native: dials ride Ev_Succession refires; web: the knock pump owns it)
}

// The generated thunk table — pure data, like Entity_Kind (state lives on
// Boot; generated code carries no globals worth forking across script dlls).
Succ_Hooks :: struct {
	backup:    proc(game: rawptr, w: ^knet.Writer), // nil = empty blob (entities alone)
	took_over: proc(game: rawptr, r: ^knet.Reader), // nil = resume silently
	wiped:     proc(game: rawptr), // nil = no non-entity pools
	migrating: proc(game: rawptr, step: Migrate_Step, target: string, try: int), // nil = no words
}

// Every arm the dance can land on — words, never mechanics (the kit already
// acted; the half narrates). The frozen world stays on screen for the human
// arms: the kit never tears down a scene it cannot rebuild.
Migrate_Step :: enum u8 {
	Taking_Over, // heir: the torch named ME — the takeover starts now (worded ONCE,
	// even when a double death-signal queues the succession twice in one batch)
	Chasing, // native: the rendezvous is being dialed (target = "addr:port")
	Knocking, // web: a knock went out at the reserved room (target = the code)
	No_Torch, // no usable successor info — the human flow is all there is
	Chase_Failed, // the dial itself refused (ENet create / relay socket)
	Gave_Up, // out of tries — the human flow takes over
	No_Backup, // heir: designated but never fed (host died inside the refresh window)
	Raise_Failed, // heir: the crown's transport refused (port taken / relay)
	Resume_Corrupt, // heir: the backup snapshot did not parse
}

// Wire the migration dance. Call once in ready, after boot_attach. `game` is
// the shell struct the halves receive. The dance still ARMS off the session's
// backup config — a game that declares halves but never enables backups just
// carries an unused table.
boot_migration :: proc(b: ^Boot, game: rawptr, hooks: Succ_Hooks) {
	assert(b.ses != nil, "boot_migration comes AFTER boot_attach — it registers on the attached session")
	assert(b.lane == nil, "host migration is coop-lane only for now: a sim lane's authority cannot migrate (the lane would need a rebuild + input epoch care)")
	b.succ_game = game
	b.succ_hooks = hooks
	b.succ_armed = true
	if hooks.backup != nil {
		ksess.session_set_backup_blob(b.ses, b, boot_succ_blob)
	}
}

// The session's blob hook, adapted to the typed half.
@(private = "file")
boot_succ_blob :: proc(user: rawptr, w: ^knet.Writer) {
	b := cast(^Boot)user
	b.succ_hooks.backup(b.succ_game, w)
}

// boot_pump's slice of the dance (called from the event drain): the torch is
// immediate (nothing to wipe), the succession is only NOTED (mechanics wait
// for boot_migrate_pending so the game's words halves see the old world),
// the welcome ends any chase, the kick latches (a kicked player never
// chases a session that showed them the door).
boot_succ_event :: proc(b: ^Boot, ev: ksess.Event) {
	if !b.succ_armed {
		return
	}
	#partial switch e in ev {
	case ksess.Ev_Backup_Target:
		if b.ses.is_host {
			_, _ = netgd.succession_torch(&b.succ, &b.wire, e.player)
		}
	case ksess.Ev_Host_Left:
		if b.succ_phase == .Idle {
			b.succ_phase = .Host_Gone // never demotes a live chase
		}
	case ksess.Ev_Succession:
		if !b.ses.is_host { // a takeover queued a stale twin behind itself — dead here too
			if b.succ_phase == .Idle {
				b.succ_phase = .Host_Gone // a succession IMPLIES the loss (batch order is not ours)
			}
			b.succ_pending = e.successor
			b.succ_has_pending = true
		}
	case ksess.Ev_Welcomed:
		// Seated = the host exists BY DEFINITION — the window closes HERE
		// (dead-socket signals landing mid-rejoin must not re-open it
		// against the live host — the cavecrawl lesson, now the kit's).
		boot_succ_end(b)
	case ksess.Ev_Kicked:
		b.succ_kicked = true
	}
}

// The window closes (a seat arrived, a takeover crowned, a give-up ended the
// hunt): back to Idle, counter zeroed, any live web room released.
@(private = "file")
boot_succ_end :: proc(b: ^Boot) {
	b.succ_phase = .Idle
	b.succ_tries = 0
	if b.succ_room != "" {
		delete(b.succ_room)
		b.succ_room = ""
	}
}

// The web knock pump, one pulse per frame (no-op native / idle). The retry
// POLICY lives here now — netgd only dials; the machine decides when. The
// heir needs a moment to open the reserved room and a browser cannot block,
// so each knock folds the failed socket and dials fresh on the gap timer.
boot_succ_pulse :: proc(b: ^Boot, now: f64) {
	if !b.succ_armed || b.succ_phase != .Chasing || b.succ_room == "" {
		return
	}
	if now < b.succ_next {
		return
	}
	if b.succ_tries >= netgd.SUCC_CHASE_TRIES {
		room := strings.clone(b.succ_room, context.temp_allocator)
		tries := b.succ_tries
		netgd.web_close(&b.wire) // release the half-open knock with the hunt
		boot_succ_end(b)
		b.succ_phase = .Host_Gone // the window stays open for the human flow
		boot_succ_word(b, .Gave_Up, room, tries)
		return
	}
	b.succ_tries += 1
	b.succ_next = now + netgd.SUCC_CHASE_GAP
	rv := netgd.Rendezvous{kind = .Web_Room, code = b.succ_room}
	if netgd.succession_dial(&b.succ, &b.wire, rv) {
		boot_succ_word(b, .Knocking, b.succ_room, b.succ_tries)
	}
	// A refused relay socket just waits for the next gap — the timer knocks again.
}

// The deferred mechanics — the generated `<snake>_events` calls this after
// dispatching the frame's words halves. The fork every game wrote by hand.
boot_migrate_pending :: proc(b: ^Boot) {
	if !b.succ_armed || !b.succ_has_pending {
		return
	}
	successor := b.succ_pending
	b.succ_has_pending = false
	if b.succ_kicked {
		return
	}
	if successor == b.ses.me {
		// The bearer's word rides the DRAIN, not the raw event: a double
		// death-signal queues Ev_Succession twice in one batch, and the bare
		// words half hears both — this arm fires exactly once.
		boot_succ_word(b, .Taking_Over, "", 0)
		_ = boot_take_over(b)
	} else {
		boot_chase(b)
	}
}

// THE HEIR: wipe, raise the promised transport, resume the run as its host,
// hand the game its blob. Public — a manual Resume button drives the same
// sequence the auto path does. False = worded through `_migrating` already
// (no backup / raise refused / corrupt snapshot); the frozen world stays.
boot_take_over :: proc(b: ^Boot) -> bool {
	if !b.succ_armed || b.ses == nil || b.ses.is_host || b.succ_phase == .Idle {
		return false // no window: hosts don't take over, and neither does a live seat
	}
	blob, snapshot, ok := ksess.session_backup_parts(b.ses)
	if !ok {
		boot_succ_word(b, .No_Backup, "", 0)
		return false
	}
	me := b.ses.me
	boot_entities_wipe(b)
	if !netgd.succession_raise(&b.succ, &b.wire) {
		boot_succ_word(b, .Raise_Failed, "", 0)
		return false
	}
	if !ksess.session_host_resume(b.ses, me, b.succ.name, snapshot) {
		boot_succ_word(b, .Resume_Corrupt, "", 0)
		return false
	}
	boot_succ_end(b) // the crown sits — the window is over
	if b.succ_hooks.took_over != nil {
		r := knet.reader_make(blob)
		b.succ_hooks.took_over(b.succ_game, &r)
	}
	return true
}

// A SURVIVOR: decode the torch (no torch = no wipe — the frozen world stays
// worded, not torn down), then wipe and go find the heir. Public — the
// manual rejoin button. Ev_Succession re-fires on every failed native
// reconnect; the ONE tries counter turns that pulse into a bounded chase
// (web knocks count against the same counter, via the pump).
boot_chase :: proc(b: ^Boot) {
	if !b.succ_armed || b.ses == nil || b.ses.is_host || b.succ_phase == .Idle {
		return
	}
	if b.succ_room != "" {
		return // the pump owns a live web chase — a stale refire
	}
	// Decode + COPY the torch out before anything restarts the session —
	// the record's strings view successor_info, which a dial frees (temp:
	// the words half fires this frame; the room clone below is owned).
	_, sinfo := ksess.session_successor(b.ses)
	rv, named := netgd.succession_decode(sinfo)
	if !named {
		boot_succ_word(b, .No_Torch, "", 0)
		return
	}
	switch rv.kind {
	case .Native_Addr:
		if b.succ_tries >= netgd.SUCC_CHASE_TRIES {
			boot_succ_word(b, .Gave_Up, "", b.succ_tries)
			return
		}
		b.succ_tries += 1
		b.succ_phase = .Chasing
		target := fmt.tprintf("%s:%d", rv.addr, rv.port)
		rv.addr = strings.clone(rv.addr, context.temp_allocator)
		boot_entities_wipe(b)
		if netgd.succession_dial(&b.succ, &b.wire, rv) {
			boot_succ_word(b, .Chasing, target, b.succ_tries)
		} else {
			boot_succ_word(b, .Chase_Failed, target, b.succ_tries)
		}
	case .Web_Room:
		// Arm the knock pump: own the room (every knock restarts the session,
		// which frees the torch under the view) and give the heir a breath.
		b.succ_room = strings.clone(rv.code)
		b.succ_tries = 0
		b.succ_next = b.succ_now + netgd.SUCC_CHASE_HEADSTART
		b.succ_phase = .Chasing
		boot_entities_wipe(b)
		netgd.web_close(&b.wire) // fold the dead run's socket; the pump dials fresh
		boot_succ_word(b, .Knocking, b.succ_room, 0)
	case .None:
		boot_succ_word(b, .No_Torch, "", 0)
	}
}

// The census-driven wipe: fire each live entity's `_freed` hook while the
// OLD registry still resolves it (the by-type maps empty through the same
// code that filled them), free the nodes, then `_wiped` for the non-entity
// pools. Also the back-to-lobby wipe — boot_entities_clear with the game's
// bookkeeping carried along.
boot_entities_wipe :: proc(b: ^Boot) {
	if b.ses != nil {
		for id, type in b.ent_types {
			for &k in b.ent_kinds {
				if k.type != type || k.freed == nil {
					continue
				}
				if e, ok := knet.registry_get(&b.ses.reg, id); ok {
					k.freed(b.ent_game, e.entity, id)
				}
				break
			}
		}
	}
	boot_entities_clear(b)
	if b.succ_armed && b.succ_hooks.wiped != nil {
		b.succ_hooks.wiped(b.succ_game)
	}
}

@(private = "file")
boot_succ_word :: proc(b: ^Boot, step: Migrate_Step, target: string, try: int) {
	if b.succ_hooks.migrating != nil {
		b.succ_hooks.migrating(b.succ_game, step, target, try)
	}
}

// Succession config capture — the transport doors call this so the ceremony
// knows the run's shape without a line of game config. The rendezvous KIND
// names the flavor this run's torch will carry (.Native_Addr for ENet doors,
// .Web_Room for relay doors; a Steam lobby kind arrives with the
// Transport-record refactor). The name is cloned: door callers pass temps.
boot_succ_config :: proc(b: ^Boot, kind: netgd.Rendezvous_Kind, port: int, url: cstring, token: u64, name: string) {
	b.succ.kind = kind
	b.succ.base_port = port
	b.succ.token = token
	if b.succ_name != "" {
		delete(b.succ_name)
	}
	b.succ_name = strings.clone(name)
	b.succ.name = b.succ_name
	if kind == .Web_Room {
		if b.succ_url != "" {
			delete(b.succ_url)
		}
		b.succ_url = strings.clone(fmt.tprintf("%s", url))
		b.succ.signal_url = b.succ_url
	}
	b.succ_kicked = false
	boot_succ_end(b)
}
