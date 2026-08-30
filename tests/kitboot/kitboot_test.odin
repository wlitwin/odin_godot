package kit_boot_test

// Engine-free checks for kit/boot's entity census. The Boot value is populated
// with the same registry/type/index rows its factory owns at runtime; no Godot
// node is needed to exercise exact-kind and ownership cardinality.

import "core:testing"
import kboot "godot:kit/boot"
import knet "godot:kit/net"
import ksess "godot:kit/session"

PROBE_TYPE :: ksess.Entity_Type(41)

Probe :: struct {
	value: i32,
}

probe_desc := knet.Entity_Desc{}
probe_set := knet.Command_Set{entity_desc = &probe_desc}

send_sink :: proc(user: rawptr, to: ksess.Peer_Id, bytes: []u8, channel: ksess.Channel) {
	_ = user; _ = to; _ = bytes; _ = channel
}

boot_census_make :: proc(s: ^ksess.Session, b: ^kboot.Boot) {
	s.send = send_sink
	ksess.session_host_start(s, "census")
	b.ses = s
	b.ent_types = make(map[knet.Net_Id]ksess.Entity_Type)
	b.ent_heads = make(map[ksess.Entity_Type]knet.Net_Id)
	b.ent_next = make(map[knet.Net_Id]knet.Net_Id)
}

boot_census_destroy :: proc(s: ^ksess.Session, b: ^kboot.Boot) {
	delete(b.ent_types)
	delete(b.ent_heads)
	delete(b.ent_next)
	ksess.session_destroy(s)
}

boot_census_insert :: proc(
	s: ^ksess.Session,
	b: ^kboot.Boot,
	id: knet.Net_Id,
	entity: rawptr,
	owner: knet.Player_Id,
) {
	knet.registry_insert(&s.reg, id, entity, &probe_set, owner)
	b.ent_types[id] = PROBE_TYPE
	if head, has := b.ent_heads[PROBE_TYPE]; has {
		last := head
		for {
			next, ok := b.ent_next[last]
			if !ok || next == knet.NET_ID_INVALID {
				break
			}
			last = next
		}
		b.ent_next[last] = id
	} else {
		b.ent_heads[PROBE_TYPE] = id
	}
}

@(test)
owned_entity_is_an_honest_singular_query :: proc(t: ^testing.T) {
	s: ksess.Session
	b: kboot.Boot
	boot_census_make(&s, &b)
	defer boot_census_destroy(&s, &b)

	first := Probe{value = 10}
	boot_census_insert(&s, &b, 11, &first, s.me)
	entity, id, ok := kboot.boot_owned_entity(&b, PROBE_TYPE, s.me)
	testing.expect(t, ok)
	testing.expect_value(t, id, knet.Net_Id(11))
	testing.expect_value(t, cast(^Probe)entity, &first)

	// The normal dev build stops loudly at the ambiguity assertion. The
	// release build still has to reject instead of degrading to first-match;
	// tests/kitboot/run.sh runs this package once each way.
	when ODIN_DISABLE_ASSERT {
		second := Probe{value = 20}
		boot_census_insert(&s, &b, 12, &second, s.me)
		ambiguous, ambiguous_id, singular := kboot.boot_owned_entity(&b, PROBE_TYPE, s.me)
		testing.expect(t, !singular)
		testing.expect_value(t, ambiguous, rawptr(nil))
		testing.expect_value(t, ambiguous_id, knet.NET_ID_INVALID)
	}
}
