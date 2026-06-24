package validate_fixture

// A clean baseline package used by tests/validate to exercise OdinLanguage._validate.
// It type-checks against the `godot` collection, so `_validate` on this content reports
// valid=true / errors=[]. The validate test then overlays a DELIBERATELY broken version of
// this file (via the live-buffer argument) and asserts the reported error line/column.

import gd "godot:godot"

sample_proc :: proc() -> gd.Int {
	x: int = 42
	return gd.Int(x)
}
