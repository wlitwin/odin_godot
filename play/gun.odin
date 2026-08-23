package play

// play/gun — a reusable GUN as a drop-in block: mag + reload + jam, host-authoritative and
// client-predicted, configured by knobs. The whole point of scriptgen's verb-composition: embed
// one field and the entity gets a working trigger, both the replicated state AND the `gun_fire`
// verb travelling with it.
//
//   Runner :: struct {
//       owner:  gd.Node2d,
//       net_id: knet.Net_Id,
//       weapon: play.Gun,   // -> the entity gets `runner_weapon_fire` on its command table
//   }
//
// WHAT THE BLOCK OWNS (and you never re-hand-roll): the magazine, the reload dwell, and the
// jam/clear state machine — resolved DETERMINISTICALLY inside the `gun_fire` command, which runs
// on the host AND the predicting client from byte-identical input. So kit/net's own prediction
// revert + reject-truth reconcile the gun for free (its replicated fields are in the entity
// descriptor) — no client-side shadow copy, no hand-written reconcile. `g.fired` says whether a
// live round left the barrel this pull (jams, empty-clicks, and clear-taps leave it false).
//
// WHAT STAYS YOURS — two seams, because they can't be general:
//   * CADENCE — WHEN to pull. Responsive fire is a per-local-player wall-clock feel (the pacer
//     lesson): the wielder paces and predicts on its own clock, never waiting for replicated
//     state. So the game issues `..._fire_cmd` when ITS pace says now (a play.Pace, holding for
//     `g.def.reload_ticks` while `g.mode == .Reloading`). The gun tells you its state; you
//     time the trigger.
//   * EFFECT — WHAT a shot does. A projectile / hitscan / damage touches the game's world, which
//     the gun can't know. Read `g.fired` at the issue site to draw YOUR muzzle flash, and in the
//     command hook (keyed by this command's index) to spawn the authoritative shot from the
//     pull's aim AND ORIGIN (the wire args). Cross-entity effects are the game's, exactly as
//     any command's are.
//
// THE PULL CARRIES ITS ORIGIN (ox, oy) — the wielder's own muzzle, as the shooter's screen saw
// it. On an OWNER-STREAMED wielder (x/y `gd:"owner"`, the kit/net avatar default) the host's
// copy lags a stream behind, so a shot the host launches from ITS copy of the wielder leaves
// from behind a moving shooter — on every screen, including the shooter's, whose own tracer
// left the live muzzle. That is a gameplay divergence (the wounding line is not the line the
// shooter saw hit), not a presentation one. The claimed origin is UNTRUSTED input: in your
// `_then` hook leash it against your copy before launching —
// `kcombat.leash({ox, oy, 0}, {self.x, self.y, 0}, LEASH)` — honest latency offsets pass,
// teleport-cheese is dragged back to arm's length (cavecrawl's spelunker_throw is the pattern).
// The gun can't leash for you: it does not know the wielder's position (below). A wielder whose
// position the host simulates itself (a kit/sim `gd:"predict"` body) just passes its own x/y —
// host and owner agree on the tick's position, so the leash is a no-op there.
//
// The wielder is NOT threaded in (unlike a game-specific composed command): the gun is
// self-contained through its knobs, so `gun_fire` reaches nothing outside the block — which is
// what makes it reusable across entity types (a player, an enemy, a turret) unchanged.

Gun_Mode :: enum u8 {
	Ready,
	Reloading,
	Jammed,
}

// The gun's identity as DATA — the knobs. Host-assigned at equip and replicated (it rarely
// changes, so it's near-free on the wire via delta compression) so both peers resolve the
// deterministic jam identically and every screen's HUD reads the same numbers.
Gun_Def :: struct {
	mag:           u16, // rounds per magazine
	reload_ticks:  u16, // reload dwell, in NET ticks
	jam_per_mille: u16, // per-shot jam chance in ‰ (0 = never jams)
	jam_taps:      u8,  // trigger-pulls to clear a jam
}

Gun :: struct {
	def:          Gun_Def `gd:"replicate"`, // the knobs (POD blob; host-assigned at equip)
	ammo:         u16 `gd:"replicate"`,      // rounds left in the mag
	mode:         Gun_Mode `gd:"replicate"`, // Ready / Reloading / Jammed — host-written, every screen reads
	reload_cd:    u16 `gd:"replicate"`,      // host countdown to reload done (0 = not reloading)
	taps:         u8 `gd:"replicate"`,       // clear-taps left on a jam (replicated so the mash reads on every screen)
	salt:         u32 `gd:"replicate"`,      // jam-seed context the game sets (floor/run/player); 0 is fine
	spent:        u32 `gd:"replicate"`,      // lifetime rounds consumed since equip — the jam roll's never-repeating half
	aim_x, aim_y: f32,                       // scratch: the last pull's aim, for the game's effect hook (host-side)
	origin_x, origin_y: f32,                 // scratch: the last pull's CLAIMED origin (the wielder's own muzzle) — leash it in the hook
	fired:        bool,                      // scratch: did the last pull send a live round — the game's EFFECT signal
	pull:         Gun_Pull,                  // scratch: WHICH arm of the FSM the last pull ran — receipts/sfx read it
	                                         // instead of reverse-engineering the transition from post-state
}

// What one trigger pull actually did — the outcome `fired` compresses to a
// bool. Hosts used to infer these from the post-pull state (a fresh jam reads
// as taps == def.jam_taps, an unjam as Ready-and-not-fired), which is exactly
// the kind of fragile archaeology a scratch enum deletes.
Gun_Pull :: enum u8 {
	Held,      // reloading: the pull was absorbed (the pacer usually prevents it)
	Fired,     // a live round left the barrel (fired = true)
	Jammed,    // the round was a dud — ejected, the mash begins
	Empty,     // dry click: the reload begins
	Clear_Tap, // a mash pull chipped a tap (still jammed)
	Cleared,   // the LAST tap — Ready again, no round yet
}

// gun_equip — host-only, at spawn or on a weapon swap: stamp the knobs, top off the mag, go
// Ready. `salt` folds any per-context entropy you want the deterministic jam to depend on (the
// floor number, the run seed, the player id) so a dud round can't be memorised across runs; 0 is
// a fine default.
gun_equip :: proc(g: ^Gun, def: Gun_Def, salt: u32 = 0) {
	g.def = def
	g.ammo = def.mag
	g.salt = salt
	g.spent = 0
	g.reload_cd = 0
	g.taps = 0
	g.mode = .Ready
}

// gun_fire — PULL THE TRIGGER. A composed, PREDICTED command: scriptgen hoists it onto whatever
// entity embeds the Gun (`weapon: Gun` -> `<entity>_weapon_fire`), and it runs identically on the
// host and the predicting client. It resolves the mag/reload/jam FSM in place. The bool it returns
// is kit/net's APPLIED signal — a gun pull is ALWAYS a valid transition (fire, jam, reload, or
// clear-tap), so it is always true; a `false` would tell kit/net to REVERT the transition, which a
// jam or a reload must never do. Whether a live round actually LEFT THE BARREL is `g.fired`, which
// the game reads at the issue site (draw the muzzle flash) and in its command hook (spawn the
// shot). `dx,dy` is the aim and `ox,oy` the wielder's OWN muzzle position at the pull (the
// owner-carried origin — see the header: leash it in the hook), both stashed for that hook —
// the gun itself is aim- and position-agnostic.
@(gd_command = "predict")
gun_fire :: proc(g: ^Gun, dx, dy: f32, ox, oy: f32) -> bool {
	g.aim_x, g.aim_y = dx, dy
	g.origin_x, g.origin_y = ox, oy
	g.fired = false
	switch g.mode {
	case .Reloading:
		// The pacer holds through a reload; a stray pull that raced it is a no-op (still applied).
		g.pull = .Held
	case .Jammed:
		// Mash to clear — each pull chips a tap; no round leaves until it's Ready again.
		if g.taps > 0 {g.taps -= 1}
		g.pull = .Clear_Tap
		if g.taps == 0 {
			g.mode = .Ready
			g.pull = .Cleared
		}
	case .Ready:
		if g.ammo == 0 {
			// Empty — begin the reload; the host counts it down in gun_tick, the pacer holds.
			g.mode = .Reloading
			g.reload_cd = g.def.reload_ticks
			g.pull = .Empty
		} else if gun_jams(g) {
			g.ammo -= 1 // the dud is ejected
			g.spent += 1
			g.mode = .Jammed
			g.taps = g.def.jam_taps
			g.pull = .Jammed
		} else {
			g.ammo -= 1
			g.spent += 1
			g.fired = true // a live round flew
			g.pull = .Fired
			if g.ammo == 0 {
				g.mode = .Reloading
				g.reload_cd = g.def.reload_ticks
			}
		}
	}
	return true // the pull applied — jam/reload/clear-tap are valid outcomes, not rejections
}

// gun_tick — HOST per-tick: run the reload dwell. Call once per net tick per gun on the host; the
// authoritative half of the client's predicted reload gap (they finish within a hair). No-op
// unless reloading.
gun_tick :: proc(g: ^Gun) {
	if g.mode == .Reloading && g.reload_cd > 0 {
		g.reload_cd -= 1
		if g.reload_cd == 0 {
			g.ammo = g.def.mag
			g.mode = .Ready
		}
	}
}

// THE MODE'S PRESENTATION is the game's edge half on the embedding entity —
// branch on (old, new) for enter/exit cues (a JAM burst, a reload click, a
// Ready pop), fired on every screen by the session's edge pass, no per-frame
// scan and no coordination:
//
//   runner_weapon_mode_edge :: proc(g: ^Game, self: ^Runner, old, new: play.Gun_Mode) {
//       #partial switch new { case .Jammed: spark(); case .Ready: click() }
//   }

// gun_jams — the deterministic per-shot jam roll: seeded from the shared salt and the gun's
// LIFETIME round counter, which never repeats. (It once seeded from the mag position — fine on a
// 20-round iron, but a 3-shell drum re-rolled the SAME three verdicts every magazine, so one
// cursed (salt, slot) pair read as a 33% jam rate for an entire floor.) Unpredictable to the
// player, IDENTICAL on host and client — so the client predicts the jam and shows it with
// zero lag while the host stays authoritative. `def.jam_per_mille == 0` never jams.
gun_jams :: proc "contextless" (g: ^Gun) -> bool {
	if g.def.jam_per_mille == 0 {return false}
	h := g.salt * 2654435761 + g.spent * 40503 + 668265263
	h ~= h >> 15
	h *= 2246822519
	h ~= h >> 13
	return u16(h % 1000) < g.def.jam_per_mille
}

// Convenience predicates the pacer and HUD read — the gun's state is public (`g.mode`,
// `g.ammo`, `g.def`), but these name the intent at the call site.
gun_reloading :: proc "contextless" (g: ^Gun) -> bool {return g.mode == .Reloading}
gun_jammed :: proc "contextless" (g: ^Gun) -> bool {return g.mode == .Jammed}
