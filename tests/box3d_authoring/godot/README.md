Owned Godot authoring fixture (uncompiled/unrun)

`run.py --out NEW --native-library NEW_ADVANCED_NATIVE --godot GODOT --odin ODIN`
performs the standard build_scripts.sh transaction, headless editor import and
one headless test_authoring.gd process. Root schedules execution only after the
shared/native/source freeze. No Native build or custom Core/scriptgen hook.
The addon is copied into the fresh project by the ordinary installation layout.

The real SDK script module extracts through public Object/Variant APIs into
shared parse_and_bake, with one counted Meter context (existing provider category
is test bookkeeping, not a Replay runtime). The headless test authors all six
shape kinds and a Sensor with reused geometry, saves/reloads real .tres/.tscn,
checks content/logical identities across reorder and presentation renaming,
checks explicit invalid inputs, frees source nodes/resources, then constructs
Native only from copied bake data. It requires an actual one-image census and
checked Native/Meter cleanup. No authoring node steps physics. This is separate
from Root's real Kit/Replay adapter and canonical recovery tests and Gate C.
