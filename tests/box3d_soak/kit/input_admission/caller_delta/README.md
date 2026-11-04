# Caller eligibility regressions

The fixed tables retain163 finite, bit-exact checks of the original imported
`caller_delta_plan` calculator and five metadata-only intent regressions. They
do not copy a Lane or simulate a Runtime. The current v2 accounting and receipt
contract is tested separately in `tests/box3d_soak/kit/world_v2_caller`.

The historical intentionally failing proposed-accounting experiment and its
source-bound one-off runner were retired after the supported caller/protocol
implementation passed. Their original source and results remain preserved in
the experiment archive; an intentional historical RED is not an active test.

These tests import the example package: use ordinary generated metadata and
standard SDK custom attributes. Do not bypass or manually modify its guard.
