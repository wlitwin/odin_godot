package play

// play/trail — moved DOWN to kit/combat (the arrow points play → kit, and a
// pure off-wire ring is mechanism, not replicated state; the coop lag-comp
// option lands beside it there). These aliases keep every play.Trail call
// site true — new code should reach for kcombat.Trail directly.

import kcombat "godot:kit/combat"

Trail :: kcombat.Trail
trail_note :: kcombat.trail_note
trail_read :: kcombat.trail_read
