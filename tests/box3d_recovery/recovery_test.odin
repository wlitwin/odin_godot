package recovery_test
import "core:fmt"
import "core:slice"
import "core:testing"
import b "godot:box3d"
ok :: proc(t: ^testing.T, s: b.Status) {testing.expect_value(t, s, b.Status.Ok)}
assets :: proc() -> [6]b.Recovery_Asset {return{
		b.recovery_asset_box(1, {6, .25, 6}),
		b.recovery_asset_box(2, {.25, .25, .25}),
		b.recovery_asset_sphere(3, {0, 0, 0}, 4),
		b.recovery_asset_sphere(4, {0, 0, 0}, .15),
		b.recovery_asset_capsule(5, {0, -.25, 0}, {0, .25, 0}, .2),
		b.recovery_asset_box(6, {.5, .5, .5}),
	}}
fixture :: proc(t: ^testing.T) -> (b.World, [32]b.Body, b.Body) {
	w, s := b.world_create(b.world_def_default()); ok(t, s)
	sd := b.shape_def_default(); sd.enable_sensor_events = 1; sd.enable_contact_events = 1
	bd := b.body_def_default(
		
	); bd.pose.position = {0, -.25, 0}; floor, fs := b.body_create(w, bd); ok(t, fs); _, fss := b.shape_box(floor, sd, {6, .25, 6}); ok(t, fss)
	bd.pose.position = {
		0,
		1,
		0,
	}; sensor, ss := b.body_create(w, bd); ok(t, ss); sensor_def := sd; sensor_def.is_sensor = 1; _, sss := b.shape_sphere(sensor, sensor_def, 4); ok(t, sss)
	bodies: [32]b.Body
	for i in 0 ..< 32 {bd = b.body_def_default(); bd.type = .Dynamic; bd.pose.position = {f32(i % 5 - 2) * .6, .45 + f32(i / 25) * .55, f32(i / 5 % 5 - 2) * .6}; body, bs := b.body_create(w, bd); ok(t, bs); bodies[i] = body; _, shs := b.shape_box(body, sd, {.25, .25, .25}); ok(t, shs)}
	hd := b.hinge_def_default(
		
	); hd.body_a = floor; hd.body_b = bodies[0]; hd.local_frame_a.position = {-1.2, .7, -1.2}; hd.enable_motor = 1; hd.motor_speed = .75; hd.max_motor_torque = 2; hd.enable_limit = 1; hd.lower_angle = -.5; hd.upper_angle = .5; _, hs := b.joint_hinge_create(w, hd); ok(t, hs)
	return w, bodies, sensor
}
wire :: proc(t: ^testing.T, c: ^b.Recovery_Catalog, s: ^b.Snapshot) -> []u8 {
	n, status, diag := b.recovery_write_diagnostic(c, s, nil)
	if status !=
	   .Ok {fmt.printf("encode rejected section%d record%d reason%d", diag.section, diag.record, diag.reason); ok(t, status); return nil}
	data := make(
		[]u8,
		int(n),
	); actual, write_status := b.recovery_write(c, s, data); ok(t, write_status); testing.expect_value(t, actual, n); return data
}
dump :: proc(t: ^testing.T, w: b.World) -> []u8 {n, s := b.world_dump(w, nil); ok(t, s); data :=
		make([]u8, int(n))
	_, rs := b.world_dump(w, data)
	ok(t, rs)
	return data}
run_32body_fixture :: proc(t: ^testing.T) {
	cfg := b.recovery_config_default(); cfg.profile = 0x5445535452454331
	table := assets(
		
	); catalog, cs := b.recovery_catalog_create(cfg, table[:]); ok(t, cs); defer b.recovery_catalog_destroy(&catalog)
	source, bodies, sensor := fixture(t); defer b.world_destroy(&source)
	target, ws := b.world_create(b.world_def_default()); ok(t, ws); defer b.world_destroy(&target)
	for tick in 1 ..= 160 {
		if tick % 30 == 0 {ok(t, b.body_apply_impulse(bodies[tick % 32], {.01, .2, 0}))}
		if tick ==
		   60 {ok(t, b.body_set_awake(bodies[7], false))}; if tick == 61 {ok(t, b.body_set_awake(bodies[7], true))}
		ok(t, b.world_step_fixed(source))
		if tick == 80 {ok(t, b.body_destroy(&sensor))}
		if tick % 20 == 0 {
			snapshot, ss := b.snapshot_capture(
				source,
			); ok(t, ss); data := wire(t, &catalog, &snapshot); if data == nil {b.snapshot_destroy(&snapshot); return}
			expected, admit_status := b.recovery_world_admit(&catalog, source)
			ok(t, admit_status); testing.expect_value(t, expected, u64(len(data)))
			decoded, decoded_info, ds, diag := b.recovery_read_info_diagnostic(&catalog, data)
			if ds ==
			   .Ok {checked, checked_status := b.snapshot_info(&decoded); ok(t, checked_status); testing.expect_value(t, checked, decoded_info)}
			if ds !=
			   .Ok {fmt.printf("decode tick%d section%d record%d field%d reason%d", tick, diag.section, diag.record, diag.field, diag.reason)}
			ok(t, ds); if ds != .Ok {delete(data); b.snapshot_destroy(&snapshot); return}
			ok(
				t,
				b.snapshot_restore(target, &decoded),
			); a := dump(t, source); z := dump(t, target); testing.expect(t, slice.equal(a, z)); delete(a); delete(z)
			recoded := wire(
				t,
				&catalog,
				&decoded,
			); testing.expect(t, slice.equal(data, recoded)); delete(recoded); delete(data); ok(t, b.snapshot_destroy(&decoded)); ok(t, b.snapshot_destroy(&snapshot))
		}
	}
	snapshot, ss := b.snapshot_capture(
		source,
	); ok(t, ss); data := wire(t, &catalog, &snapshot); defer delete(data); ok(t, b.snapshot_destroy(&snapshot)); ok(t, b.world_destroy(&source))
	decoded, ds := b.recovery_read(&catalog, data); ok(t, ds); defer b.snapshot_destroy(&decoded)
	clone, clone_status := b.recovery_catalog_clone(
		&catalog,
	); ok(t, clone_status); ok(t, b.recovery_catalog_destroy(&catalog))
	ok(t, b.snapshot_restore(target, &decoded))
	branch, bs := b.world_create(
		b.world_def_default(),
	); ok(t, bs); defer b.world_destroy(&branch); ok(t, b.snapshot_restore(branch, &decoded))
	ok(t, b.recovery_catalog_destroy(&clone))
	for _ in 0 ..< 120 {ok(t, b.world_step_fixed(target)); ok(t, b.world_step_fixed(branch)); a := dump(t, target); z := dump(t, branch); testing.expect(t, slice.equal(a, z)); delete(a); delete(z)}
}

@(test)
canonical_32body_hinge_sensor_sleep_and_source_destroy_suffix :: proc(t: ^testing.T) {
	run_32body_fixture(t)
	engine, es := b.engine_allocation_stats(); ok(t, es)
	wrapper, ws := b.snapshot_allocation_stats(); ok(t, ws)
	testing.expect_value(
		t,
		engine.live_bytes,
		u64(0),
	); testing.expect_value(t, wrapper.live_bytes, u64(0))
	fmt.printf(
		"recovery32 teardown engine=%d wrapper=%d engine_peak=%d wrapper_peak=%d\n",
		engine.live_bytes,
		wrapper.live_bytes,
		engine.high_water_bytes,
		wrapper.high_water_bytes,
	)
}
