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
//     `g.def.reload_ticks` while `g.mode.cur == .Reloading`). The gun tells you its state; you
//     time the trigger.
//   * EFFECT — WHAT a shot does. A projectile / hitscan / damage touches the game's world, which
//     the gun can't know. Read `g.fired` at the issue site to draw YOUR muzzle flash, and in the
//     command hook (keyed by this command's index) to spawn the authoritative shot from `g.aim`.
//     Cross-entity effects are the game's, exactly as any command's are.
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
	mode:         Machine(Gun_Mode),         // Ready / Reloading / Jammed (cur replicated; owns its own state)
	reload_cd:    u16 `gd:"replicate"`,      // host countdown to reload done (0 = not reloading)
	taps:         u8 `gd:"replicate"`,       // clear-taps left on a jam (replicated so the mash reads on every screen)
	salt:         u32 `gd:"replicate"`,      // jam-seed context the game sets (floor/run/player); 0 is fine
	spent:        u32 `gd:"replicate"`,      // lifetime rounds consumed since equip — the jam roll's never-repeating half
	aim_x, aim_y: f32,                       // scratch: the last pull's aim, for the game's effect hook (host-side)
	fired:        bool,                      // scratch: did the last pull send a live round — the game's EFFECT signal
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
	set(&g.mode, Gun_Mode.Ready)
}

// gun_fire — PULL THE TRIGGER. A composed, PREDICTED command: scriptgen hoists it onto whatever
// entity embeds the Gun (`weapon: Gun` -> `<entity>_weapon_fire`), and it runs identically on the
// host and the predicting client. It resolves the mag/reload/jam FSM in place. The bool it returns
// is kit/net's APPLIED signal — a gun pull is ALWAYS a valid transition (fire, jam, reload, or
// clear-tap), so it is always true; a `false` would tell kit/net to REVERT the transition, which a
// jam or a reload must never do. Whether a live round actually LEFT THE BARREL is `g.fired`, which
// the game reads at the issue site (draw the muzzle flash) and in its command hook (spawn the
// shot). `dx,dy` is the aim, stashed for that hook — the gun itself is aim-agnostic.
@(gd_command = "predict")
gun_fire :: proc(g: ^Gun, dx, dy: f32) -> bool {
	g.aim_x, g.aim_y = dx, dy
	g.fired = false
	switch g.mode.cur {
	case .Reloading:
	// The pacer holds through a reload; a stray pull that raced it is a no-op (still applied).
	case .Jammed:
		// Mash to clear — each pull chips a tap; no round leaves until it's Ready again.
		if g.taps > 0 {g.taps -= 1}
		if g.taps == 0 {set(&g.mode, Gun_Mode.Ready)}
	case .Ready:
		if g.ammo == 0 {
			// Empty — begin the reload; the host counts it down in gun_tick, the pacer holds.
			set(&g.mode, Gun_Mode.Reloading)
			g.reload_cd = g.def.reload_ticks
		} else if gun_jams(g) {
			g.ammo -= 1 // the dud is ejected
			g.spent += 1
			set(&g.mode, Gun_Mode.Jammed)
			g.taps = g.def.jam_taps
		} else {
			g.ammo -= 1
			g.spent += 1
			g.fired = true // a live round flew
			if g.ammo == 0 {
				set(&g.mode, Gun_Mode.Reloading)
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
	if g.mode.cur == .Reloading && g.reload_cd > 0 {
		g.reload_cd -= 1
		if g.reload_cd == 0 {
			g.ammo = g.def.mag
			set(&g.mode, Gun_Mode.Ready)
		}
	}
}

// gun_step — presentation edge: call every frame on every peer and branch on (from, to) to fire
// enter/exit cues (a JAM burst, a reload click, a Ready pop). The host observes its own `set`,
// each client observes the replicated `mode.cur`; both drive this, so cues fire on every screen
// with no coordination — the play.Machine contract, one level up.
gun_step :: proc(g: ^Gun) -> (from, to: Gun_Mode, moved: bool) {
	return step(&g.mode)
}

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

// Convenience predicates the pacer and HUD read — the gun's state is public (`g.mode.cur`,
// `g.ammo`, `g.def`), but these name the intent at the call site.
gun_reloading :: proc "contextless" (g: ^Gun) -> bool {return g.mode.cur == .Reloading}
gun_jammed :: proc "contextless" (g: ^Gun) -> bool {return g.mode.cur == .Jammed}
