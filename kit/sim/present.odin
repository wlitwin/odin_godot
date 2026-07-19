package kit_sim

// present — blending predict-set snapshots for the eye.
//
// This file is the blend/error MATH only — the per-frame PRESENTER that calls
// it lives in lane.odin as lane_present (the pump that picks the bracket pair,
// the alpha, and the render clock). A reader looking for "the present code
// path" wants lane_present; this file is the primitives it drives.
//
// A watched entity (someone else's avatar on a client) holds ledgered truth
// at snapshot ticks; drawing it straight from the newest batch steps at the
// snap rate. predict_blend is the smoothing primitive: interpolate two
// ledger blobs into the entity's fields, honoring each field's Lerp_Kind
// exactly like stream sampling does on the coop lane — .Interp fields blend,
// everything else STEPS to the earlier sample (a discrete field must never
// show a value that never existed). The lane's watch clock (lane_present)
// decides the pair and the alpha; this file only does the math.

import "core:math"
import knet "godot:kit/net"

// ---------------------------------------------------------------------------
// Render-error smoothing — the reconcile's presentation half.
//
// When a reconcile corrects a predicted entity, the SIM fields snap (truth is
// truth, and the ledger records it), but the drawn pose glides: the error —
// what the screen showed minus what is now true — decays with a half-life,
// applied on top of the sim state at present time. Errors are meaningful for
// FLOAT .Interp fields only (a discrete field must never show a value that
// never existed); everything else presents the sim value as-is. The err blob
// shares the predict-subset layout, so offsets line up for free.

// err = shown − truth, per float interp component. The cut is the teleport
// threshold: an error any component of which exceeds it is a deliberate
// discontinuity (a teleport, a kickoff) — zero the WHOLE error and let the snap
// show; smoothing a cut looks worse than the cut (the puppet rule). `cut` is
// the lane default; a field's own Field_Desc.cut (> 0) overrides it — but the
// snap stays entity-coherent (any field past ITS cut snaps the whole pose).
predict_error :: proc(err: []u8, shown: []u8, truth: []u8, desc: ^knet.Entity_Desc, cut: f32) {
	off := 0
	over := false
	for f in desc.fields {
		if .Predicted not_in f.flags {
			continue
		}
		defer off += f.size
		if .Interp not_in f.flags {
			continue
		}
		fc := f.cut > 0 ? f.cut : cut // per-field cut overrides the lane default
		#partial switch f.lerp {
		case .F32:
			for i in 0 ..< f.size / 4 {
				d := (^f32)(rawptr(&shown[off + i * 4]))^ - (^f32)(rawptr(&truth[off + i * 4]))^
				(^f32)(rawptr(&err[off + i * 4]))^ = d
				if fc > 0 && abs(d) > fc {
					over = true
				}
			}
		case .Angle:
			for i in 0 ..< f.size / 4 {
				// The error is the SHORT arc — a glide across ±π must not
				// spin the long way any more than the blend does.
				d := knet.angle_arc((^f32)(rawptr(&truth[off + i * 4]))^, (^f32)(rawptr(&shown[off + i * 4]))^)
				(^f32)(rawptr(&err[off + i * 4]))^ = d
				if fc > 0 && abs(d) > fc {
					over = true
				}
			}
		case .F64:
			for i in 0 ..< f.size / 8 {
				d := (^f64)(rawptr(&shown[off + i * 8]))^ - (^f64)(rawptr(&truth[off + i * 8]))^
				(^f64)(rawptr(&err[off + i * 8]))^ = d
				if fc > 0 && abs(d) > f64(fc) {
					over = true
				}
			}
		}
	}
	if over {
		for i in 0 ..< len(err) {
			err[i] = 0
		}
	}
}

// One frame of exponential decay per field: err *= 0.5^(dt/half_life), where a
// field's own glide half-life (Field_Desc.glide > 0) overrides `halflife`, the
// lane default. Per-field k is why a slow-gliding avatar and a snappy ball can
// share one lane.
predict_error_decay :: proc(err: []u8, desc: ^knet.Entity_Desc, dt: f64, halflife: f64) {
	off := 0
	for f in desc.fields {
		if .Predicted not_in f.flags {
			continue
		}
		defer off += f.size
		if .Interp not_in f.flags {
			continue
		}
		hl := f.glide > 0 ? f64(f.glide) : halflife
		k := f32(math.pow(0.5, dt / hl))
		#partial switch f.lerp {
		case .F32, .Angle: // an angle error is already the short arc — plain decay
			for i in 0 ..< f.size / 4 {
				(^f32)(rawptr(&err[off + i * 4]))^ *= k
			}
		case .F64:
			for i in 0 ..< f.size / 8 {
				(^f64)(rawptr(&err[off + i * 8]))^ *= f64(k)
			}
		}
	}
}

// Present: add the decayed error onto the entity's float interp fields (the
// caller restores the sim state first, so this is shown = truth + err).
predict_error_apply :: proc(entity: rawptr, desc: ^knet.Entity_Desc, err: []u8) {
	off := 0
	for f in desc.fields {
		if .Predicted not_in f.flags {
			continue
		}
		defer off += f.size
		if .Interp not_in f.flags {
			continue
		}
		base := uintptr(entity) + f.offset
		#partial switch f.lerp {
		case .F32:
			for i in 0 ..< f.size / 4 {
				(^f32)(rawptr(base + uintptr(i * 4)))^ += (^f32)(rawptr(&err[off + i * 4]))^
			}
		case .Angle:
			for i in 0 ..< f.size / 4 {
				p := (^f32)(rawptr(base + uintptr(i * 4)))
				// add the gliding error, then keep the shown value in (-π, π]
				p^ = knet.angle_arc(0, p^ + (^f32)(rawptr(&err[off + i * 4]))^)
			}
		case .F64:
			for i in 0 ..< f.size / 8 {
				(^f64)(rawptr(base + uintptr(i * 8)))^ += (^f64)(rawptr(&err[off + i * 8]))^
			}
		}
	}
}

// Write the interpolation of two predict-set blobs (struct layout, the shape
// History holds) into the entity's predicted fields. alpha 0 = a, 1 = b.
predict_blend :: proc(entity: rawptr, desc: ^knet.Entity_Desc, a: []u8, b: []u8, alpha: f32) {
	off := 0
	for f in desc.fields {
		if .Predicted not_in f.flags {
			continue
		}
		dst := rawptr(uintptr(entity) + f.offset)
		if .Interp not_in f.flags {
			// Discrete: hold the earlier sample until the later one's time
			// truly arrives — the same step rule the stream ring applies.
			copy(([^]u8)(dst)[:f.size], a[off:off + f.size])
			off += f.size
			continue
		}
		ap := rawptr(&a[off])
		bp := rawptr(&b[off])
		switch f.lerp {
		case .Snap:
			copy(([^]u8)(dst)[:f.size], a[off:off + f.size])
		case .F32:
			df := ([^]f32)(dst)
			af := ([^]f32)(ap)
			bf := ([^]f32)(bp)
			for i in 0 ..< f.size / 4 {
				df[i] = af[i] + (bf[i] - af[i]) * alpha
			}
		case .F64:
			dd := ([^]f64)(dst)
			ad := ([^]f64)(ap)
			bd := ([^]f64)(bp)
			for i in 0 ..< f.size / 8 {
				dd[i] = ad[i] + (bd[i] - ad[i]) * f64(alpha)
			}
		case .Angle:
			df := ([^]f32)(dst)
			af := ([^]f32)(ap)
			bf := ([^]f32)(bp)
			for i in 0 ..< f.size / 4 {
				df[i] = knet.angle_lerp(af[i], bf[i], alpha) // shortest arc across ±π
			}
		case .Quat:
			// The stream path's nlerp, verbatim — hemisphere flip and the
			// antipode hold live in ONE place (knet), never a drifted twin.
			knet.quat_nlerp(([^]f32)(dst), ([^]f32)(ap), ([^]f32)(bp), alpha)
		case .Custom:
			f.blend(dst, ap, bp, alpha)
		}
		off += f.size
	}
}
