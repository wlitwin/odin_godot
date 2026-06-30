package godot

// Ergonomic helpers for common gameplay/UI classes — hand-written, mirrored in
// bindgen/upstream/godot/ so they survive binding regeneration. They collapse the verbose bits
// (constructing a Godot String / StringName, multi-arg method calls with defaults) into
// `gd.<helper>(...)` one-liners. Generic helpers take `Object` (so `self.owner` passes with no
// cast); the class-specific ones take the class alias for a little type safety.

// ---- Text: any Control with a `text` property (Label, Button, LineEdit, RichTextLabel, …) ----

// set_text sets a control's `text` from a plain cstring — no Godot String to construct.
set_text :: proc "contextless" (obj: Object, text: cstring) {
	set_string(obj, "text", text)
}

// get_text reads a control's `text` as an Odin string (allocated in context.allocator).
get_text :: proc(obj: Object, allocator := context.allocator) -> string {
	return get_string(obj, "text", allocator)
}

// ---- AnimationPlayer ----

// animation_play plays an animation by name (cstring -> StringName), with Godot's default blend
// and speed. For a non-default blend/speed/from_end use the bound `animation_player_play`.
animation_play :: proc "contextless" (player: Animation_Player, name: cstring) {
	n := new_string_name_cstring(name, true)
	animation_player_play(player, n, -1.0, 1.0, false)
}

// animation_stop stops the current animation (without resetting to the rest pose).
animation_stop :: proc "contextless" (player: Animation_Player) {
	animation_player_stop(player, false)
}

// is_animation_playing reports whether the AnimationPlayer is currently playing.
is_animation_playing :: proc "contextless" (player: Animation_Player) -> bool {
	return bool(animation_player_is_playing(player))
}

// ---- AnimatedSprite2D ----

// sprite_play plays an AnimatedSprite2D animation by name (cstring -> StringName).
sprite_play :: proc "contextless" (sprite: Animated_Sprite2d, name: cstring) {
	n := new_string_name_cstring(name, true)
	animated_sprite2d_play(sprite, n, 1.0, false)
}

// sprite_stop stops the AnimatedSprite2D.
sprite_stop :: proc "contextless" (sprite: Animated_Sprite2d) {
	animated_sprite2d_stop(sprite)
}

// is_sprite_playing reports whether the AnimatedSprite2D is currently playing.
is_sprite_playing :: proc "contextless" (sprite: Animated_Sprite2d) -> bool {
	return bool(animated_sprite2d_is_playing(sprite))
}

// ---- Audio ----

// audio_play / audio_stop drive an AudioStreamPlayer (non-positional). audio_play starts from the
// beginning; for a start offset use the bound `audio_stream_player_play`.
audio_play :: proc "contextless" (player: Audio_Stream_Player) {
	audio_stream_player_play(player, 0.0)
}
audio_stop :: proc "contextless" (player: Audio_Stream_Player) {
	audio_stream_player_stop(player)
}

// audio_play2d / audio_stop2d drive a positional AudioStreamPlayer2D.
audio_play2d :: proc "contextless" (player: Audio_Stream_Player2d) {
	audio_stream_player2d_play(player, 0.0)
}
audio_stop2d :: proc "contextless" (player: Audio_Stream_Player2d) {
	audio_stream_player2d_stop(player)
}
