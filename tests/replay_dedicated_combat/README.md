# Dedicated combat recovery

```sh
REPLAY_DEDICATED_COMBAT_OUT=/absolute/fresh/output nix develop --command bash tests/replay_dedicated_combat/run.sh
```

Two avatarless infrastructure identities and two real players run the actual
Scrapyard model. A forty-enemy wave uses stock damage, health, movement, cooldowns
and cover. The initial catalog uses the original stress harness's 255-magazine /
no-jam overrides; barrels are disabled and one wave is selected. Clients choose
riveters and slime/igniter abilities through ordinary Profile and Ready actions.
They aim from their predicted body at the authority-observed enemy census, move
through ordinary controls, and submit fire/revive/cast inputs. No live world value
is edited by the driver.

The authority waits for at least thirty simultaneously living enemies before
clients engage. Planned/crash takeover must use an approved checkpoint containing
living enemies, a live projectile/lob/zone, at least eight shots, two casts and an
active cooldown. Exact restored-frame equality remains required. After that
baseline is established, the new authority must observe at least ten more shots,
two more casts and another kill in the same run. Completion also requires the
returned/demoted server to receive a new prepared backup and both real seats to
remain intact. The test does not require the bots to win or survive indefinitely;
normal injuries, deaths and eventual wipes remain game behavior.

`overlay.py` supplies the same combat extension to native and browser fixtures.
The input helper borrows observations and uses the existing cover-routing recipe.
`verify.py` independently checks restored/continued counters and their ordering.
An early draft checked continuation before initializing its restored baseline;
that draft's successful process exits are not accepted as continuation evidence.

The browser gate reuses authenticated RTC, the 5,000 ms browser lease, and the
existing role/connection assertions. Native uses the ordinary 2,000 ms lease.
Both keep 120 ms receive delay and the 120-tick known-rollback limit. Broader
network loss, public deployment and repeated combat takeover remain separate work.
