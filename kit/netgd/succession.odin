package kit_netgd

// succession — the TRANSPORT half of surviving a dead host, extracted from
// the game that shipped it (scrapyard's succession.odin was ~400 lines; most
// of it was this ceremony, none of it game-shaped). The session already does
// the session half: backups ride to the eldest client, the torch names the
// bearer, session_host_resume raises the heir, tokens reclaim seats. What a
// game still had to hand-roll was the RENDEZVOUS — how survivors FIND the
// heir on each transport flavor:
//
//   native  the host broadcasts "addr:port" — the bearer's address as the
//           host saw it, and the port the bearer WILL bind (derived from
//           their seat, so it never collides with the dead host's).
//   web     the relay honors reservations on create, so the host MINTS
//           tomorrow's room code today and rides it in the torch
//           ("web:<CODE>"); the heir hosts UNDER the reserved code and every
//           survivor knocks on it — on a timer, because the heir needs a
//           breath to open the room and a browser cannot block.
//
// The game keeps what is genuinely its own: wiping its census before a
// raise/chase, restoring its campaign blob, and wording the notes. The shape:
//
//   // ready() — configure once (web/native is a build fact, IS_WEB-style):
//   self.succ = netgd.Succession{web = IS_WEB, signal_url = SIGNAL_URL,
//                                base_port = PORT, token = my_token(), name = my_name()}
//   // Ev_Backup_Target (host): broadcast the rendezvous
//   info, _ := netgd.succession_torch(&self.succ, &self.boot.wire, e.player)
//   // Ev_Succession: the two exits from a dead host
//   if e.successor == self.ses.me {
//       census_clear(self)                                  // yours
//       if netgd.succession_raise(&self.succ, &self.boot.wire) {
//           ksess.session_host_resume(...)                  // yours: resume + blob + fixups
//       }
//   } else {
//       census_clear(self)                                  // yours
//       switch netgd.succession_chase(&self.succ, &self.boot.wire, now) { ... } // word it
//   }
//   // process(), every frame (no-op unless a web chase is live):
//   switch netgd.succession_pulse(&self.succ, &self.boot.wire, now) { ... }     // word it
//   // Ev_Welcomed: the chase caught its seat
//   netgd.succession_done(&self.succ)
//
// Same-subnet truth: over raw ENet the address the host observed may not be
// reachable across NAT (room codes and Steam lobbies don't have this problem —
// their rendezvous blobs are ids, not addresses). Friendslop accepts this.

import knet "godot:kit/net"
import ksess "godot:kit/session"
import "core:fmt"
import "core:strconv"
import "core:strings"

// The web torch's sentinel: "web:<CODE>" (a bare "web" is an old torch with
// no reservation — the human get-the-code-and-rejoin flow is all there is).
SUCC_WEB_INFO :: "web"

// Wordable over voice, like the relay's own codes.
@(private = "file")
SUCC_CODE_ALPHABET :: "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

SUCC_CHASE_TRIES :: 12 // ~30s of knocking before the human flow takes over
SUCC_CHASE_GAP :: 2.5
SUCC_CHASE_HEADSTART :: 1.5 // the heir's breath before the first knock

Succession :: struct {
	// configure once, before any torch (all copied, never freed by the kit):
	web:        bool,   // web room-code rendezvous vs native addr:port
	signal_url: string, // web: the relay url ("" on native)
	base_port:  int,    // native: the run's host port (the heir binds a seat-derived sibling)
	token:      u64,    // my reconnect identity (the chase rejoins with it)
	name:       string, // my display name (chase + heir host)

	// the ceremony's state:
	code:           string, // host: the minted reservation, once per run ("" = not yet)
	chase_code:     string, // chaser: the room being knocked on ("" = idle)
	warned_no_addr: bool, // the torch said "this transport can't" once already
	chase_tries: int,
	chase_next:  f64,
}

// What a chase call/pulse did — the game words each arm (notes, logs).
Chase_Step :: enum {
	Idle,    // nothing to do (native pulse, no live chase)
	Dialing, // native: the rendezvous is being dialed right now
	Knocking, // web: the knock pump armed (chase) or knocked (pulse)
	No_Info, // the torch named nobody / carried no reservation — human flow only
	Failed,  // the dial itself refused (ENet create / relay socket) — human flow
	Gave_Up, // web: out of tries — human flow from here
}

// Is there a usable torch to chase? A PEEK — nothing moves, so the game can
// word the no-successor case (and leave its world standing) before wiping
// anything for a real chase.
succession_named :: proc(sc: ^Succession, wire: ^Session_Wire) -> bool {
	_, info := ksess.session_successor(wire.ses)
	if sc.web {
		code, _ := succ_web_code(string(info))
		return code != ""
	}
	_, _, ok := succ_rendezvous(string(info))
	return ok
}

succession_destroy :: proc(sc: ^Succession) {
	delete(sc.code)
	sc.code = ""
	succession_done(sc)
}

// HOST, on Ev_Backup_Target: compute the rendezvous and broadcast it (the
// session re-broadcasts to every later joiner). Web mints ONE reservation per
// run — stable across torch re-broadcasts. Returns the info for the game's
// log; false = no rendezvous could be named (unseated target, no address).
succession_torch :: proc(sc: ^Succession, wire: ^Session_Wire, target: knet.Player_Id) -> (info: string, ok: bool) {
	if sc.web {
		if sc.code == "" {
			sc.code = succ_mint_code(sc.token)
		}
		info = fmt.tprintf("%s:%s", SUCC_WEB_INFO, sc.code)
		ksess.session_set_successor_info(wire.ses, transmute([]u8)info)
		return info, true
	}
	p, has := wire.ses.players[target]
	if !has {return "", false}
	addr, aok := peer_address(wire.node, p.peer)
	if !aok {
		// A transport with no peer-address story (anything but ENet — Steam,
		// custom peers) can never light the native torch: migration stays
		// ARMED but silently absent. Say it once instead of losing the world
		// to a dead host months later. (A Steam lobby id is the easy
		// rendezvous the per-transport refactor will carry; until then, the
		// web room-code arm is the workaround.)
		if !sc.warned_no_addr {
			sc.warned_no_addr = true
			fmt.println("kit/netgd: succession torch UNLIT — this transport exposes no peer address (ENet-only today), so host migration cannot happen on it; use the web rendezvous (boot_succ_config web=true + relay) until per-transport rendezvous ships")
		}
		return "", false
	}
	info = fmt.tprintf("%s:%d", addr, succ_port(sc.base_port, target))
	ksess.session_set_successor_info(wire.ses, transmute([]u8)info)
	return info, true
}

// THE HEIR, from Ev_Succession naming me: raise the transport the torch
// promised — web hosts UNDER the reserved room (the crew is knocking on that
// exact code right now), native binds the seat-derived port. False = the
// crown could not be raised (port taken / relay refused). The caller wipes
// its census first and runs session_host_resume after — this is ONLY the
// transport. (On web, begin_host_web host-starts the session and the resume
// re-inits over it — the same order the native arm runs through begin_host.)
succession_raise :: proc(sc: ^Succession, wire: ^Session_Wire) -> bool {
	if sc.web {
		// Copy the reservation OUT before touching the transport — raising
		// re-inits the session, which frees successor_info under the slice.
		_, sinfo := ksess.session_successor(wire.ses)
		code, _ := succ_web_code(string(sinfo))
		room := fmt.ctprintf("%s", code)
		web_close(wire)
		return begin_host_web(wire, fmt.ctprintf("%s", sc.signal_url), sc.name, room = room)
	}
	return begin_host(wire, succ_port(sc.base_port, wire.ses.me), sc.name, 32)
}

// A SURVIVOR, from Ev_Succession naming someone else: go find them. Native
// dials the rendezvous now (`.Dialing`); web arms the knock pump
// (`.Knocking` — drive it with succession_pulse every frame). `.No_Info` is
// the human flow: word it and let the player rejoin by hand. The caller
// wipes its census before calling. Re-fires are safe: a live web chase
// ignores them (the pump owns the hunt).
succession_chase :: proc(sc: ^Succession, wire: ^Session_Wire, now: f64) -> Chase_Step {
	if sc.web {
		if sc.chase_code != "" {return .Knocking} // a stale refire — the pump owns it
		_, sinfo := ksess.session_successor(wire.ses)
		code, _ := succ_web_code(string(sinfo))
		if code == "" {
			web_close(wire)
			return .No_Info
		}
		// Copy the code OUT of the session's buffer (every knock restarts the
		// session, which frees it) and give the heir a breath before knocking.
		sc.chase_code = strings.clone(code)
		sc.chase_tries = 0
		sc.chase_next = now + SUCC_CHASE_HEADSTART
		web_close(wire)
		return .Knocking
	}
	_, info := ksess.session_successor(wire.ses)
	addr, chase_port, ok := succ_rendezvous(string(info))
	if !ok {return .No_Info}
	if !begin_join(wire, fmt.ctprintf("%s", addr), chase_port, sc.token, sc.name) {
		return .Failed
	}
	return .Dialing
}

// Every frame (a no-op unless a web chase is live): the knock pump. The heir
// needs a moment to open the reserved room and a browser cannot block, so
// each retry folds the failed attempt and dials fresh. `.Knocking` = a knock
// went out (word the attempt if you like); `.Gave_Up` = out of tries — the
// human flow takes over. A seat arriving (Ev_Welcomed) must call
// succession_done to end the hunt.
succession_pulse :: proc(sc: ^Succession, wire: ^Session_Wire, now: f64) -> Chase_Step {
	if !sc.web || sc.chase_code == "" {return .Idle}
	if now < sc.chase_next {return .Idle}
	if sc.chase_tries >= SUCC_CHASE_TRIES {
		succession_done(sc)
		return .Gave_Up
	}
	if sc.chase_tries > 0 {
		web_close(wire) // fold the failed knock before the next
	}
	sc.chase_tries += 1
	sc.chase_next = now + SUCC_CHASE_GAP
	if !begin_join_web(wire, fmt.ctprintf("%s", sc.signal_url), fmt.ctprintf("%s", sc.chase_code), sc.token, sc.name) {
		return .Idle // the relay socket refused; the timer knocks again
	}
	return .Knocking
}

// The chase ended — a seat (Ev_Welcomed), a give-up — stop knocking.
succession_done :: proc(sc: ^Succession) {
	if sc.chase_code != "" {
		delete(sc.chase_code)
		sc.chase_code = ""
	}
}

// The room being chased ("" = no live chase) — for the game's notes.
succession_chasing :: proc(sc: ^Succession) -> string {
	return sc.chase_code
}

// Mint the reservation — any entropy works (it's a host-local pick the torch
// carries; the relay is the arbiter of collisions). Five characters keeps it
// out of the relay's four-character space and still shoutable.
@(private = "file")
succ_mint_code :: proc(token: u64) -> string {
	h := token * 2654435761 ~ u64(knet.now_s() * 1000)
	alphabet := string(SUCC_CODE_ALPHABET) // constants can't be indexed by a variable
	buf: [5]u8
	for i in 0 ..< 5 {
		h = h * 6364136223846793005 + 1442695040888963407
		buf[i] = alphabet[(h >> 33) % u64(len(alphabet))]
	}
	return strings.clone(string(buf[:]))
}

// Parse the web torch: "web" alone is an old bare sentinel (no reservation).
@(private = "file")
succ_web_code :: proc(info: string) -> (code: string, is_web: bool) {
	if !strings.has_prefix(info, SUCC_WEB_INFO) {return "", false}
	if len(info) > len(SUCC_WEB_INFO) && info[len(SUCC_WEB_INFO)] == ':' {
		return info[len(SUCC_WEB_INFO) + 1:], true
	}
	return "", true
}

// The heir listens on a port derived from their seat — the HOST writes it
// into the rendezvous (peers parse the torch, never re-derive).
@(private = "file")
succ_port :: proc(base: int, p: knet.Player_Id) -> int {
	return base + 1 + int(u64(p) % 512)
}

// Parse a native torch ("addr:port").
@(private = "file")
succ_rendezvous :: proc(info: string) -> (addr: string, p: int, ok: bool) {
	i := strings.last_index_byte(info, ':')
	if i <= 0 {return}
	p, _ = strconv.parse_int(info[i + 1:]) // 0 on garbage, same as ever
	if p == 0 {return}
	return info[:i], p, true
}
