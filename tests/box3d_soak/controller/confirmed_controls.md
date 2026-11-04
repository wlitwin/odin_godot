# Confirmed Kit class0 evidence

Kit controls count only when a retained decision has the exact logical key
`[epoch,tick,seat,0]` and a matching flat body. `accepted` must be boolean true,
`status` integer0, `origin` integer1/2/3 (Submitted/Held/Authority), `sequence`
typed u64, and x/z typed signed i16. Player must match the actual two-player
READY mapping for that seat. Null, unavailable, malformed, mismatched or
duplicate logical rows cannot satisfy coverage, including zero-valued controls.

The declared target is finite and at most65535. Host coverage still requires
both seats at every post-admission tick through target. Client rows receive the
same strict body validation; existing global parity and qualified recovery-gap
classification remain unchanged. A qualified missing row stays unobserved past,
not matched/delivered. Authority coverage is never waived by a gap.

Replay retains its existing representation/counting path. V1/V2 intent proof,
POLICY_ID, FIXED, PHASES, BOUNDS and plan format are unchanged. This adds no
simulation, admission, fallback controls, private state decoder or runtime API.

Original7b6ae/audit7d8bc remain FAIL/INCOMPLETE: they have zero control rows.
PUMP ranges or sampled complete-state matches do not reconstruct absent INPUT
records. Only fresh producer evidence can satisfy this strict proof.

The focused Python controls are synthetic metadata/SQLite fixtures only, not
Native, Lane, SDK ownership, Godot, timing or functional acceptance evidence.
