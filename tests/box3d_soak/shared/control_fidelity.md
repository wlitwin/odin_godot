# Saved control-fidelity diagnostic

`control_fidelity.audit_archive(path, *, framework, epoch, first_tick, last_tick,
remote_seat=2, sample_limit=8)` reads a **closed** controller
`observations.sqlite` using SQLite `mode=ro` and `query_only`. It returns a JSON
compatible diagnostic and never changes an archive, existing report or checker.
The window is explicit; observed maxima do not establish complete coverage.

Each host/client seat has actual origin counts, Submitted/Replay Sample counts,
Held/nonzero/Held-zero counts, missing/duplicate/malformed observations and
consecutive-tick runs (origin runs and separate Held-zero runs). Detail samples
are bounded (0..64 per control group/correlation observation category); counts cover the whole
selected window. `DEGENERATE_FULL_HELD_ZERO` means that every required tick of
the remote seat was observed as Held `(0,0)`. It is evidence of degenerate input
fidelity, never a product pass. Incomplete all-Held-zero observations have a
separate unavailable-coverage flag. Zero controls with another origin remain
reported as zero; this tool does not invent a nonzero-control requirement.

Kit uses integer origins 1=Submitted, 2=Held, 3=Authority, actual class0/status0/
accepted observations, signed i16 axes, u64 source sequence and actual READY
player mapping. Replay preserves its public names Neutral/Sample/Held/Local and
actual generation/serial/incarnation fields. No missing field becomes zero,
Held, None, a receipt or a rejection. Missing/malformed evidence stays unavailable.

Client ISSUED/SUBMITTED records are correlated with **actual host APPLIED rows**
by epoch/seat/sequence/kind and Replay generation. Results distinguish missing,
malformed, ambiguous and different-kind counterparts; applied booleans/reasons
come only from those published rows. Serial/incarnation differences remain
visible. Missing reasons/scope metadata remain explicitly unavailable. Actual
authority execution tick differences from submitted tick are counted without
interpreting Receipt/Scheduled compatibility. Issue counts are rows,
not a substitute for the existing global issue-uniqueness proof. A logical match is **not acceptance** and never overrides the frozen
identity rules. No receive/admission time or action outcome is inferred from a
control origin. Original event IDs link samples back to the immutable archive.

This is intentionally not another policy engine: no state decoding, chain
certification, scenario/cycle/Spawn checker, new quality limits, Gate B decision
or retrospective PASS. Selected/scripted schedule compatibility and unknown
timing must be assessed separately from these descriptive counts. Root owns
integration and any prospective selection.

Initial source checkpoint only: no diagnostic execution or synthetic/saved-case
checks before Root's grant. Planned controls cover real nonzero Submitted/Sample
observations, full and partial Held-zero runs, missing/malformed/bool/float
fields, body/index/player mismatch, duplicate rows, actual applied-false versus
missing outcomes, ambiguous counterparts and scope differences. Saved readback
will compare the pre-existing `claude-independent-review-v1/root-count-verification.json`
counts for Kit and both Replay cases without changing their original results.
