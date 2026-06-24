package complete

// ----------------------------------------------------------------------------
// Canonical SHAPE of a `_complete_code` completion-option Dictionary.
//
// SINGLE SOURCE OF TRUTH, shared by:
//   * core/complete.odin  — BUILDS each option Dictionary by iterating these fields, so the
//                           emitted set is exactly this enum (one key per field), and
//   * tests/complete      — ASSERTS this set covers every key Godot requires.
//
// Godot's `ScriptLanguageExtension::complete_code` (core/object/script_language_extension.h,
// v4.6.2, ~L407-420) deserializes each option with an `ERR_CONTINUE(!op.has("<key>"))` per
// key BEFORE reading it — so omitting ANY key drops that option AND spams the editor log with
//   ERROR: Condition "!op.has("font_color")" is true. ... at: complete_code (...:413)
// (the user's original bug). Every field below is one of those required keys; the trailing
// comment is the exact C++ type the engine casts the Variant to.
//
// `matches` (PackedInt32Array) is the one OPTIONAL key (engine guards it with `op.has`), so we
// don't emit it — ols gives us no fuzzy-match ranges. It is intentionally NOT in this enum.
// ----------------------------------------------------------------------------

Completion_Option_Field :: enum {
	Kind, // int    -> CodeCompletionKind
	Display, // String
	Insert_Text, // String
	Font_Color, // Color
	Icon, // Variant (NIL -> empty Ref<Texture2D>; the editor supplies its own icon)
	Default_Value, // Variant (NIL -> no inline value swatch)
	Location, // int    -> CodeCompletionLocation
}

// The exact Dictionary key string the engine reads for each field.
completion_option_field_key :: proc(f: Completion_Option_Field) -> cstring {
	switch f {
	case .Kind:
		return "kind"
	case .Display:
		return "display"
	case .Insert_Text:
		return "insert_text"
	case .Font_Color:
		return "font_color"
	case .Icon:
		return "icon"
	case .Default_Value:
		return "default_value"
	case .Location:
		return "location"
	}
	return ""
}
