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
// The rules, enforced both ends: owner access is the default; a verb declaring
// `any_seat` accepts any playing seat, and `authority` never crosses ingress.
// Prediction scope and command authority are separate questions: a contested
// open verb speculates, while a watched open verb is still issuable but waits
// for authority state. Marking a class contested (which predict-world does to
// every avatar) never silently opens its verbs to every seat.
// Bursts chain per entity (cmd_settle re-executes survivors in seq order);
// the per-player pending cap is an untrusted-input bound, not a rule.

import "core:mem"
import knet "godot:kit/net"
import ksess "godot:kit/session"

// Generated per verb: decode args, run the verb (and its `_apply` half when
// declared), fire its `_then` on the authority at execution time. Returns
// the verb's verdict.
Cmd_Exec :: proc(entity: rawptr, args: []u8, lane: ^Lane, by: knet.Player_Id) -> bool

// Generated verbs use the detailed form so decode failures stay distinct from
// gameplay predicate failures. `exec` above remains for hand-built tables; the
// runtime maps its false result to Predicate.
Cmd_Exec_Checked :: proc(
	entity: rawptr,
	args: []u8,
	lane: ^Lane,
	by: knet.Player_Id,
) -> knet.Action_Reject_Reason

// The verb's PREDICTED-EFFECT half, when the game declares `<verb>_apply`:
// pure (ledgered args, predicted fields), re-run by every resim with the
// CORRECTED pre-state — which makes relative effects (an impulse) exact
// where the recorded-bytes patch would re-pin stale absolutes. With an
// apply half, the verb itself keeps its hands off predicted fields: the
// predicate and the delta-lane writes stay execute-once.
Cmd_Apply :: proc(entity: rawptr, args: []u8, lane: ^Lane)

// A sim verb's wire id. THE ID LAW lives at knet.Command_Desc.id (scriptgen's
// cmd_wire_id implements it) — this mirrors it for the tick-scheduled lane.
// Distinct from knet.Cmd_Id: a coop command id and a sim verb id flow through
// near-identical issue shapes (knet.command_issue vs lane_command), so the
// distinct types stop a game holding both from feeding one namespace's id to
// the other's proc. Wire bytes unchanged — lane_command still writes u16(id).
Cmd_Id :: distinct u16

// A client's issued-command sequence number, unique per issuer on this lane —
// mirroring knet.Intent_Seq's precedent for the coop loop. u32, ~4 billion
// verbs per session. Wire bytes unchanged: the encoders still write u32(seq).
Cmd_Seq :: distinct u32

Sim_Cmd :: struct {
	// The same callback-free descriptor embedded by knet.Command_Desc. Only the
	// execution callbacks below differ between the two models.
	using action: knet.Action_Desc(Cmd_Id),
	exec:         Cmd_Exec, // compatibility bool thunk (nil when exec_checked is generated)
	exec_checked: Cmd_Exec_Checked,
	apply:        Cmd_Apply, // nil = patch mode (recorded post-bytes replay)
}

@(private)
sim_cmd_execute :: proc(
	cmd: ^Sim_Cmd,
	entity: rawptr,
	args: []u8,
	lane: ^Lane,
	by: knet.Player_Id,
) -> knet.Action_Reject_Reason {
	if cmd.exec_checked != nil {
		return cmd.exec_checked(entity, args, lane, by)
	}
	if cmd.exec == nil {
		return .Malformed
	}
	return cmd.exec(entity, args, lane, by) ? .None : .Predicate
}

// id → slot in the entity's command slice (-1 = unknown id: reject). Sets are
// a handful of verbs — a scan beats any table.
@(private)
sim_cmd_find :: proc(cmds: []Sim_Cmd, id: Cmd_Id) -> int {
	for c, i in cmds {
		if c.id == id {
			return i
		}
	}
	return -1
}

// How long a command may sit unanswered before the client treats silence as
// rejection and restores its revert buffer: the LANE'S ring depth (l.slots)
// — past that horizon the entry can't reconcile anyway. (This was a fixed
// 128 regardless of cfg.slots: a deeper ring expired commands it could
// still have settled; a shallower one held reverts it could no longer use.)

// The most scheduled-but-unexecuted commands the host will hold per player
// — an untrusted-input cap, far above any honest burst.
CMD_HOST_CAP :: 16

// Tick verbs are small intent tuples, not an upload channel. The generated
// encoders normally emit a handful of scalar bytes; this generous ceiling
// bounds the authority's clone/allocation even for hand-written commands.
CMD_ARGS_MAX :: knet.ACTION_ARGS_DEFAULT

// The internal ledger state of an issued verb — deliberately NOT knet's
// Action_Outcome. Its state is the ISSUE WRAPPER'S game-facing return
// (Rejected/Predicted/Applied); this is a Cmd_Out's private in-flight state
// (Pending until the host answers). The member sets differ and don't merge —
// notably a sim verb NEVER returns .Applied (even the host's own issue runs at
// the stamped tick, never inline: ".Applied is a coop-loop word"), so the two
// vocabularies name different things at different layers. Neither crosses the
// wire: SIM_VERDICT ships an Action_Reject_Reason, decoded into the private
// Accepted/Rejected state here.
Cmd_Verdict :: enum u8 {
	Pending,
	Accepted,
	Rejected,
}

// A client's issued command: the ledger entry resims replay from.
@(private)
Cmd_Out :: struct {
	seq:          Cmd_Seq,
	tick:         u64, // local execution tick
	issued_clock: u64, // lane-frame clock; keeps timeout moving when sim ticks stall
	id:           knet.Net_Id,
	cmd:          Cmd_Id, // the verb's stable wire id (Sim_Cmd.id — resolved by lookup, never a position)
	args:         []u8, // owned
	executed:     bool,
	ok:           bool, // the LOCAL predicate's verdict (apply-mode resims gate on it)
	mask:         u64, // predict-subset ordinals the verb changed
	patch:        []u8, // their post-exec bytes, packed (owned)
	revert:       []u8, // delta-subset capture from before the exec (owned)
	verdict:      Cmd_Verdict,
	reason:       knet.Action_Reject_Reason,
	notified:     bool,
}

// A host-side scheduled command, executed at `tick` inside run_tick.
@(private)
Cmd_In :: struct {
	tick: u64,
	from: knet.Player_Id,
	seq:  Cmd_Seq,
	id:   knet.Net_Id,
	cmd:  Cmd_Id, // the verb's stable wire id (Sim_Cmd.id)
	args: []u8, // owned
}

// ---------------------------------------------------------------------------
// The delta subset — replicated fields that are neither predicted nor
// owner-streamed: what a speculative verb may write OUTSIDE the resim's
// jurisdiction, and therefore what a rejection must put back.

delta_lane_size :: proc(desc: ^knet.Entity_Desc) -> int {
	return knet.subset_view(desc, .Delta).struct_bytes
}

delta_lane_capture :: proc(dst: []u8, entity: rawptr, desc: ^knet.Entity_Desc) {
	knet.subset_capture(knet.subset_view(desc, .Delta), entity, dst)
}

delta_lane_restore :: proc(entity: rawptr, desc: ^knet.Entity_Desc, src: []u8) {
	knet.subset_restore(knet.subset_view(desc, .Delta), entity, src)
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
cmd_patch_diff :: proc(
	dst: []u8,
	pre: []u8,
	entity: rawptr,
	desc: ^knet.Entity_Desc,
) -> (
	mask: u64,
	n: int,
) {
	v := knet.subset_view(desc, .Predicted)
	for e, ord in v.entries {
		f := v.fields[e.field]
		off := int(e.struct_off)
		ep := ([^]u8)(rawptr(uintptr(entity) + f.offset))
		if mem.compare(ep[:f.size], pre[off:off + f.size]) != 0 {
			mask |= u64(1) << u32(ord)
			copy(dst[n:], ep[:f.size])
			n += f.size
		}
	}
	return mask, n
}

cmd_patch_apply :: proc(entity: rawptr, desc: ^knet.Entity_Desc, mask: u64, patch: []u8) {
	v := knet.subset_view(desc, .Predicted)
	n := 0
	for e, ord in v.entries {
		f := v.fields[e.field]
		if mask & (u64(1) << u32(ord)) != 0 {
			mem.copy(rawptr(uintptr(entity) + f.offset), raw_data(patch[n:]), f.size)
			n += f.size
		}
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

Lane_Command_Result :: struct {
	scheduled: bool,
	reason:    knet.Action_Reject_Reason,
	seq:       Cmd_Seq,
}

// Detailed issue result for generated wrappers. The final authority verdict is
// delivered through the same session command callbacks as co-op actions.
lane_command_checked :: proc(
	l: ^Lane,
	id: knet.Net_Id,
	cmd: Cmd_Id,
	args: []u8,
) -> Lane_Command_Result {
	context.allocator = l.allocator // the owned arg copies free under lane roots later
	tr := cmd_tracked(l, id)
	if tr == nil || tr.cmds == nil {
		return {reason = .Stale}
	}
	slot := sim_cmd_find(tr.cmds, cmd)
	if slot < 0 {
		return {reason = .Malformed}
	}
	policy := tr.cmds[slot].policy
	if !knet.action_args_allowed(policy, len(args)) {
		return {reason = .Malformed}
	}
	if l.ses.is_host {
		// The authority's own verb: schedule at the next tick, no wire, no
		// speculation — its execution IS the truth.
		queued := make([]u8, len(args))
		copy(queued, args)
		append(
			&l.cmd_in,
			Cmd_In{tick = l.ticker.tick + 1, from = l.ses.me, id = id, cmd = cmd, args = queued},
		)
		return {scheduled = true}
	}
	// Access and prediction are separate. Owner refuses a non-owner locally;
	// Authority never crosses the wire; Any_Seat may target a watched object
	// (it simply has no local ledger on which to speculate before truth lands).
	if !l.anchored {
		return {reason = .Stale}
	}
	if !knet.action_access_allows(policy, l.ses.me, tr.owner, false) {
		return {reason = .Access}
	}
	pending := 0
	for c in l.cmd_out {
		if c.verdict == .Pending {
			pending += 1
		}
	}
	if pending >= CMD_HOST_CAP {
		return {reason = .Rate} // mirror the host's cap — an honest burst never queues this deep
	}
	if l.cmd_seq == Cmd_Seq(max(u32)) {
		// Never wrap to zero or into the authority's replay window. Four billion
		// commands is a session-lifetime boundary, not a sequence-reset protocol.
		return {reason = .Stale}
	}
	owned := make([]u8, len(args))
	copy(owned, args)
	l.cmd_seq += 1
	append(
		&l.cmd_out,
		Cmd_Out {
			seq = l.cmd_seq,
			tick = l.ticker.tick + 1,
			issued_clock = l.cmd_clock,
			id = id,
			cmd = cmd,
			args = owned,
		},
	)
	w := ksess.session_app_begin(l.ses, l.tag)
	knet.write_u8(w, SIM_CMD)
	knet.write_u32(w, u32(l.cmd_seq)) // wire bytes unchanged: seq crosses as a plain u32
	knet.write_u64(w, l.ticker.tick + 1)
	knet.write_net_id(w, id)
	knet.write_u16(w, u16(cmd)) // wire bytes unchanged: the id crosses as a plain u16
	knet.write_bytes(w, args)
	ksess.session_app_flush(l.ses, ksess.HOST_PEER) // reliable: verbs are one-shots
	return {scheduled = true, seq = l.cmd_seq}
}

// Compatibility escape hatch for hand-written callers.
lane_command :: proc(l: ^Lane, id: knet.Net_Id, cmd: Cmd_Id, args: []u8) -> bool {
	return lane_command_checked(l, id, cmd, args).scheduled
}

@(private)
cmd_send_verdict :: proc(
	l: ^Lane,
	to: knet.Player_Id,
	seq: Cmd_Seq,
	reason: knet.Action_Reject_Reason,
) {
	if to == l.ses.me {
		return
	}
	if p, seated := ksess.session_player(l.ses, to);
	   seated && p.connected && p.peer != ksess.NO_PEER {
		w := ksess.session_app_begin(l.ses, l.tag)
		knet.write_u8(w, SIM_VERDICT)
		knet.write_u32(w, u32(seq))
		knet.write_u8(w, u8(reason))
		ksess.session_app_flush(l.ses, p.peer)
	}
}

@(private)
cmd_refuse :: proc(
	l: ^Lane,
	from: knet.Player_Id,
	seq: Cmd_Seq,
	reason: knet.Action_Reject_Reason,
	id: knet.Net_Id,
	cmd: Cmd_Id,
) {
	assert(reason != .None)
	l.stat_cmd_rejected += 1
	cmd_send_verdict(l, from, seq, reason)
	ksess.session_action_executed(l.ses, .Scheduled, u32(seq), from, id, u16(cmd), reason)
}

// Access is checked on arrival AND at execution: a reliable command may sit
// queued while its issuer disconnects, becomes a spectator, or loses ownership.
@(private)
cmd_authorized :: proc(l: ^Lane, from: knet.Player_Id, tr: ^Tracked, slot: int) -> bool {
	if from == l.ses.me {
		return true // an authority-authored verb is already inside the trust boundary
	}
	p, seated := ksess.session_player(l.ses, from)
	if !seated || !p.connected || p.spectator || slot < 0 || slot >= len(tr.cmds) {
		return false
	}
	return knet.action_access_allows(tr.cmds[slot].policy, from, tr.owner, false)
}

// Any tick-scheduled verb still in flight on this entity? The session's
// write guard exempts such an entity: the verb's speculative delta-lane
// writes are legal until the entry retires (cmd_retire blesses it then).
// kboot.boot_lane installs this as the session's guard exemption.
lane_cmd_inflight :: proc(l: ^Lane, id: knet.Net_Id) -> bool {
	for c in l.cmd_out {
		if c.id == id {
			return true
		}
	}
	return false
}

// Host: file an arriving SIM_CMD (handler discipline — no game code here).
@(private)
cmd_handle :: proc(l: ^Lane, from: knet.Player_Id, from_peer: ksess.Peer_Id, r: ^knet.Reader) {
	seq := Cmd_Seq(knet.read_u32(r))
	tick := knet.read_u64(r)
	id := knet.read_net_id(r)
	cmd := Cmd_Id(knet.read_u16(r))
	args := knet.read_bytes_limited(r, knet.ACTION_ARGS_MAX)
	tr := cmd_tracked(l, id)
	slot := tr != nil && tr.cmds != nil ? sim_cmd_find(tr.cmds, cmd) : -1
	policy := knet.Action_Policy{}
	owner := knet.PLAYER_ID_INVALID
	if tr != nil {
		owner = tr.owner
		if slot >= 0 {
			policy = tr.cmds[slot].policy
		}
	}
	held := 0
	for c in l.cmd_in {
		if c.from == from {
			held += 1
		}
	}
	decision := ksess.session_authority_action_admit(
		l.ses,
		ksess.Authority_Action_Request {
			model = .Scheduled,
			player = from,
			peer = from_peer,
			seq = u32(seq),
			entity = id,
			action = u16(cmd),
			packet_bytes = len(r.data),
			payload_valid = !r.err && len(knet.reader_remaining(r)) == 0,
			target_exists = tr != nil,
			action_exists = slot >= 0,
			owner = owner,
			policy = policy,
			args_bytes = len(args),
			args_valid = slot >= 0 && knet.action_args_allowed(policy, len(args)),
			has_tick = true,
			tick = tick,
			authority_tick = l.ticker.tick,
			max_future_tick = u64(l.lead_max),
			queue_depth = held,
			queue_limit = CMD_HOST_CAP,
		},
	)
	if !decision.admitted {
		if decision.stage == .Budget {
			l.stat_cmd_rate_dropped += 1
		} else if decision.stage == .Queue {
			l.stat_cmd_capped += 1
		}
		if decision.respond {
			cmd_refuse(l, from, seq, decision.reason, id, cmd)
		} else {
			l.stat_cmd_rejected += 1
		}
		return
	}
	queued := make([]u8, len(args))
	copy(queued, args)
	// Late arrivals (a lag spike outran the lead) execute at the next tick —
	// history is never rewritten; the client's reconcile absorbs the slip.
	at := max(tick, l.ticker.tick + 1)
	append(&l.cmd_in, Cmd_In{tick = at, from = from, seq = seq, id = id, cmd = cmd, args = queued})
}

// Client: the authority answered (handler discipline — file it; the revert
// itself waits for the frame, where all game-state mutation lives).
@(private)
cmd_handle_verdict :: proc(l: ^Lane, r: ^knet.Reader) {
	seq := Cmd_Seq(knet.read_u32(r))
	reason := knet.Action_Reject_Reason(knet.read_u8(r))
	if r.err || !knet.action_reject_reason_valid(reason) || len(knet.reader_remaining(r)) != 0 {
		r.err = true
		return
	}
	for &c in l.cmd_out {
		if c.seq == seq && c.verdict == .Pending {
			c.reason = reason
			c.verdict = reason == .None ? Cmd_Verdict.Accepted : Cmd_Verdict.Rejected
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
			reason := knet.Action_Reject_Reason.Stale
			if tr := cmd_tracked(l, c.id); tr != nil && tr.cmds != nil {
				slot := sim_cmd_find(tr.cmds, c.cmd)
				if slot < 0 {
					reason = .Malformed
				} else if cmd_authorized(l, c.from, tr, slot) {
					reason = sim_cmd_execute(&tr.cmds[slot], tr.entity, c.args, l, c.from)
				} else {
					reason = .Access
				}
			}
			if reason != .None {
				l.stat_cmd_rejected += 1
			}
			cmd_send_verdict(l, c.from, c.seq, reason)
			ksess.session_action_executed(
				l.ses,
				.Scheduled,
				u32(c.seq),
				c.from,
				c.id,
				u16(c.cmd),
				reason,
			)
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
		slot := sim_cmd_find(tr.cmds, c.cmd)
		if slot < 0 || !knet.action_predicts(tr.cmds[slot].policy) {
			continue // scheduled without local execution; authority state lands normally
		}
		if !l.resimming && !c.executed {
			// The live pass: run the verb ONCE, bracketed by captures — the
			// delta-lane revert for a rejection, the predicted-field patch
			// (or the apply half) for every replay after this one.
			c.executed = true
			cmd_exec_local(l, &c, tr, l.ses.me)
		} else if l.resimming && c.executed && c.verdict != .Rejected {
			if ap := tr.cmds[slot].apply; ap != nil {
				if c.ok {
					ap(tr.entity, c.args, l) // exact: re-run with corrected pre-state
				}
			} else if c.mask != 0 {
				cmd_patch_apply(tr.entity, tr.desc, c.mask, c.patch)
			}
		}
	}
}

// Lifecycle cleanup for reliable commands whose packets outlive their target
// or issuer. These are called by lane_untrack/lane_drop_player in lane.odin.
@(private)
cmd_forget_entity :: proc(l: ^Lane, id: knet.Net_Id) {
	for i := 0; i < len(l.cmd_in); {
		if l.cmd_in[i].id != id {
			i += 1
			continue
		}
		delete(l.cmd_in[i].args)
		ordered_remove(&l.cmd_in, i)
	}
	for i := 0; i < len(l.cmd_out); {
		if l.cmd_out[i].id != id {
			i += 1
			continue
		}
		l.cmd_out[i].verdict = .Rejected
		l.cmd_out[i].reason = .Stale
		l.cmd_out[i].executed = false // target is gone; there is nothing left to unwind
		cmd_notify_resolved(l, &l.cmd_out[i])
		cmd_out_free(&l.cmd_out[i])
		ordered_remove(&l.cmd_out, i)
	}
}

@(private)
cmd_forget_player :: proc(l: ^Lane, player: knet.Player_Id) {
	for i := 0; i < len(l.cmd_in); {
		if l.cmd_in[i].from != player {
			i += 1
			continue
		}
		ksess.session_action_executed(
			l.ses,
			.Scheduled,
			u32(l.cmd_in[i].seq),
			player,
			l.cmd_in[i].id,
			u16(l.cmd_in[i].cmd),
			.Stale,
		)
		delete(l.cmd_in[i].args)
		ordered_remove(&l.cmd_in, i)
	}
}

// One speculative execution, capture-bracketed. `re` re-executions (the
// chain's replay after an earlier rejection) discard the predicted-field
// writes — the resims rebuild those from the fresh patch/apply — but keep
// the delta-lane ones: they ARE the re-applied speculation.
@(private = "file")
cmd_exec_local :: proc(l: ^Lane, c: ^Cmd_Out, tr: ^Tracked, me: knet.Player_Id, re := false) {
	// Capture stable handles up front: the verb may spawn a projectile
	// (lane_spawn_predicted), which appends to l.tracked and can REALLOCATE it —
	// `tr` would then dangle. The entity struct, its descriptor, the command
	// slice, and the History all live outside that array and stay put.
	entity, dsc, cmds, hist := tr.entity, tr.desc, tr.cmds, tr.hist
	idx := sim_cmd_find(cmds, c.cmd) // the verb's slot, resolved from its stable id
	if idx < 0 {
		c.ok = false // unknown verb id — same-build issue makes this unreachable
		return
	}
	if n := delta_lane_size(dsc); n > 0 {
		if c.revert == nil {
			c.revert = make([]u8, n)
		}
		delta_lane_capture(c.revert, entity, dsc)
	}
	pre := make([]u8, hist.size, context.temp_allocator)
	predict_capture(pre, entity, dsc)
	c.mask = 0
	delete(c.patch)
	c.patch = nil
	l.cmd_exec_seq = u32(c.seq) // a predicted spawn inside this verb tags itself with the seq (spawn keys are raw u32)
	local_reason := sim_cmd_execute(&cmds[idx], entity, c.args, l, me)
	c.ok = local_reason == .None
	l.cmd_exec_seq = 0
	if c.ok && cmds[idx].apply == nil {
		scratch := make([]u8, hist.size, context.temp_allocator)
		mask, n := cmd_patch_diff(scratch, pre, entity, dsc)
		if n > 0 {
			c.mask = mask
			c.patch = make([]u8, n)
			copy(c.patch, scratch[:n])
		}
	}
	if re {
		// Off-tick re-execution: predicted fields go back to what the frame
		// held; the effect lands through the next resim like everything else.
		predict_restore(entity, dsc, pre)
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
cmd_notify_resolved :: proc(l: ^Lane, c: ^Cmd_Out) {
	if c.notified || c.verdict == .Pending {
		return
	}
	reason := c.reason
	if c.verdict == .Accepted {
		reason = .None
	} else if reason == .None {
		reason = .Predicate
	}
	ksess.session_action_resolved(l.ses, .Scheduled, u32(c.seq), c.id, u16(c.cmd), reason)
	c.notified = true
}

@(private)
cmd_settle :: proc(l: ^Lane) {
	for i := 0; i < len(l.cmd_out); i += 1 {
		c := &l.cmd_out[i]
		if c.verdict == .Pending && l.cmd_clock > c.issued_clock + u64(l.slots) {
			c.verdict = .Rejected // silence past the horizon = a lost seat or a dead host
			c.reason = .Timeout
		}
		if c.verdict == .Accepted {
			cmd_notify_resolved(l, c)
			continue
		}
		if c.verdict != .Rejected {
			continue
		}
		if !c.executed {
			cmd_notify_resolved(l, c)
			continue
		}
		// A refused fire despawns the projectile it predicted (no-op if it
		// spawned none) — the verdict is the instant despawn; the sweep is the
		// backstop for a fire whose spawn simply never arrives.
		lane_spawn_reject(l, u32(c.seq)) // spawn match keys are raw u32
		tr := cmd_tracked(l, c.id)
		if tr == nil || tr.hist == nil {
			c.executed = false
			c.mask = 0
			cmd_notify_resolved(l, c)
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
			// A survivor's re-exec may SPAWN (lane_spawn_predicted appends to
			// l.tracked and can REALLOCATE it) — a ^Tracked held across the
			// loop would dangle for the next survivor. Re-resolve each pass.
			tr = cmd_tracked(l, c.id)
			if tr == nil {
				break
			}
			cmd_exec_local(l, o, tr, l.ses.me, re = true)
		}
		cmd_notify_resolved(l, c)
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
			// Bless the entity's session shadow: the entry's speculative
			// delta-lane writes just stopped being exempt (write guard) — an
			// accepted verb's stand as framework truth, a rejected one's were
			// already unwound by cmd_settle.
			knet.registry_bless(&l.ses.reg, c.id)
			cmd_out_free(c)
			ordered_remove(&l.cmd_out, i)
			continue
		}
		i += 1
	}
}
