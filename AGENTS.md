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
