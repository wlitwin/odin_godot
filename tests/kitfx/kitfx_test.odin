package kit_fx_test

// Standalone tests for kit/fx's trauma shake — the zero-value legacy feel,
// every knob, coherence (the no-teleport property), and the tick/sample
// split the rotation channels ride on. No Godot runtime:
//
//   odin test tests/kitfx -collection:godot=$PWD

import "core:math"
import "core:testing"
import kfx "godot:kit/fx"

// The zero-value Shake must trace the legacy formula EXACTLY — scrapyard and
// every existing consumer ships with `kfx.Shake{}` and expects the kit feel
// (7 px, trauma², 1.6/s decay, the 91.7/113.3 sine pair) bit for bit.
@(test)
zero_value_is_the_legacy_feel :: proc(t: ^testing.T) {
	s := kfx.Shake{}
	kfx.shake_add(&s, 1)
	dt := 1.0 / 60.0
	lt, ltr: f32 = 0, 1
	for _ in 0 ..< 30 {
		ox, oy := kfx.shake_offset(&s, dt)
		ltr = max(ltr - 1.6*f32(dt), 0)
		lt += f32(dt)
		amp := ltr * ltr * 7
		testing.expect_value(t, ox, amp*math.sin(lt*91.7))
		testing.expect_value(t, oy, amp*math.sin(lt*113.3+1.7))
	}
}

@(test)
knobs_scale_shape_and_swap :: proc(t: ^testing.T) {
	dt := 1.0 / 60.0

	// max_offset scales linearly.
	a := kfx.Shake{}
	b := kfx.Shake{max_offset = 14}
	kfx.shake_add(&a, 1)
	kfx.shake_add(&b, 1)
	ax, ay := kfx.shake_offset(&a, dt)
	bx, by := kfx.shake_offset(&b, dt)
	testing.expect(t, abs(bx-2*ax) < 1e-4 && abs(by-2*ay) < 1e-4, "double max_offset = double offset")

	// decay: a faster decay leaves less trauma after the same tick.
	c := kfx.Shake{decay = 8}
	kfx.shake_add(&c, 1)
	kfx.shake_tick(&c, dt)
	testing.expect(t, c.trauma < a.trauma, "decay knob drains faster than the default")

	// exponent: cubed whispers below squared at partial trauma.
	d := kfx.Shake{exponent = 3}
	e := kfx.Shake{}
	kfx.shake_add(&d, 0.5)
	kfx.shake_add(&e, 0.5)
	kfx.shake_tick(&d, dt)
	kfx.shake_tick(&e, dt)
	testing.expect(t, abs(kfx.shake_sample(&d, kfx.SHAKE_X)) < abs(kfx.shake_sample(&e, kfx.SHAKE_X)),
		"trauma³ < trauma² below full trauma")

	// a custom noise driver is used verbatim, on every channel.
	flat :: proc(channel: int, tm: f32) -> f32 {return 1}
	f := kfx.Shake{noise = flat}
	kfx.shake_add(&f, 1)
	fx, fy := kfx.shake_offset(&f, dt)
	want := (1 - f32(1.6)*f32(dt)) * (1 - f32(1.6)*f32(dt)) * 7
	testing.expect(t, abs(fx-want) < 1e-4 && fx == fy, "flat driver → amp on both axes")

	// the shipped simplex driver stays in [-1, 1].
	for i in 0 ..< 500 {
		v := kfx.shake_noise_simplex(kfx.SHAKE_X, f32(i)*0.01)
		testing.expect(t, v >= -1 && v <= 1, "simplex driver in unit range")
	}
}

// The property the trauma talk demands of the jitter: adjacent frames land
// near each other (pan, don't teleport) — for both shipped drivers. The sine
// driver's worst slope is amp·freq = 7·113.3 px/s → < 3.4 px at 240 fps;
// fresh per-frame randoms would jump up to 14 px.
@(test)
coherent_never_teleports :: proc(t: ^testing.T) {
	drivers := [?]kfx.Shake_Noise{nil, kfx.shake_noise_simplex}
	for drv in drivers {
		s := kfx.Shake{noise = drv}
		kfx.shake_add(&s, 1)
		px, py := kfx.shake_offset(&s, 1.0/240)
		for _ in 0 ..< 200 {
			x, y := kfx.shake_offset(&s, 1.0/240)
			testing.expect(t, abs(x-px) < 4 && abs(y-py) < 4, "adjacent frames stay close")
			px, py = x, y
		}
	}
}

@(test)
settles_exactly_home_and_stays :: proc(t: ^testing.T) {
	s := kfx.Shake{}
	kfx.shake_add(&s, 1)
	for _ in 0 ..< 300 {kfx.shake_offset(&s, 1.0/60)} // 5 s ≫ the ~0.6 s settle
	x, y := kfx.shake_offset(&s, 1.0/60)
	testing.expect(t, x == 0 && y == 0 && s.trauma == 0, "settled shake is exactly home")
	t0 := s.t
	kfx.shake_tick(&s, 1.0/60)
	testing.expect(t, s.t == t0, "idle tick does not advance the clock")
}

// The per-source cap: rapid fire (add rate > decay rate) must HOLD at the
// cap instead of ratcheting to a full slam, a bigger uncapped event must
// still slam past it, and a capped add during that slam must be a no-op —
// never a damper.
@(test)
capped_add_holds_under_rapid_fire :: proc(t: ^testing.T) {
	s := kfx.Shake{}
	// A 0.25 kick every 0.15 s vs 1.6/s decay — uncapped this climbs to 1.
	for _ in 0 ..< 100 {
		kfx.shake_add(&s, 0.25, 0.35)
		kfx.shake_tick(&s, 0.15)
	}
	kfx.shake_add(&s, 0.25, 0.35)
	testing.expect(t, s.trauma <= 0.35, "autofire never sums past its cap")
	testing.expect(t, s.trauma > 0.3, "…but each shot still lands a fresh kick")

	// The explosion outranks the cap; a capped shot mid-slam changes nothing.
	kfx.shake_add(&s, 0.6)
	banked := s.trauma
	testing.expect(t, banked > 0.35, "uncapped event slams past a source cap")
	kfx.shake_add(&s, 0.25, 0.35)
	testing.expect_value(t, s.trauma, banked)

	// Default cap is 1 — the legacy signature and clamp are unchanged.
	kfx.shake_add(&s, 5)
	testing.expect_value(t, s.trauma, f32(1))
}

@(test)
rotation_channels_sample_without_ticking :: proc(t: ^testing.T) {
	s := kfx.Shake{}
	kfx.shake_add(&s, 1)
	kfx.shake_tick(&s, 0.01)
	t0, tr0 := s.t, s.trauma

	r := kfx.shake_roll(&s)
	roll, pitch, yaw := kfx.shake_angles(&s)
	testing.expect_value(t, r, roll)
	testing.expect(t, s.t == t0 && s.trauma == tr0, "sampling never advances the model")
	testing.expect(t, roll != 0 && pitch != 0 && yaw != 0, "rotation channels alive at full trauma")
	testing.expect(t, roll != pitch && pitch != yaw, "channels are independent streams")

	// max_roll override rescales the same underlying sample.
	s2 := kfx.Shake{max_roll = 1}
	kfx.shake_add(&s2, 1)
	kfx.shake_tick(&s2, 0.01)
	testing.expect(t, abs(kfx.shake_roll(&s2)*kfx.SHAKE_MAX_ROLL-roll) < 1e-5, "max_roll scales the channel")
}
