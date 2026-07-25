package kit_netgd

// succession — the TRANSPORT half of surviving a dead host: how survivors
// FIND the heir. The session does the session half (backups ride to the
// eldest client, the torch names the bearer, session_host_resume raises the
// heir, tokens reclaim seats); kit/boot owns the ORCHESTRATION (the state
// machine, the retry policy, the deferred mechanics — boot/succession.odin).
// What lives HERE is stateless per-transport mechanics:
//
//   - the RENDEZVOUS record: a typed torch ([kind u8][payload]) instead of a
//     sniffed string — one encoder, one decoder, extensible per transport
//     (a Steam lobby id is a future kind, not a format renegotiation).
//   - the torch verbs: compute + broadcast the rendezvous (host), raise the
//     promised transport (heir), dial it ONCE (survivor — the retry loop is
//     boot's).
//
// The kinds shipped today:
//
//   .Native_Addr   [addr string][port u16] — the bearer's address as the host
//                  observed it, and the port the bearer WILL bind (derived
//                  from their seat, so it never collides with the dead
//                  host's). ENet-only: a transport with no peer-address story
//                  cannot light this torch (the torch says so, once).
//   .Web_Room      [code string] — the relay honors reservations on create,
//                  so the host MINTS tomorrow's room code today and rides it
//                  in the torch; the heir hosts UNDER the reserved code and
//                  every survivor knocks on it — on boot's timer, because the
//                  heir needs a breath to open the room and a browser cannot
//                  block.
//
// Same-subnet truth: over raw ENet the address the host observed may not be
// reachable across NAT (room codes and Steam lobbies don't have this problem —
// their rendezvous blobs are ids, not addresses). Friendslop accepts this.

import knet "godot:kit/net"
import ksess "godot:kit/session"
import "core:fmt"
import "core:strings"

// Wordable over voice, like the relay's own codes.
@(private = "file")
SUCC_CODE_ALPHABET :: "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

// The chase policy constants — the state machine that applies them lives in
// kit/boot, but the numbers are transport truths (how long a relay room takes
// to open, how patient a knock should be), so they stay here.
SUCC_CHASE_TRIES :: 12 // ~30s of knocking before the human flow takes over
SUCC_CHASE_GAP :: 2.5
SUCC_CHASE_HEADSTART :: 1.5 // the heir's breath before the first knock

// Which rendezvous flavor a torch carries. A new transport adds a kind and
// two switch arms (encode/dial) — never a string format negotiation.
Rendezvous_Kind :: enum u8 {
	None        = 0, // no torch / an unparseable one — the human flow is all there is
	Native_Addr = 1, // [addr string][port u16]
	Web_Room    = 2, // [code string]
	// A Steam peer id ([id u64]) is the reserved next kind. The Transport
	// record now carries every handle it would need (transport.odin) — what is
	// missing is one slot: kit/steamgd's `address`, i.e. a verified way to ask
	// GodotSteam which steam id is behind a multiplayer peer. Fill that slot
	// and this kind is two switch arms. NOT the lobby id, deliberately: Steam
	// promotes its own lobby owner, which is rarely the session's backup
	// target, and the kit keeps ONE heir story — the torch names the bearer.
}

// Which kinds a transport can light is the transport's own answer
// (Transport.rendezvous); kboot.boot_succ_config reads it there so a door
// never has to be told twice.

// A decoded torch. String fields are VIEWS into the torch bytes — copy them
// out before anything restarts the session (a raise or dial frees
// successor_info under the slice; the boot driver clones to temp first).
Rendezvous :: struct {
	kind: Rendezvous_Kind,
	addr: string, // .Native_Addr
	port: int, // .Native_Addr
	code: string, // .Web_Room
}

Succession :: struct {
	// configure once, before any torch (all copied, never freed by the kit;
	// kboot.boot_succ_config fills it for door games):
	kind:       Rendezvous_Kind, // the flavor THIS run's torch will carry
	signal_url: string, // .Web_Room: the relay url
	base_port:  int, // .Native_Addr: the run's host port (the heir binds a seat-derived sibling)
	token:      u64, // my reconnect identity (the chase rejoins with it)
	name:       string, // my display name (chase + heir host)

	// host-side ceremony state:
	code:            string, // host: the minted web reservation, once per run ("" = not yet)
	warned_no_torch: bool, // the torch said "this transport can't" once already
}

succession_destroy :: proc(sc: ^Succession) {
	delete(sc.code)
	sc.code = ""
}

// Parse a torch. kind == .None (ok=false) covers both "no torch yet" and a
// foreign/corrupt one — the callers treat those identically (human flow).
succession_decode :: proc(info: ksess.Successor_Info) -> (rv: Rendezvous, ok: bool) {
	if len(info.bytes) == 0 {
		return {}, false
	}
	r := knet.reader_make(info.bytes)
	kind := Rendezvous_Kind(knet.read_u8(&r))
	switch kind {
	case .Native_Addr:
		rv.addr = knet.read_string(&r)
		rv.port = int(knet.read_u16(&r))
		if r.err || rv.addr == "" || rv.port == 0 {
			return {}, false
		}
	case .Web_Room:
		rv.code = knet.read_string(&r)
		if r.err || rv.code == "" {
			return {}, false
		}
	case .None:
		return {}, false
	case:
		return {}, false // a kind from the future: this build can't chase it
	}
	rv.kind = kind
	return rv, true
}

// A decoded torch, worded for a human — the log line every game writes when it
// hears who carries the flame ("127.0.0.1:4591", "room QK7MP"). This exists
// because the obvious way to get one used to be `string(info)` on the raw
// blob: it compiled, it read fine while the rendezvous happened to be text,
// and it printed garbage the day the record went binary. Now the raw form
// refuses to stringify (ksess.Successor_Info) and this is the answer it points
// at. Temp-allocated: log it, don't keep it.
succession_words :: proc(rv: Rendezvous, allocator := context.temp_allocator) -> string {
	switch rv.kind {
	case .Native_Addr:
		return fmt.aprintf("%s:%d", rv.addr, rv.port, allocator = allocator)
	case .Web_Room:
		return fmt.aprintf("room %s", rv.code, allocator = allocator)
	case .None:
	}
	return ""
}

// Is there a usable torch to chase? A PEEK — nothing moves, so the game can
// word the no-successor case (and leave its world standing) before wiping
// anything for a real chase.
succession_named :: proc(sc: ^Succession, wire: ^Session_Wire) -> bool {
	_, info := ksess.session_successor(wire.ses)
	_, ok := succession_decode(info)
	return ok
}

// HOST, on Ev_Backup_Target: compute the rendezvous and broadcast it (the
// session re-broadcasts to every later joiner). Web mints ONE reservation per
// run — stable across torch re-broadcasts. Returns a human-readable info
// string for the game's log; false = no rendezvous could be named (unseated
// target, no address, a kind this transport can't light).
succession_torch :: proc(sc: ^Succession, wire: ^Session_Wire, target: knet.Player_Id) -> (info: string, ok: bool) {
	w := knet.writer_make(32, context.temp_allocator)
	switch sc.kind {
	case .Web_Room:
		if sc.code == "" {
			sc.code = succ_mint_code(sc.token)
		}
		knet.write_u8(&w, u8(Rendezvous_Kind.Web_Room))
		knet.write_string(&w, sc.code)
		info = fmt.tprintf("room %s", sc.code)
	case .Native_Addr:
		p, has := wire.ses.players[target]
		if !has {return "", false}
		// The transport's own address story (Transport.address) — ENet answers
		// with the peer's remote address; a transport that leaves the slot nil
		// answers ok=false here.
		addr, aok := transport_address(wire, p.peer)
		if !aok {
			// A transport with no peer-address story can never light the
			// native torch: migration stays ARMED but silently absent. Say it
			// once instead of losing the world to a dead host months later.
			if !sc.warned_no_torch {
				sc.warned_no_torch = true
				// (Native only: the wasm fmt has no stdio — printfln doesn't
				// exist there, and this line class broke the whole web build
				// once.)
				when ODIN_OS != .Freestanding {
					fmt.printfln(
						"kit/netgd: succession torch UNLIT — the %q transport fills no `address` slot, so it cannot name an heir and host migration cannot happen on it; use the web rendezvous (kind = .Web_Room + relay), or fill that slot in its Transport record (kit/netgd/transport.odin)",
						transport_of(wire).name,
					)
				}
			}
			return "", false
		}
		port := succ_port(sc.base_port, target)
		knet.write_u8(&w, u8(Rendezvous_Kind.Native_Addr))
		knet.write_string(&w, addr)
		assert(port <= int(max(u16)))
		knet.write_u16(&w, u16(port))
		info = fmt.tprintf("%s:%d", addr, port)
	case .None:
		return "", false
	}
	ksess.session_set_successor_info(wire.ses, knet.writer_bytes(&w))
	return info, true
}

// THE HEIR, from a succession naming me: raise the transport the torch
// promised — web hosts UNDER the reserved room (the crew is knocking on that
// exact code right now), native binds the seat-derived port. False = the
// crown could not be raised (port taken / relay refused). The caller wipes
// its census first and runs session_host_resume after — this is ONLY the
// transport. (On web, begin_host_web host-starts the session and the resume
// re-inits over it — the same order the native arm runs through begin_host.)
succession_raise :: proc(sc: ^Succession, wire: ^Session_Wire) -> bool {
	// Raise per the TORCH's kind, not the config's — what the survivors hold
	// is what they will chase.
	_, sinfo := ksess.session_successor(wire.ses)
	rv, ok := succession_decode(sinfo)
	if !ok {
		return false
	}
	switch rv.kind {
	case .Web_Room:
		// Copy the reservation OUT before touching the transport — raising
		// re-inits the session, which frees successor_info under the slice.
		room := fmt.ctprintf("%s", rv.code)
		web_close(wire)
		return begin_host_web(wire, fmt.ctprintf("%s", sc.signal_url), sc.name, room = room)
	case .Native_Addr:
		return begin_host(wire, succ_port(sc.base_port, wire.ses.me), sc.name, 32)
	case .None:
	}
	return false
}

// A SURVIVOR: one dial at a decoded torch — no retry, no timer, no state.
// The chase POLICY (tries, gaps, the heir's headstart, when to give up) is
// kit/boot's state machine; this is only the transport verb it repeats.
// Web folds any previous knock's socket first (the relay allows one at a
// time); false = the dial itself refused (ENet create / relay socket).
succession_dial :: proc(sc: ^Succession, wire: ^Session_Wire, rv: Rendezvous) -> bool {
	switch rv.kind {
	case .Web_Room:
		web_close(wire) // fold the previous knock (idempotent on a cold wire)
		return begin_join_web(wire, fmt.ctprintf("%s", sc.signal_url), fmt.ctprintf("%s", rv.code), sc.token, sc.name)
	case .Native_Addr:
		return begin_join(wire, fmt.ctprintf("%s", rv.addr), rv.port, sc.token, sc.name)
	case .None:
	}
	return false
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

// The heir listens on a port derived from their seat — the HOST writes it
// into the rendezvous (peers decode the torch, never re-derive).
@(private = "file")
succ_port :: proc(base: int, p: knet.Player_Id) -> int {
	return base + 1 + int(u64(p) % 512)
}
