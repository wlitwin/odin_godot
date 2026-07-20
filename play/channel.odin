package play

// play/channel — HOLD-TO-PROGRESS as a drop-in block: a channel the owner fills by sustained
// action, that every screen watches fill, and that the host honors when the owner claims it.
// Revives, capture points, cast bars, opening a heavy chest, hacking, defusing — the same shape.
//
//   Runner :: struct {
//       owner:  gd.Node2d,
//       net_id: knet.Net_Id,
//       rev:    play.Channel,   // -> the entity gets `runner_rev_claim`
//   }
//
// THE THIRD AUTHORITY MODEL. play.Gun and play.Ability are host-authoritative (host writes,
// command-predicted). A channel is OWNER-AUTHORED: `target` and `pct` ride the owner's unreliable
// stream like position — the owning client writes them every held frame, a dropped tick is
// superseded, and every screen (the channeler, the target, onlookers) reads the same broadcast to
// draw the bar. No commands while channeling; ONE plain command at the end — the CLAIM — which the
// host honors only after re-checking the world.
//
// WHAT THE BLOCK OWNS: the progress accumulator (float-precise, so long channels don't lose u8
// truncation), the broadcast fields, restart-on-retarget, and the claim's carry (the claimed
// target rides the command as a wire arg and is stashed host-side for your hook — the OWNER STREAM
// CANNOT CARRY THE CLAIM: the stream is unreliable and the owner drops the channel as it claims,
// so the zeroed fields can outrace the reliable command; the wire arg makes the claim
// self-contained).
//
// WHAT STAYS YOURS — the seams, per the block rule (a block gates only its OWN state):
//   * THE SCAN — who/what am I channeling on. Range checks, "is the target valid", which button
//     holds. You find the target each frame and call `channel_run`; call `channel_drop` when the
//     hold breaks. The block can't know your geometry.
//   * THE HONOR — the host's re-check. Owner-authored progress is TRUST-THE-OWNER data (same
//     model as position): a modified client can stream pct=255 instantly, so the claim's real
//     gates are the world conditions only the host can check — reviver alive, target still down,
//     actually in reach. Run them in your command hook (keyed by this command's index), reading
//     `claimed` — then grant the effect.
//   * THE BAR — presentation off the replicated pct (play.marker fill/follow), yours to draw.

Channel :: struct {
	target:  u32 `gd:"owner"`, // net id I'm channeling on (0 = idle) — every screen reads it
	pct:     u8 `gd:"owner"`,  // progress 0..255 — the bar every screen draws
	acc:     f32,                        // owner-local: float-precise progress 0..1 (pct is its broadcast)
	claimed: u32,                        // host scratch: the target the claim carried, for the game hook
}

// channel_run — the OWNER's held frame: advance the channel on `target`, taking `seconds` to
// fill. Retargeting restarts; reaching full DROPS the channel and returns done=true exactly once
// — issue the claim right there (`<entity>_<field>_claim_cmd(ctx, self, target)`). Call this only
// while the hold is live on a found target; call channel_drop the frame it breaks.
channel_run :: proc(c: ^Channel, target: u32, dt, seconds: f32) -> (done: bool) {
	if target == 0 {
		channel_drop(c)
		return false
	}
	if target != c.target {c.acc = 0} // switched mid-hold — restart on the new target
	c.target = target
	c.acc = seconds > 0 ? min(c.acc + dt / seconds, 1) : 1
	c.pct = u8(c.acc * 255)
	if c.acc >= 1 {
		channel_drop(c)
		return true
	}
	return false
}

// channel_drop — the hold broke (released, walked away, target died) or the channel completed:
// zero the broadcast so every screen's bar vanishes, and the progress with it.
channel_drop :: proc(c: ^Channel) {
	c.target = 0
	c.pct = 0
	c.acc = 0
}

// channel_claim — the completion, a composed PLAIN command (no prediction: the effect is a host
// grant, there is nothing local to run). The claimed target rides as a wire arg — self-contained
// against the owner stream racing the command (see the module doc) — and is stashed in `claimed`
// for the game's hook, which re-checks the world and grants. The body accepts any nonzero claim:
// every REAL gate is the hook's, because only the host can check the world.
@(gd_command)
channel_claim :: proc(c: ^Channel, target: u32) -> bool {
	if target == 0 {return false}
	c.claimed = target
	return true
}

// channel_active — is this channel live (for bars and gates). `c.pct`/`c.target` are public;
// this names the intent.
channel_active :: proc "contextless" (c: ^Channel) -> bool {
	return c.target != 0 && c.pct > 0
}
