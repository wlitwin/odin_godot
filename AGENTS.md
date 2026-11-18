# Working guidance

## Revisit architecture when fixes keep piling up

When repeated narrow fixes or diagnostic iterations leave the same failure mode,
stop and reconsider the relevant architecture or protocol. Compare simpler
designs that remove the structural bottleneck before adding more tuning,
instrumentation, or workarounds. Existing designs and constraints such as “no
protocol changes” are revisable when evidence shows they are causing the issue.

Choose the smallest sound design change, version changed contracts, preserve
prior evidence, and revalidate the guarantees it affects. Keep the reassessment
focused: do not replace implementation churn with review churn.

## Usability remediation and compatibility

The framework and owned games are unlaunched and currently have only internal
users. During the usability remediation, migrate owned callers, content, and
fixtures to the current contracts, then delete obsolete APIs and schema
compatibility paths rather than retaining unnecessary shims. Keep useful current
low-level APIs for deliberate custom composition, and preserve historical evidence.
Track the phased work in `docs/design/usability-backlog.json` and its Herdr board.

When a CI or local test fails, determine whether the implementation or the test
conflicts with the intended behavior. Behavior changes may invalidate old tests:
update those assertions and fixtures with meaningful coverage of the new contract.
Do not preserve obsolete behavior just to make an old test pass, or weaken a valid
test to hide an implementation defect. Record the diagnosis with the check result.
