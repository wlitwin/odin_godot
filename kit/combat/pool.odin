package kit_combat

import "base:intrinsics"

// pool — the host-sim projectile pool's tick, extracted from the loop every game re-wrote
// (scrapyard three times: slugs/lobs/globs; cavecrawl's rocks; homestead's rocks). The mechanics
// it owns are exactly the bug-prone parts:
//
//   * SWEEP BEFORE STEP — hit-test the tick's whole segment (current pos + this tick's vel)
//     BEFORE moving, so a fast projectile can't tunnel through its target between ticks.
//   * remove-during-iteration — the unordered_remove/index dance, done once, correctly.
//   * expiry — projectile_step's ttl reaching zero despawns, with a last-word callback
//     (a lob's splash IS its expiry).
//
// What stays the game's, as callbacks (the kit's user-rawptr hook idiom — no closures needed):
//
//   * TARGETS — called PER PROJECTILE, not snapshotted per tick: an on_hit that kills (a slug
//     felling a mob) changes the target set for the very next projectile in the pool, and a
//     stale snapshot would land hits on the corpse. nil = this pool doesn't hit-test (a lob
//     that flies its clock out and splashes at expiry).
//   * ON_HIT / ON_EXPIRE — what a connect or a fizzle MEANS (damage, splash, credit). A hit
//     always removes the projectile (none of the five pools in the dogfoods pierce; if a game
//     ever wants piercing, that's the signature to revisit).
//
// The pool element is YOUR wrapper carrying whatever the callbacks need (damage, shooter) with
// the kit's Projectile embedded as `p` — or a bare Projectile when there's nothing to carry:
//
//   Slug :: struct { p: kcombat.Projectile, dmg: u8, shooter: knet.Player_Id }
//   flying: [dynamic]Slug                    // wrapper pool
//   spit:   [dynamic]kcombat.Projectile      // bare pool
//
//   kcombat.pool_tick(&self.flying, self, slug_targets, slug_hit, nil)
//   kcombat.pool_tick(&self.lobs, self, nil, nil, lob_splash)

// The pool's target census, called per projectile (see above). Return a temp-allocated or
// cached slice; the pool only reads it for the one sweep.
Pool_Targets :: proc(user: rawptr) -> []Target

// One host tick of a whole pool: sweep (if targeted), step, despawn — callbacks decide meaning.
// `T` is the element: either a wrapper with a `p: Projectile` field, or Projectile itself.
pool_tick :: proc(
	pool: ^[dynamic]$T,
	user: rawptr,
	targets: Pool_Targets,
	on_hit: proc(user: rawptr, item: ^T, tg: Target),
	on_expire: proc(user: rawptr, item: ^T),
) where T == Projectile || intrinsics.type_has_field(T, "p") {
	i := 0
	for i < len(pool) {
		it := &pool[i]
		pr: ^Projectile
		when T == Projectile {pr = it} else {pr = &it.p}
		// Sweep the tick's segment BEFORE stepping — a fast projectile still connects.
		if targets != nil && on_hit != nil {
			if tg, hit := projectile_hit(pr.pos, pr.vel, targets(user)); hit {
				on_hit(user, it, tg)
				unordered_remove(pool, i)
				continue
			}
		}
		if !projectile_step(pr) {
			if on_expire != nil {on_expire(user, it)}
			unordered_remove(pool, i)
			continue
		}
		i += 1
	}
}
