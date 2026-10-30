# Recovery-backup status

`room_backup_status(&room)` returns a local observation of recovery preparation.
It reads Room's clock; the overload with `now_ms` accepts a time in that same clock
domain and is otherwise read-only. Neither form renews, retires or changes the Lease,
requests a transfer, elects a host or authorizes a handoff.

For a current steady observation, the report includes the last accepted nominee/Point, observation epoch/revision/time,
known progress, known age and configured rollback limit. Room retains that accepted
observation while another RPC is pending, rather than treating the transient empty
RPC reply as lost approval.

| Phase | Meaning |
| --- | --- |
| Unavailable | Room or recovery has failed, or Room is not open |
| Connecting | Registration/session entry is incomplete |
| Waiting_Peer | No eligible nominee is known; the host also checks its actual admitted connection |
| Transferring | A nominee exists but approval or the nominee's retained exact copy is missing |
| Ready | A scope-valid approved Point is within the known rollback bound |
| Stale | Known progress exceeds that bound for the approved Point |
| Checking | Control/clock/epoch observation is no longer valid for this session |
| Recovering | Fencing or a requested/in-progress authority transition is active |

Approval must match the current accepted Lease view and session epoch. Nomination
checks include enabled hosting trust and dedicated infrastructure policy. A host
also checks seat, token binding, incarnation and connection generation/liveness.
The nominee needs its retained exact prepared Point. Other clients can report the
coordinator's observation without holding authority-only checkpoint bytes.

Age is the nonnegative difference between the approved tick and the greater of
coordinator-known progress and locally observed authoritative progress. It is a
known/conservative age, not proof of unreported work or remote process liveness.
Interpret age only for Ready/Stale, and do not treat zero metadata in connecting,
checking, unavailable or recovering states as a valid zero-age backup.
A Point exactly at the rollback limit remains Ready; one tick beyond is Stale.
Expired/backward/invalid clock observations cannot produce Ready.

`room_backup_message(status)` supplies compact UI text, including “Recovery backup
confirmed” rather than promising future recovery availability. `room_recovery_message`
also retains disclosure of a completed host change or published restore, while
still distinguishing a current pending/stale/checking backup. A previous successful
restore is not evidence of a fresh backup now.

Planned handoff keeps its existing API and eligibility checks; it can prepare a
new final checkpoint. The readiness report is not a replacement for that protocol
or a permanent guarantee against subsequent failures. Tests cover policy/clock
edges and a live delayed-preparation, refresh, handoff and departing-peer scenario.
