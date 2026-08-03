package slopball

// ----------------------------------------------------------------------------
// util — shared, owner-less helpers for slopball (no //gd:class, so scriptgen skips this
// file; plain package Odin compiled into the one scripts dll, shared by every script).
// The old hand-rolled helpers moved into the library: value-form normalization is
// gd.normalized, the per-seat tint is gd.peer_color.
// ----------------------------------------------------------------------------

PITCH_W :: f32(640)
PITCH_H :: f32(360)
