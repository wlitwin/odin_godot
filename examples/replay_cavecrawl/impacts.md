# Dweller impacts: C9 and O3

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
Current content IDs are **C9 `0x4341564552504c39`** for server motion and
**O3 `0x434156454f574e33`** for owner motion. Old peers and saves are not silently
admitted under the new content. Session/checkpoint schemas and gameplay world
layout remain unchanged.

The native save converters now accept C1–C8 and O1–O2, respectively. C8 and O2
conversion preserves the exact frame, controls, membership, action frontiers and
pending payloads, then selects current content for future execution. C8's existing
authority observation is preserved rather than reseeded. O1 actions retain their
accepted-pose interpretation. The tools require a new destination and refuse
coordinated/custom-policy archives; those need an application-owned upgrade.
Browser records are not rewritten implicitly.

Historical recordings must retain their event rules. `upgrade.model8()` and
`owner_upgrade.model_2()` provide explicit C8/O2 descriptors with dweller impacts
disabled. Use their old content ID and recorded build identity with
`net.recording_model` and the diagnostic verifier. Genuine pre-change recordings
verify natively and in WASM; substituting today's model produces an event mismatch.
This is explicit historical execution, not conversion of a recording to new rules.

[Projectile views](projectiles.md) now preview bounded motion between ticks. This
presentation path never generates these Hit occurrences or changes their timing.
