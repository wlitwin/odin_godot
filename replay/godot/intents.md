# Copied action intents

`net.Action_Intent(Action)` owns one copied, unsubmitted action and a bounded set
of tickets already accepted by the network ledger. It lives beside device/UI
state, outside the simulation. It does not change action scheduling, admission,
prediction, game predicates or checkpoint policy.

```odin
dash: net.Action_Intent(Action)

// Capture once when the game can construct the intended payload.
error := net.intent_capture(&dash, Action{kind=.Dash, aim=direction})

// Call each frame, including frames with no new press. A failed submission
// retains the payload; a successful one returns its sequence and consumes it.
sequence, error := replaygd.session_intent(&session, &dash)
// For a Room, use replaygd.room_intent(&room, &dash).

for change in changes {
    replaygd.intent_observe(&dash, &session, change)
}

// Menus or game policy may cancel input that has not yet been submitted.
net.intent_cancel(&dash)
```

Capture rejects reference-bearing payload types. Capturing while another payload
is held returns `Capacity` and preserves the first value; this is a single intent
latch, not an unlimited click queue. Submission also checks ticket capacity before
calling the issuer. A successful issue owns delivery through the existing action
ledger. Cancellation cannot withdraw that submitted action, and a predicate
refusal completes its ticket without automatic retry.

The helper tracks tickets by **epoch and sequence**, because recovery can reuse a
sequence number from a retired epoch. `intent_observe` accepts only authoritative
action-result changes for the Session's local seat and a matching ticket. Predicted
changes, cancellation, other seats, old epochs and duplicate results do not settle
the ticket.

Session helpers process the existing recovery report. Retained requests move to
the new epoch with their original sequence. Known applied/rejected results settle;
retired requests and unavailable settled results increment distinct `retired` and
`unknown` counters. Neither is treated as a gameplay rejection or blindly retried.
Call the submit/observation helpers every frame and consume recovery reports in
order; low-level users can call `net.intent_recover` explicitly.

`submitted`, `confirmed`, `refused`, `retired`, `unknown`, `pending_count` and
`captured` are diagnostic state. `last` holds the most recently completed result;
`result_serial` changes whenever one completes, including through recovery. A
recovery batch can complete multiple tickets, so use the original Session changes
and recovery report when every individual result is needed for application logic.

Use `intent_reset` only at an explicit local session lifecycle boundary, before
reusing the helper with another ledger. It does not cancel work in a running
network session. One helper must not mix results from unrelated sessions.

Low-level `client_intent` and `server_intent` use the same mechanism. Custom
`intent_submit` callbacks must enqueue once, return a nonzero increasing sequence
for the supplied epoch, and avoid reentry or synchronous resolution. A broken
success receipt faults the helper to prevent automatic duplicate submission; the
helper cannot undo an external callback's side effects.
