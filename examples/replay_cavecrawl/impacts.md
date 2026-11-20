# Dweller impacts: C10 and O4

Every rock contact emits a recorded occurrence for its dweller, including the
nonlethal first hit. An occurrence pairs an event payload with an identity used
to match it across replay; here the payload is Hit. Damage, collision ordering, kills, drops and motion are
unchanged. The existing Hit payload uses seat zero for a dweller; player hits
retain their existing seat. Its position is copied before removal, and amount
retains the rock's 35-point damage value.

The occurrence source identifies the projectile generation/slot. The occurrence
key is the target view identity: `u64(dweller_generation)<<32 | (slot+1)`.
Consequently, two rocks hitting one target remain distinct occurrences, and a
recycled dweller slot cannot inherit an older impact's flash. Lethal hits precede
the existing Slain occurrence, so yellow impact sparks and purple death sparks
both survive entity removal. Correction/cancellation use the visual cue ledger.

The event layout is unchanged, but the replayed event sequence has changed.
Current content IDs are **C10 `0x4341564552504c3a`** for server motion and
**O4 `0x434156454f574e34`** for owner motion. Old peers and saves are not silently
admitted under the new content. The event schema and negotiated checkpoint
contract changed. The saved world and pending action layouts are the same.

Retained checkpoints were migrated with frames, controls, membership and pending
actions preserved. The active fixtures use C10/O4 directly. [Original bytes and
migration receipts](../../docs/replay/results/usability-legacy-2026-11-16/cavecrawl/receipt.json) remain separate evidence; old readers and the
impact-suppression entry points have been removed.

Old C8/O2 recordings lack these Hit events. They remain historical evidence.
New current-model recordings start from the migrated checkpoints, restore under
the next epoch and capture three ticks. Tests require one correctly keyed Hit,
one settlement of the original pending Door, and no repeated impact. Native and
executed WASM replay the same files. Changing only an expected Hit amount must
produce event divergence with identical Worlds.

See [the acceptance runner](../../tests/replay_cave_impact/README.md) for current
model, recording, fresh-process resume, campaign and rendering checks.
