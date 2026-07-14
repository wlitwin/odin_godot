package kit_sim

// Discrete verbs on the sim lane — @(gd_command) on a ticking class.
//
// A verb is everything an input bit isn't: it carries ARGUMENTS, it can be
// REJECTED, and it fires once. But its effects may live in predicted fields
// — state the resim re-derives every reconcile — so the coop loop's
// optimistic-apply + revert-buffer and the lane's rewind + replay would
// fight over one baseline. The resolution is ONE ARBITER: the verb becomes
// part of the tick timeline.
//
//   * The issuer schedules it at its next local tick T and ships it
//     reliably, tick-stamped. The client's lead exists precisely so
//     tick-stamped things arrive before the server simulates T; a late
//     arrival (a lag spike) executes at the server's next tick instead —
//     history is never rewritten.
//   * Both sides execute INSIDE the tick pipeline, after entity thunks and
//     before the world pass: ticks integrate, verbs mutate the settled
//     state, the world pass adjudicates.
//   * The verb's body runs ONCE per peer. On the client's live pass its
//     predicted-field footprint is captured as a PATCH (changed fields +
//     post bytes); resims re-APPLY the patch instead of re-running the
//     verb — a replayed predicate would read anachronistic delta-lane
//     state (the gold it already spent) and re-fire delta-lane writes.
//   * Delta-lane writes are speculated under a REVERT buffer (the coop
//     discipline, scoped to the non-predicted subset): a rejection or a
//     timeout restores them, and the next reconcile scrubs the predicted
//     half. The server's verdict rides the reliable channel.
//
// V1 rules, enforced both ends: a client may only command entities it OWNS
// (predicted-self — the shop buys YOUR boots), and one verb may be pending
// per entity at a time. Both are the shapes a first consumer needs;
// loosening either is a wire-compatible follow-up.

import "core:mem"
import knet "godot:kit/net"
import ksess "godot:kit/session"

// Generated per verb: decode args, run the verb (and its `_apply` half when
// declared), fire its `_then` on the authority at execution time. Returns
// the verb's verdict.
Cmd_Exec :: proc(entity: rawptr, args: []u8, lane: ^Lane, by: knet.Player_Id) -> bool

// The verb's PREDICTED-EFFECT half, when the game declares `<verb>_apply`:
// pure (ledgered args, predicted fields), re-run by every resim with the
// CORRECTED pre-state — which makes relative effects (an impulse) exact
// where the recorded-bytes patch would re-pin stale absolutes. With an
// apply half, the verb itself keeps its hands off predicted fields: the
// predicate and the delta-lane writes stay execute-once.
Cmd_Apply :: proc(entity: rawptr, args: []u8, lane: ^Lane)

Sim_Cmd :: struct {
	exec:  Cmd_Exec,
	apply: Cmd_Apply, // nil = patch mode (recorded post-bytes replay)
}

// How long a command may sit unanswered before the client treats silence as
// rejection and restores its revert buffer, in ledger slots (ticks).
CMD_EXPIRE_SLOTS :: 128

// The most scheduled-but-unexecuted commands the host will hold per player
// — an untrusted-input cap, far above any honest burst.
CMD_HOST_CAP :: 16

Cmd_Verdict :: enum u8 {
	Pending,
	Accepted,
	Rejected,
}

// A client's issued command: the ledger entry resims replay from.
@(private)
Cmd_Out :: struct {
	seq:      u32,
	tick:     u64, // local execution tick
	id:       knet.Net_Id,
	idx:      u16, // index into the entity's Sim_Set.commands
	args:     []u8, // owned
	executed: bool,
	ok:       bool, // the LOCAL predicate's verdict (apply-mode resims gate on it)
	mask:     u64, // predict-subset ordinals the verb changed
	patch:    []u8, // their post-exec bytes, packed (owned)
	revert:   []u8, // delta-subset capture from before the exec (owned)
	verdict:  Cmd_Verdict,
}

// A host-side scheduled command, executed at `tick` inside run_tick.
@(private)
Cmd_In :: struct {
	tick: u64,
	from: knet.Player_Id,
	seq:  u32,
	id:   knet.Net_Id,
	idx:  u16,
	args: []u8, // owned
}

// ---------------------------------------------------------------------------
// The delta subset — replicated fields that are neither predicted nor
// owner-streamed: what a speculative verb may write OUTSIDE the resim's
// jurisdiction, and therefore what a rejection must put back.

delta_lane_size :: proc(desc: ^knet.Entity_Desc) -> int {
	n := 0
	for f in desc.fields {
		if .Predicted in f.flags || .Owner_Stream in f.flags {
			continue
		}
		n += f.size
	}
	return n
}

delta_lane_capture :: proc(dst: []u8, entity: rawptr, desc: ^knet.Entity_Desc) {
	off := 0
	for f in desc.fields {
		if .Predicted in f.flags || .Owner_Stream in f.flags {
			continue
		}
		mem.copy(&dst[off], rawptr(uintptr(entity) + f.offset), f.size)
		off += f.size
	}
}

delta_lane_restore :: proc(entity: rawptr, desc: ^knet.Entity_Desc, src: []u8) {
	off := 0
	for f in desc.fields {
		if .Predicted in f.flags || .Owner_Stream in f.flags {
			continue
		}
		mem.copy(rawptr(uintptr(entity) + f.offset), &src[off], f.size)
		off += f.size
	}
}

// ---------------------------------------------------------------------------
// The predicted-field patch: which predict-subset fields a live execution
// changed (a bit per subset ordinal) and their post-exec bytes, packed in
// subset order. Absolute values by design — replays write what the verb
// wrote; recommend absolute-style mutations (gear = BOOTS) over relative
// ones for predicted fields a verb touches.

// Diff the entity's live predict set against `pre` (its capture from before
// the exec). Returns the mask and the packed changed bytes' length; `dst`
// is caller-sized to predict_size.
cmd_patch_diff :: proc(dst: []u8, pre: []u8, entity: rawptr, desc: ^knet.Entity_Desc) -> (mask: u64, n: int) {
	off, ord := 0, u32(0)
	for f in desc.fields {
		if .Predicted not_in f.flags {
			continue
		}
		ep := ([^]u8)(rawptr(uintptr(entity) + f.offset))
		if mem.compare(ep[:f.size], pre[off:off + f.size]) != 0 {
			mask |= u64(1) << ord
			copy(dst[n:], ep[:f.size])
			n += f.size
		}
		off += f.size
		ord += 1
	}
	return mask, n
}

cmd_patch_apply :: proc(entity: rawptr, desc: ^knet.Entity_Desc, mask: u64, patch: []u8) {
	n, ord := 0, u32(0)
	for f in desc.fields {
		if .Predicted not_in f.flags {
			continue
		}
		if mask & (u64(1) << ord) != 0 {
			mem.copy(rawptr(uintptr(entity) + f.offset), raw_data(patch[n:]), f.size)
			n += f.size
		}
		ord += 1
	}
}

// ---------------------------------------------------------------------------
// The driver half: issue, wire, execute, verdict, retire.

@(private)
cmd_out_free :: proc(c: ^Cmd_Out) {
	delete(c.args)
	delete(c.patch)
	delete(c.revert)
}

@(private)
cmd_tracked :: proc(l: ^Lane, id: knet.Net_Id) -> ^Tracked {
	for &tr in l.tracked {
		if tr.id == id {
			return &tr
		}
	}
	return nil
}

// Issue verb `idx` of entity `id` with encoded `args` — the generated
// `<verb>_cmd` wrapper's target; games never call this raw. Schedules the
// execution at the next local tick (host and client alike — live and
// replay must agree on WHEN), ships it tick-stamped on the reliable
// channel, and returns whether it was scheduled: the VERDICT is state, not
// a return value (watch the fields, or the authority's `_then`).
lane_command :: proc(l: ^Lane, id: knet.Net_Id, idx: u16, args: []u8) -> bool {
	tr := cmd_tracked(l, id)
	if tr == nil || tr.cmds == nil || int(idx) >= len(tr.cmds) {
		return false
	}
	if l.ses.is_host {
		// The authority's own verb: schedule at the next tick, no wire, no
		// speculation — its execution IS the truth.
		queued := make([]u8, len(args))
		copy(queued, args)
		append(&l.cmd_in, Cmd_In{tick = l.ticker.tick + 1, from = l.ses.me, id = id, idx = idx, args = queued})
		return true
	}
	// Predicted-HERE only: my own entities, and contested ones (on my
	// prediction ledger by construction — a verb on the ball speculates
	// exactly like a touch does). Watched entities can't speculate: their
	// fields belong to the presenter; command them from the authority, or
	// promote them to contested.
	if !l.anchored || tr.hist == nil || (tr.owner != l.ses.me && !tr.contested) {
		return false
	}
	pending := 0
	for c in l.cmd_out {
		if c.verdict == .Pending {
			pending += 1
		}
	}
	if pending >= CMD_HOST_CAP {
		return false // mirror the host's cap — an honest burst never queues this deep
	}
	owned := make([]u8, len(args))
	copy(owned, args)
	l.cmd_seq += 1
	append(&l.cmd_out, Cmd_Out{seq = l.cmd_seq, tick = l.ticker.tick + 1, id = id, idx = idx, args = owned})
	w := ksess.session_app_begin(l.ses, l.tag)
	knet.write_u8(w, SIM_CMD)
	knet.write_u32(w, l.cmd_seq)
	knet.write_u64(w, l.ticker.tick + 1)
	knet.write_u32(w, u32(id))
	knet.write_u16(w, idx)
	knet.write_bytes(w, args)
	ksess.session_app_flush(l.ses, ksess.HOST_PEER) // reliable: verbs are one-shots
	return true
}

// Host: file an arriving SIM_CMD (handler discipline — no game code here).
@(private)
cmd_handle :: proc(l: ^Lane, from: knet.Player_Id, r: ^knet.Reader) {
	seq := knet.read_u32(r)
	tick := knet.read_u64(r)
	id := knet.Net_Id(knet.read_u32(r))
	idx := knet.read_u16(r)
	args := knet.read_bytes(r)
	if r.err {
		return
	}
	tr := cmd_tracked(l, id)
	if tr == nil || tr.cmds == nil || int(idx) >= len(tr.cmds) {
		return
	}
	// The cheat gate: your verbs move YOUR entities — or CONTESTED ones,
	// where any seat's touch is legitimate and the predicate arbitrates
	// (two grabs the same tick: arrival order runs them, one wins).
	contested_type := tr.set != nil && tr.set.contested
	if tr.owner != from && !contested_type {
		return
	}
	held := 0
	for c in l.cmd_in {
		if c.from == from {
			held += 1
		}
	}
	if held >= CMD_HOST_CAP {
		return // untrusted-input cap; an honest client never queues this deep
	}
	queued := make([]u8, len(args))
	copy(queued, args)
	// Late arrivals (a lag spike outran the lead) execute at the next tick —
	// history is never rewritten; the client's reconcile absorbs the slip.
	at := max(tick, l.ticker.tick + 1)
	append(&l.cmd_in, Cmd_In{tick = at, from = from, seq = seq, id = id, idx = idx, args = queued})
}

// Client: the authority answered (handler discipline — file it; the revert
// itself waits for the frame, where all game-state mutation lives).
@(private)
cmd_handle_verdict :: proc(l: ^Lane, r: ^knet.Reader) {
	seq := knet.read_u32(r)
	ok := knet.read_u8(r)
	if r.err {
		return
	}
	for &c in l.cmd_out {
		if c.seq == seq && c.verdict == .Pending {
			c.verdict = ok != 0 ? Cmd_Verdict.Accepted : Cmd_Verdict.Rejected
			return
		}
	}
}

// Inside run_tick, after entity thunks and before the world pass: ticks
// integrate, verbs mutate the settled state, the world pass adjudicates.
@(private)
run_cmds :: proc(l: ^Lane, t: u64) {
	if l.ses.is_host {
		for i := 0; i < len(l.cmd_in); {
			c := &l.cmd_in[i]
			if c.tick != t {
				i += 1
				continue
			}
			if tr := cmd_tracked(l, c.id); tr != nil && tr.cmds != nil && int(c.idx) < len(tr.cmds) {
				ok := tr.cmds[c.idx].exec(tr.entity, c.args, l, c.from)
				if c.from != l.ses.me {
					if p, seated := ksess.session_player(l.ses, c.from); seated && p.peer != ksess.NO_PEER {
						w := ksess.session_app_begin(l.ses, l.tag)
						knet.write_u8(w, SIM_VERDICT)
						knet.write_u32(w, c.seq)
						knet.write_u8(w, ok ? 1 : 0)
						ksess.session_app_flush(l.ses, p.peer)
					}
				}
			}
			delete(c.args)
			ordered_remove(&l.cmd_in, i)
		}
		return
	}
	for &c in l.cmd_out {
		if c.tick != t {
			continue
		}
		tr := cmd_tracked(l, c.id)
		if tr == nil || tr.hist == nil {
			continue // untracked (or demoted) since issue: nothing to patch
		}
		if !l.resimming && !c.executed {
			// The live pass: run the verb ONCE, bracketed by captures — the
			// delta-lane revert for a rejection, the predicted-field patch
			// (or the apply half) for every replay after this one.
			c.executed = true
			cmd_exec_local(l, &c, tr, l.ses.me)
		} else if l.resimming && c.executed && c.verdict != .Rejected {
			if ap := tr.cmds[c.idx].apply; ap != nil {
				if c.ok {
					ap(tr.entity, c.args, l) // exact: re-run with corrected pre-state
				}
			} else if c.mask != 0 {
				cmd_patch_apply(tr.entity, tr.desc, c.mask, c.patch)
			}
		}
	}
}

// One speculative execution, capture-bracketed. `re` re-executions (the
// chain's replay after an earlier rejection) discard the predicted-field
// writes — the resims rebuild those from the fresh patch/apply — but keep
// the delta-lane ones: they ARE the re-applied speculation.
@(private = "file")
cmd_exec_local :: proc(l: ^Lane, c: ^Cmd_Out, tr: ^Tracked, me: knet.Player_Id, re := false) {
	if n := delta_lane_size(tr.desc); n > 0 {
		if c.revert == nil {
			c.revert = make([]u8, n)
		}
		delta_lane_capture(c.revert, tr.entity, tr.desc)
	}
	pre := make([]u8, tr.hist.size, context.temp_allocator)
	predict_capture(pre, tr.entity, tr.desc)
	c.mask = 0
	delete(c.patch)
	c.patch = nil
	c.ok = tr.cmds[c.idx].exec(tr.entity, c.args, l, me)
	if c.ok && tr.cmds[c.idx].apply == nil {
		scratch := make([]u8, tr.hist.size, context.temp_allocator)
		mask, n := cmd_patch_diff(scratch, pre, tr.entity, tr.desc)
		if n > 0 {
			c.mask = mask
			c.patch = make([]u8, n)
			copy(c.patch, scratch[:n])
		}
	}
	if re {
		// Off-tick re-execution: predicted fields go back to what the frame
		// held; the effect lands through the next resim like everything else.
		predict_restore(tr.entity, tr.desc, pre)
	}
	// A locally-false verb wrote nothing (check-then-mutate is the verb
	// contract) — the entry stays for the server's word anyway: ITS state
	// may say yes, and truth will carry the effect.
}

// Client, once per frame (outside the tick loop): land rejections and
// timeouts. The predicted half is self-healing — a rejected entry simply
// stops replaying and the next reconcile rebuilds predicted state from the
// survivors — but the DELTA-lane revert stack must unwind in order: a later
// speculation's revert buffer captured the earlier one's writes, so a lone
// restore would clobber it. On a rejection: restore reverts newest→rejected
// for that entity, drop the rejected one, re-execute the survivors in seq
// order (fresh reverts, fresh patches; predicted writes discarded — the
// resim rebuilds them).
@(private)
cmd_settle :: proc(l: ^Lane) {
	for i := 0; i < len(l.cmd_out); i += 1 {
		c := &l.cmd_out[i]
		if c.verdict == .Pending && c.executed && l.ticker.tick > c.tick + CMD_EXPIRE_SLOTS {
			c.verdict = .Rejected // silence past the horizon = a lost seat or a dead host
		}
		if c.verdict != .Rejected || !c.executed {
			continue
		}
		tr := cmd_tracked(l, c.id)
		if tr == nil || tr.hist == nil {
			c.executed = false
			c.mask = 0
			continue // untracked since issue: nothing to unwind into
		}
		// Survivors: executed entries for the SAME entity issued after this
		// one (seq order == issue order == capture order).
		later := make([dynamic]^Cmd_Out, context.temp_allocator)
		for &o in l.cmd_out {
			if o.id == c.id && o.executed && o.seq > c.seq && o.verdict != .Rejected {
				append(&later, &o)
			}
		}
		for j := len(later) - 1; j >= 0; j -= 1 {
			if later[j].revert != nil {
				delta_lane_restore(tr.entity, tr.desc, later[j].revert)
			}
		}
		if c.revert != nil {
			delta_lane_restore(tr.entity, tr.desc, c.revert)
		}
		c.executed = false
		c.mask = 0
		c.ok = false
		for o in later {
			cmd_exec_local(l, o, tr, l.ses.me, re = true)
		}
	}
}

// Client, after a reconcile anchored authoritative tick `auth`: entries at
// or before it are settled history — resims never revisit them. Accepted
// effects live in truth now; a rejected entry retires only once cmd_settle
// has landed its revert (executed drops to false there) — the reconcile
// runs FIRST each frame, and freeing the revert before it runs would eat
// the unwind.
@(private)
cmd_retire :: proc(l: ^Lane, auth: u64) {
	for i := 0; i < len(l.cmd_out); {
		c := &l.cmd_out[i]
		settled := c.verdict == .Accepted || (c.verdict == .Rejected && !c.executed)
		if settled && c.tick <= auth {
			cmd_out_free(c)
			ordered_remove(&l.cmd_out, i)
			continue
		}
		i += 1
	}
}
