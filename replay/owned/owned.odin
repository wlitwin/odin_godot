package replay_owned

import "core:reflect"
import r "godot:replay"

Key :: struct {kind, index, generation: u32}
Scope :: struct {key: Key, epoch, revision: u64}
Sample :: struct($T: typeid) {scope: Scope, sequence, produced: u64, value: T}
Offer :: struct($T: typeid) {owner: u16, revision, offered_at, expires: u64, baseline: T}

// Complete, value-owned arbitration state. Owner zero means no active producer.
State :: struct($T: typeid) {
	key: Key,
	epoch, revision_counter: u64,
	owner: u16,
	revision, discontinuity, active_since, changed_at: u64,
	sequence, produced, accepted_at: u64,
	value: T,
	pending: Offer(T),
}

Rules :: struct($T: typeid) {
	user: rawptr, // immutable policy data, never stored in State
	valid: proc(user: rawptr, value: T) -> bool,
	transition: proc(user: rawptr, before, after: T, elapsed_authority_ticks: u64) -> bool,
}
Error :: enum {None, Not_Ready, Already_Initialized, Invalid_Key, Invalid_Epoch, Invalid_Time, Invalid_Owner, Invalid_Value, Invalid_Transition, Stale_Scope, Stale_Sample, Conflict, Offer_Pending, No_Offer, Expired, Exhausted}
Result :: struct {error: Error, applied, transferred: bool}

key :: proc(kind: u32, handle: r.Handle($T)) -> Key {return {kind, handle.index, handle.generation}}
scope :: proc(s: State($T)) -> Scope {return {s.key, s.epoch, s.revision}}
offer_scope :: proc(s: State($T)) -> Scope {return {s.key, s.epoch, s.pending.revision}}

init :: proc(s: ^State($T), object: Key, epoch, tick: u64, owner: u16, value: T, rules: Rules(T)) -> Error {
	if s.key.generation != 0 {return .Already_Initialized}
	if object.kind == 0 || object.generation == 0 {return .Invalid_Key}
	if epoch == 0 {return .Invalid_Epoch}
	if !r.value_supported(T) || rules.valid == nil || !rules.valid(rules.user, value) {return .Invalid_Value}
	s^ = {key = object, epoch = epoch, revision_counter = 1, owner = owner, revision = 1, discontinuity = 1, active_since = tick, changed_at = tick, accepted_at = tick, value = value}
	return .None
}

valid :: proc(s: State($T), rules: Rules(T)) -> bool {
	if !r.value_supported(T) || s.key.kind == 0 || s.key.generation == 0 || s.epoch == 0 || s.revision == 0 || s.revision > s.revision_counter || s.discontinuity == 0 || s.discontinuity > s.revision ||
	   s.active_since > s.changed_at || s.accepted_at > s.changed_at || s.accepted_at < s.active_since ||
	   rules.valid == nil || !rules.valid(rules.user, s.value) {return false}
	if s.sequence == 0 && (s.produced != 0 || s.accepted_at != s.active_since) {return false}
	if s.owner == 0 && s.sequence != 0 {return false}
	p := s.pending
	if p.revision == 0 {zero: T; return p.owner == 0 && p.offered_at == 0 && p.expires == 0 && reflect.equal(p.baseline, zero)}
	return p.owner != 0 && p.owner != s.owner && p.revision > s.revision && p.revision <= s.revision_counter &&
	       p.offered_at >= s.active_since && p.offered_at <= s.changed_at && p.expires > p.offered_at && rules.valid(rules.user, p.baseline)
}

// Structural validation for an upstream control codec. A zero sample is a
// canonical empty slot; nonempty samples still require state/owner admission.
sample_valid :: proc(sample: Sample($T), rules: Rules(T)) -> bool {
	if !r.value_supported(T) {return false}
	if sample.sequence == 0 {zero: T; return sample.scope == Scope{} && sample.produced == 0 && reflect.equal(sample.value, zero)}
	return sample.scope.key.kind != 0 && sample.scope.key.generation != 0 && sample.scope.epoch != 0 && sample.scope.revision != 0 &&
	       rules.valid != nil && rules.valid(rules.user, sample.value)
}

// Authority-side offer. The current owner remains active until a valid sample
// commits the reserved revision. Cancellation/expiry never reuses a revision.
offer :: proc(s: ^State($T), owner: u16, tick, ttl: u64) -> Error {
	if err := at_time(s, tick); err != .None {return err}
	if owner == 0 || owner == s.owner {return .Invalid_Owner}
	if s.pending.revision != 0 {return .Offer_Pending}
	if ttl == 0 || ttl > max(u64) - tick {return .Invalid_Time}
	if s.revision_counter == max(u64) {return .Exhausted}
	s.revision_counter += 1
	s.pending = {owner, s.revision_counter, tick, tick + ttl, s.value}
	s.changed_at = tick
	return .None
}

cancel :: proc(s: ^State($T), tick: u64) -> Error {
	if err := at_time(s, tick); err != .None {return err}
	if s.pending.revision == 0 {return .No_Offer}
	s.pending = {}; s.changed_at = tick
	return .None
}

expire :: proc(s: ^State($T), tick: u64) -> bool {
	if s.pending.revision == 0 || tick < s.pending.expires || at_time(s, tick) != .None {return false}
	s.pending = {}; s.changed_at = tick
	return true
}

// Explicit teleport/reset, revocation or administrative reassignment. Preserves
// the caller-specified complete value and invalidates every previous scope.
cut :: proc(s: ^State($T), owner: u16, value: T, tick: u64, rules: Rules(T)) -> Error {
	if err := at_time(s, tick); err != .None {return err}
	if rules.valid == nil || !rules.valid(rules.user, value) {return .Invalid_Value}
	if s.revision_counter == max(u64) {return .Exhausted}
	s.revision_counter += 1
	s.owner, s.revision, s.active_since, s.changed_at, s.accepted_at = owner, s.revision_counter, tick, tick, tick
	s.discontinuity = s.revision
	s.sequence, s.produced, s.value, s.pending = 0, 0, value, {}
	return .None
}

// A new fenced authority epoch invalidates old observations and pending offers
// while preserving the checkpoint's complete value and reserved current owner.
bind_epoch :: proc(s: ^State($T), epoch, tick: u64) -> Error {
	if err := at_time(s, tick); err != .None {return err}
	if epoch == s.epoch {return .None}
	if epoch < s.epoch {return .Invalid_Epoch}
	if s.revision_counter == max(u64) {return .Exhausted}
	s.epoch, s.revision_counter = epoch, s.revision_counter + 1
	s.revision, s.active_since, s.changed_at, s.accepted_at = s.revision_counter, tick, tick, tick
	s.discontinuity = s.revision
	s.sequence, s.produced, s.pending = 0, 0, {}
	return .None
}

// Sender is supplied by authenticated transport/session ownership, never by the
// sample. Rejected/duplicate samples leave the complete state unchanged.
accept :: proc(s: ^State($T), sender: u16, sample: Sample(T), tick: u64, rules: Rules(T)) -> Result {
	if err := at_time(s, tick); err != .None {return {error = err}}
	if sample.scope.key != s.key || sample.scope.epoch != s.epoch {return {error = .Stale_Scope}}
	current := sample.scope.revision == s.revision
	proposed := s.pending.revision != 0 && sample.scope.revision == s.pending.revision
	if !current && !proposed {return {error = .Stale_Scope}}
	if sender == 0 || sender != (proposed ? s.pending.owner : s.owner) {return {error = .Invalid_Owner}}
	if proposed && tick >= s.pending.expires {return {error = .Expired}}
	if sample.sequence == 0 {return {error = .Stale_Sample}}
	if current {
		if sample.sequence < s.sequence {return {error = .Stale_Sample}}
		if sample.sequence == s.sequence {
			if sample.produced != s.produced || !reflect.equal(sample.value, s.value) {return {error = .Conflict}}
			return {}
		}
		if sample.produced < s.produced {return {error = .Invalid_Time}}
	}
	if rules.valid == nil || !rules.valid(rules.user, sample.value) {return {error = .Invalid_Value}}
	before := proposed ? s.pending.baseline : s.value
	elapsed := tick - (proposed ? s.pending.offered_at : s.accepted_at)
	if rules.transition != nil && !rules.transition(rules.user, before, sample.value, elapsed) {return {error = .Invalid_Transition}}
	if proposed {
		s.owner, s.revision, s.active_since = sender, s.pending.revision, tick
		s.pending = {}
	}
	s.value, s.sequence, s.produced, s.accepted_at, s.changed_at = sample.value, sample.sequence, sample.produced, tick, tick
	return {applied = true, transferred = proposed}
}

@(private)
at_time :: proc(s: ^State($T), tick: u64) -> Error {
	if s.key.kind == 0 || s.key.generation == 0 || s.epoch == 0 || s.revision == 0 {return .Not_Ready}
	return tick < s.changed_at ? .Invalid_Time : .None
}
