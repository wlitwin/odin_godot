package kit_session

// net_event — reliable, non-durable presentation on the cooperative session
// lane. Scriptgen's @(gd_event) surface lowers here when its anchor is a
// session/owner-stream entity (or when it is an explicit immediate static
// event). Simulation-owned declarations lower onto kit/sim's existing fact
// clock instead; this file deliberately does not create a second sim clock.

import knet "godot:kit/net"

Net_Event_Audience :: enum u8 {
	Everyone,
	Owner,
	Observers,
}

Net_Event_Timing :: enum u8 {
	Immediate,
	Anchored,
}

Net_Event_Proc :: proc(
	user: rawptr,
	s: ^Session,
	anchor: knet.Net_Id,
	mine: bool,
	args: []u8,
)

Net_Event_Desc :: struct {
	name:      string,
	id:        u16,
	audience:  Net_Event_Audience,
	timing:    Net_Event_Timing,
	anchored:  bool,
	present:   Net_Event_Proc,
}

NET_EVENT_ARGS_MAX_BYTES :: 4096
NET_EVENT_QUEUE_CAP :: 256

@(private)
Net_Event_In :: struct {
	due:    f64,
	id:     u16,
	anchor: knet.Net_Id,
	mine:   bool,
	args:   []u8, // owned until the presentation proc returns
}

@(private = "file")
net_event_desc :: proc(s: ^Session, id: u16) -> ^Net_Event_Desc {
	for &d in s.net_event_set {
		if d.id == id {
			return &d
		}
	}
	return nil
}

@(private = "file")
net_event_mine :: proc(s: ^Session, d: ^Net_Event_Desc, anchor: knet.Net_Id) -> (mine: bool, live: bool) {
	if !d.anchored {
		// An anchorless event is a world occurrence minted by the authority.
		return s.is_host, true
	}
	e, ok := knet.registry_get(&s.reg, anchor)
	if !ok {
		return false, false
	}
	// PLAYER_ID_INVALID is authority/world ownership. On the authority's own
	// screen it is the local/source timeline; every client observes it.
	return e.owner == s.me || (e.owner == knet.PLAYER_ID_INVALID && s.is_host), true
}

@(private = "file")
net_event_audience_includes :: proc(audience: Net_Event_Audience, mine: bool) -> bool {
	switch audience {
	case .Everyone:  return true
	case .Owner:     return mine
	case .Observers: return !mine
	}
	return false
}

@(private = "file")
net_event_queue :: proc(
	s: ^Session,
	d: ^Net_Event_Desc,
	anchor: knet.Net_Id,
	mine: bool,
	args: []u8,
	defer_immediate: bool,
) {
	if !net_event_audience_includes(d.audience, mine) {
		return
	}
	delayed := d.timing == .Anchored && !mine
	if !delayed && !defer_immediate {
		d.present(s.net_event_user, s, anchor, mine, args)
		return
	}
	if len(s.net_event_in) >= NET_EVENT_QUEUE_CAP {
		s.net_event_dropped += 1
		return
	}
	owned := make([]u8, len(args))
	copy(owned, args)
	due := s.now
	if delayed {
		due += s.interp_delay
	}
	append(&s.net_event_in, Net_Event_In {
		due = due,
		id = d.id,
		anchor = anchor,
		mine = mine,
		args = owned,
	})
}

// Install the generated event table and its game pointer. Wiring survives
// every *_start/reset like entity factories, message routes, and command
// hooks; queued occurrences remain run-scoped and are dropped on reset.
session_set_net_events :: proc(s: ^Session, user: rawptr, table: []Net_Event_Desc) {
	for d, i in table {
		assert(d.id != 0, "net event id 0 is reserved")
		assert(d.present != nil, "net event descriptor needs its presentation thunk")
		assert(d.audience <= .Observers, "net event descriptor has an invalid audience")
		assert(d.timing <= .Anchored, "net event descriptor has invalid timing")
		if d.audience == .Owner {
			assert(d.anchored, "an owner-audience event needs an entity anchor")
		}
		if d.timing == .Anchored {
			assert(d.anchored, "anchored event timing needs an entity anchor")
		}
		for j in 0 ..< i {
			assert(table[j].id != d.id, "net event ids collide")
		}
	}
	s.net_event_user = user
	s.net_event_set = table
}

// Authority announcement door beneath generated @(gd_event) helpers. It
// presents the authority's own eligible copy on the correct clock, then sends
// one reliable frame only to the declared recipients. It is an occurrence,
// never join-replayed state.
session_net_event_emit :: proc(
	s: ^Session,
	id: u16,
	anchor := knet.NET_ID_INVALID,
	args: []u8 = nil,
) -> bool {
	context.allocator = ses_allocator(s) // queued tuples free at drain/reset under the session tier
	if !s.is_host {
		assert(false, "network presentation events are authority-minted; clients ask through commands")
		return false
	}
	if len(args) > NET_EVENT_ARGS_MAX_BYTES {
		assert(false, "net event payload exceeds NET_EVENT_ARGS_MAX_BYTES")
		return false
	}
	d := net_event_desc(s, id)
	if d == nil || d.anchored != (anchor != knet.NET_ID_INVALID) {
		return false
	}
	mine, live := net_event_mine(s, d, anchor)
	if !live {
		return false // the anchor was already despawned: nobody presents a corpse event
	}
	net_event_queue(s, d, anchor, mine, args, false)

	owner := knet.PLAYER_ID_INVALID
	if d.anchored {
		owner = session_owner_of(s, anchor)
	}
	for _, p in s.players {
		if !p.connected || p.id == s.me || p.peer == NO_PEER {
			continue
		}
		is_owner := owner != knet.PLAYER_ID_INVALID && p.id == owner
		include := false
		switch d.audience {
		case .Everyone:  include = true
		case .Owner:     include = is_owner
		case .Observers: include = !is_owner
		}
		if !include {
			continue
		}
		w := knet.writer_make()
		knet.write_u8(&w, SES_NET_EVENT)
		knet.write_u16(&w, id)
		knet.write_net_id(&w, anchor)
		knet.write_bytes(&w, args)
		session_send_packet(s, p.peer, knet.writer_bytes(&w), .Reliable)
		knet.writer_destroy(&w)
	}
	return true
}

// Receive side: called only from the session packet switch after the ordinary
// authority/seat gate. It files bytes and returns; presentation never re-enters
// game code from the packet handler.
@(private)
net_event_receive :: proc(s: ^Session, r: ^knet.Reader) {
	id := knet.read_u16(r)
	anchor := knet.read_net_id(r)
	args := knet.read_bytes_limited(r, NET_EVENT_ARGS_MAX_BYTES)
	if r.err || len(knet.reader_remaining(r)) != 0 {
		r.err = true
		return
	}
	d := net_event_desc(s, id)
	if d == nil || d.anchored != (anchor != knet.NET_ID_INVALID) {
		r.err = true
		return
	}
	mine, live := net_event_mine(s, d, anchor)
	if !live || !net_event_audience_includes(d.audience, mine) {
		return
	}
	net_event_queue(s, d, anchor, mine, args, true)
}

// Called by session_tick after stream sampling, beside session_present's
// later queue. Collect-then-call keeps a presentation proc free to announce or
// file another event without invalidating this traversal.
@(private)
net_event_drain :: proc(s: ^Session, now: f64) {
	clear(&s.net_event_due)
	for i := 0; i < len(s.net_event_in); {
		if s.net_event_in[i].due > now {
			i += 1
			continue
		}
		append(&s.net_event_due, s.net_event_in[i])
		ordered_remove(&s.net_event_in, i)
	}
	for &event in s.net_event_due {
		d := net_event_desc(s, event.id)
		if d != nil {
			_, live := net_event_mine(s, d, event.anchor)
			if live {
				d.present(s.net_event_user, s, event.anchor, event.mine, event.args)
			}
		}
		delete(event.args)
		event.args = nil
	}
	clear(&s.net_event_due)
}

session_net_event_dropped :: proc(s: ^Session) -> u64 {
	return s.net_event_dropped
}
