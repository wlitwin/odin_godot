package play

// play/ability — a COOLDOWN-GATED cast as a drop-in block: the classic slow ability (a lob, a
// cone, a buff) whose only state is "how long until I can go again". Embed one per slot; scriptgen
// hoists its `ability_cast` verb onto the entity (verb-composition), and the cooldown replicates
// through the embed (state-composition).
//
//   Runner :: struct {
//       owner:  gd.Node2d,
//       net_id: knet.Net_Id,
//       lob:    play.Ability,   // -> the entity gets `runner_lob_cast`
//       cone:   play.Ability,   // -> `runner_cone_cast` (distinct, path-prefixed)
//   }
//
// THE PREDICTION MODEL differs from play.Gun on purpose. A gun fires at 60Hz, so the wielder PACES
// on its own wall-clock; a slow ability's cooldown (3-5s) dwarfs any round-trip, so the CLASSIC
// predicted gate is enough — the client casts optimistically, the host is authoritative, and the
// ~RTT lag before the replicated cooldown reads ready is imperceptible. So the block owns its
// cadence here (the cooldown), where play.Gun left it to the wielder.
//
// THE RETURN IS kit/net's APPLIED SIGNAL (the play.Gun lesson: never conflate it with a domain
// outcome). For an ability the two happen to COINCIDE — a cast either goes off (applies, starts the
// cooldown) or is on cooldown (a genuine rejection: kit/net reverts the optimistic cooldown start).
// There is no jam-like "applied but nothing happened" case, so unlike play.Gun there is no separate
// `fired` flag: `ability_cast`'s return — and the command hook's `ok` — IS "the cast went off".
//
// WHAT STAYS YOURS: the EFFECT. The lob's splash, the cone's burns, the buff's stat change touch
// the game's world, so they live in your command hook (keyed by this command's index, gated on
// `ok`), reading the aim the block stashed. The gun's two-seam rule, minus the cadence seam.

// Knobs. Host-assigned at arm and replicated so both peers gate identically and the HUD reads the
// same countdown. Just the cooldown for now — a resource COST is a game gate (check it before you
// issue, the same way you check the caster is alive), not the block's business.
Ability_Def :: struct {
	cooldown: u16, // NET ticks between casts
}

Ability :: struct {
	def:          Ability_Def `gd:"replicate"`, // the knob (POD blob; host-assigned at arm)
	cd:           u16 `gd:"replicate"`,          // ticks until ready (0 = ready); host-decayed, client-predicted
	aim_x, aim_y: f32,                           // scratch: the last cast's aim/target, for the game's effect hook
}

// ability_arm — host-only, at spawn or a loadout change: stamp the cooldown and start ready.
ability_arm :: proc(a: ^Ability, def: Ability_Def) {
	a.def = def
	a.cd = 0
}

// ability_cast — CAST. A composed, PREDICTED command hoisted onto the embedding entity
// (`lob: Ability` -> `runner_lob_cast`). It gates on the cooldown and starts it. Returns whether
// the cast WENT OFF: true = applied (the client's optimistic cast stands, the cooldown is running),
// false = on cooldown (kit/net reverts the optimistic start — a stale client that raced its own
// cooldown snaps back). The game reads that at the issue site (a local cast animation) and in its
// command hook (`ok`) to run the effect from `aim`. `dx,dy` is the aim/target, stashed for the hook.
@(gd_command = "predict")
ability_cast :: proc(a: ^Ability, dx, dy: f32) -> bool {
	if a.cd > 0 {return false} // on cooldown — a rejection, revert the optimistic state
	a.aim_x, a.aim_y = dx, dy
	a.cd = a.def.cooldown
	return true
}

// ability_tick — HOST per-tick: decay the cooldown toward ready. Call once per net tick per ability
// on the host; the client watches the replicated countdown (the ability is slow enough that it
// needn't predict the decay). No-op when ready.
ability_tick :: proc(a: ^Ability) {
	if a.cd > 0 {a.cd -= 1}
}

// ability_ready reports whether the ability can cast this instant — for the HUD and any local
// pre-gate. `cd` is public (`a.cd`); this just names the intent.
ability_ready :: proc "contextless" (a: ^Ability) -> bool {
	return a.cd == 0
}
