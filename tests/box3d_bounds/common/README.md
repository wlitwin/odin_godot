`common.game_valid(Game)` is a pure structural/safety invariant of the existing
shared rules. Replay delegates `Model.state_valid` to it; Kit binds the same
function through its typed Side wrapper. It never calls Native, mutates Game,
interprets allocation-key bits, or introduces counter maxima/business limits.
The existing shared source hash includes this constraint automatically.

Three focused source-only groups cover unsafe array counts/bindings, retirement
edges and actual four/32-body rules trajectories. Invalid controls copy a Game
from a real public `common.world`; they do not stand in for Native physics proof.
The valid controls reuse `tests/box3d_slices/common`'s actual Native operations,
sensor handling and scripted Spawn/Remove/Motor/Sleep/Wake/Query pipeline. The
32-initial case reaches33 live dynamic bodies/35 total bodies during Spawn;
that legitimate state must remain valid. Removing the extra object clears its
keys but deliberately retains its last lifetime even after retirement expiry.

The eight-entry retirement edge uses real Spawn/Remove operations without extra
Native steps. This exercises the common rules' fixed storage, not a network
action-throughput claim. Every group requires actual Native/wrapper cleanup.
The new validator does not claim it can resolve opaque keys against solver
contents; canonical Native and framework authority/ownership checks remain
separate boundaries. Existing public RED reports remain immutable.

Root compiles/runs this package against the current verified Release Native
archive, ordinary `godot` collection and one test thread. No source agent runs a
compiler, Native build, runtime or probe.
