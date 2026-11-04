package box3d

RECOVERY_FORMAT :: 1
RECOVERY_MAX_ASSETS :: 8
RECOVERY_MAX_BYTES :: 512 * 1024
RECOVERY_MAX_SOURCE_IMAGE_BYTES :: 2 * 1024 * 1024
RECOVERY_WRITE_RESERVE_BYTES :: 8 * 1024 * 1024
Recovery_Asset_Kind :: enum u32 {
	Box     = 1,
	Sphere  = 2,
	Capsule = 3,
	Hull = 4,
	Mesh = 5,
}
Recovery_Asset :: struct {
	id:       u32,
	kind:     Recovery_Asset_Kind,
	a, b:     Vec3,
	radius:   f32,
	reserved: u32,
}
Recovery_Config :: struct {
	profile:                                                       u64,
	build_target:                                                  [32]u8,
	max_bytes, max_dto_bytes:                                      u64,
	max_bodies, max_shapes, max_contacts, max_joints, max_sensors: u32,
	max_sparse_slots, max_tree_nodes, max_manifolds, max_visitors: u32,
	max_pending_sensors, max_pending_contacts:                     u32,
}
Recovery_Identity :: struct {
	solver_format, recovery_format:      u32,
	profile:                             u64,
	build_target, assets, solver_schema: [32]u8,
}
Recovery_Diagnostic :: struct {
	offset:                         u64,
	section, record, field, reason: u32,
}
// One explicit owner of a copied immutable catalog. Assignment aliases ownership.
Recovery_Catalog :: struct {
	_handle: rawptr,
}

AUTHORING_ASSET_VERSION :: 2
AUTHORING_RECOVERY_FORMAT :: 2
// Narrow borrowed C input only. Catalog creation copies all pointed-to arrays.
Recovery_Asset_V2 :: struct {
 version,struct_bytes:u32,
 base:Recovery_Asset,
 vertices:[^]Vec3,
 indices:[^]u32,
 vertex_count,triangle_count:u32,
}
when size_of(rawptr)==8{
 #assert(size_of(Recovery_Asset_V2)==72&&align_of(Recovery_Asset_V2)==8)
 #assert(offset_of(Recovery_Asset_V2,base)==8&&offset_of(Recovery_Asset_V2,vertices)==48&&offset_of(Recovery_Asset_V2,indices)==56)
}
authoring_asset_abi_check :: proc()->Status{
 if status:=recovery_abi_check();status!=.Ok{return status}
 offsets:=[7]uintptr{offset_of(Recovery_Asset_V2,version),offset_of(Recovery_Asset_V2,struct_bytes),offset_of(Recovery_Asset_V2,base),offset_of(Recovery_Asset_V2,vertices),offset_of(Recovery_Asset_V2,indices),offset_of(Recovery_Asset_V2,vertex_count),offset_of(Recovery_Asset_V2,triangle_count)}
 for expected,i in offsets{size,alignment,offset:u32;status:=c_authoring_asset_layout(u32(i),&size,&alignment,&offset);if status!=.Ok{return status};if size!=size_of(Recovery_Asset_V2)||alignment!=align_of(Recovery_Asset_V2)||uintptr(offset)!=expected{return .Incompatible}}
 return .Ok
}
recovery_catalog_create_v2 :: proc(config:Recovery_Config,assets:[]Recovery_Asset_V2)->(catalog:Recovery_Catalog,status:Status){
 status=authoring_asset_abi_check();if status!=.Ok{return}
 if len(assets)==0||len(assets)>RECOVERY_MAX_ASSETS{return {},.Capacity}
 config:=config;status=c_recovery_catalog_create_v2(&config,raw_data(assets),u32(len(assets)),&catalog._handle);return
}
recovery_catalog_create_v3 :: proc(config:Recovery_Config,assets:[]Recovery_Asset_V2)->(catalog:Recovery_Catalog,status:Status){
 status=authoring_asset_abi_check();if status!=.Ok{return}
 if len(assets)==0||len(assets)>RECOVERY_MAX_ASSETS{return {},.Capacity}
 config_copy:=config;status=c_recovery_catalog_create_v3(&config_copy,raw_data(assets),u32(len(assets)),&catalog._handle);return
}
// Uses the catalog's retained immutable geometry. Material/filter/event flags
// remain the actual per-instance definition, including sensors.
recovery_catalog_shape :: proc(catalog:^Recovery_Catalog,asset_id:u32,body:Body,definition:Shape_Def)->(shape:Shape,status:Status){
 if catalog==nil||catalog._handle==nil||asset_id==0{return 0,.Invalid_Argument}
 definition:=definition;status=c_recovery_catalog_shape(catalog._handle,asset_id,body,&definition,&shape);return
}

recovery_abi_check :: proc() -> Status {
	if s := abi_check(); s != .Ok {return s}
	if c_recovery_format() != RECOVERY_FORMAT {return .Incompatible}
	checks := [?]struct {
		id, size, align: u32,
		offsets:         []uintptr,
	} {
		{
			1,
			size_of(Recovery_Config),
			align_of(Recovery_Config),
			[]uintptr {
				offset_of(Recovery_Config, profile),
				offset_of(Recovery_Config, build_target),
				offset_of(Recovery_Config, max_bytes),
				offset_of(Recovery_Config, max_dto_bytes),
				offset_of(Recovery_Config, max_bodies),
				offset_of(Recovery_Config, max_shapes),
				offset_of(Recovery_Config, max_contacts),
				offset_of(Recovery_Config, max_joints),
				offset_of(Recovery_Config, max_sensors),
				offset_of(Recovery_Config, max_sparse_slots),
				offset_of(Recovery_Config, max_tree_nodes),
				offset_of(Recovery_Config, max_manifolds),
				offset_of(Recovery_Config, max_visitors),
				offset_of(Recovery_Config, max_pending_sensors),
				offset_of(Recovery_Config, max_pending_contacts),
			},
		},
		{
			2,
			size_of(Recovery_Asset),
			align_of(Recovery_Asset),
			[]uintptr {
				offset_of(Recovery_Asset, id),
				offset_of(Recovery_Asset, kind),
				offset_of(Recovery_Asset, a),
				offset_of(Recovery_Asset, b),
				offset_of(Recovery_Asset, radius),
				offset_of(Recovery_Asset, reserved),
			},
		},
		{
			3,
			size_of(Recovery_Identity),
			align_of(Recovery_Identity),
			[]uintptr {
				offset_of(Recovery_Identity, solver_format),
				offset_of(Recovery_Identity, recovery_format),
				offset_of(Recovery_Identity, profile),
				offset_of(Recovery_Identity, build_target),
				offset_of(Recovery_Identity, assets),
				offset_of(Recovery_Identity, solver_schema),
			},
		},
		{
			4,
			size_of(Recovery_Diagnostic),
			align_of(Recovery_Diagnostic),
			[]uintptr {
				offset_of(Recovery_Diagnostic, offset),
				offset_of(Recovery_Diagnostic, section),
				offset_of(Recovery_Diagnostic, record),
				offset_of(Recovery_Diagnostic, field),
				offset_of(Recovery_Diagnostic, reason),
			},
		},
	}
	for check in checks {for expected, i in check.offsets {size, align, offset: u32; s := c_recovery_layout(check.id, u32(i), &size, &align, &offset); if s != .Ok || size != check.size || align != check.align || uintptr(offset) != expected {return .Incompatible}}}
	return .Ok
}
// Defaults supply actual embedded native build identity. Do not override it.
recovery_config_default :: proc() -> (config: Recovery_Config) {
	if recovery_abi_check() != .Ok {panic("Box3D recovery ABI mismatch")}
	if c_recovery_config_default(&config) !=
	   .Ok {panic("Box3D recovery initialization failed")}; return
}
recovery_asset_box :: proc(id: u32, half_extents: Vec3) -> Recovery_Asset {return{
		id = id,
		kind = .Box,
		a = half_extents,
	}}
recovery_asset_sphere :: proc(id: u32, center: Vec3, radius: f32) -> Recovery_Asset {return{
		id = id,
		kind = .Sphere,
		a = center,
		radius = radius,
	}}
recovery_asset_capsule :: proc(id: u32, a, b: Vec3, radius: f32) -> Recovery_Asset {return{
		id = id,
		kind = .Capsule,
		a = a,
		b = b,
		radius = radius,
	}}
recovery_catalog_create :: proc(
	config: Recovery_Config,
	assets: []Recovery_Asset,
) -> (
	catalog: Recovery_Catalog,
	status: Status,
) {
	status = recovery_abi_check(
		
	); if status != .Ok {return}; if len(assets) > RECOVERY_MAX_ASSETS {return {}, .Capacity}
	config :=
		config; status = c_recovery_catalog_create(&config, raw_data(assets), u32(len(assets)), &catalog._handle); return
}
recovery_catalog_clone :: proc(
	catalog: ^Recovery_Catalog,
) -> (
	clone: Recovery_Catalog,
	status: Status,
) {
	if catalog == nil ||
	   catalog._handle ==
		   nil {return {}, .Invalid_Argument}; status = c_recovery_catalog_clone(catalog._handle, &clone._handle); return
}
recovery_catalog_destroy :: proc(catalog: ^Recovery_Catalog) -> Status {
	if catalog ==
	   nil {return .Invalid_Argument}; if status:=c_recovery_catalog_release(catalog._handle);status!=.Ok{return status}; catalog^ = {}; return .Ok
}
recovery_catalog_identity :: proc(
	catalog: ^Recovery_Catalog,
) -> (
	identity: Recovery_Identity,
	status: Status,
) {
	if catalog == nil ||
	   catalog._handle ==
		   nil {return {}, .Invalid_Argument}; status = c_recovery_identity_get(catalog._handle, &identity); return
}
recovery_write :: proc(
	catalog: ^Recovery_Catalog,
	snapshot: ^Snapshot,
	bytes: []u8,
) -> (
	required: u64,
	status: Status,
) {
	if catalog == nil ||
	   catalog._handle == nil ||
	   snapshot == nil ||
	   snapshot._handle == nil {return 0, .Invalid_Argument}
	data := raw_data(bytes); if len(bytes) == 0 {data = nil}
	status = c_recovery_write(
		catalog._handle,
		snapshot._handle,
		data,
		u64(len(bytes)),
		&required,
		nil,
	); return
}
recovery_read :: proc(
	catalog: ^Recovery_Catalog,
	bytes: []u8,
	additional_owned_bytes: u64 = 0,
) -> (
	snapshot: Snapshot,
	status: Status,
) {
	if catalog == nil || catalog._handle == nil {return {}, .Invalid_Argument}
	status = c_recovery_read(
		catalog._handle,
		raw_data(bytes),
		u64(len(bytes)),
		additional_owned_bytes,
		&snapshot._handle,
		nil,
	); return
}
recovery_write_diagnostic :: proc(
	catalog: ^Recovery_Catalog,
	snapshot: ^Snapshot,
	bytes: []u8,
) -> (
	required: u64,
	status: Status,
	diagnostic: Recovery_Diagnostic,
) {
	if catalog == nil ||
	   catalog._handle == nil ||
	   snapshot == nil ||
	   snapshot._handle == nil {return 0, .Invalid_Argument, {}}
	data := raw_data(bytes); if len(bytes) == 0 {data = nil}
	status = c_recovery_write(
		catalog._handle,
		snapshot._handle,
		data,
		u64(len(bytes)),
		&required,
		&diagnostic,
	); return
}
recovery_read_diagnostic :: proc(
	catalog: ^Recovery_Catalog,
	bytes: []u8,
	additional_owned_bytes: u64 = 0,
) -> (
	snapshot: Snapshot,
	status: Status,
	diagnostic: Recovery_Diagnostic,
) {
	if catalog == nil || catalog._handle == nil {return {}, .Invalid_Argument, {}}
	status = c_recovery_read(
		catalog._handle,
		raw_data(bytes),
		u64(len(bytes)),
		additional_owned_bytes,
		&snapshot._handle,
		&diagnostic,
	); return
}

// Readonly complete profile admission on an idle execution before capture/publish.
// Actual export continues through recovery_write and its 8MiB reserve.
recovery_world_admit :: proc(
	catalog: ^Recovery_Catalog,
	world: World,
	additional_owned_bytes: u64 = 0,
) -> (
	required: u64,
	status: Status,
) {
	if catalog == nil || catalog._handle == nil {return 0, .Invalid_Argument}
	status = c_recovery_world_admit(
		catalog._handle,
		world,
		additional_owned_bytes,
		&required,
		nil,
	); return
}
recovery_world_admit_diagnostic :: proc(
	catalog: ^Recovery_Catalog,
	world: World,
	additional_owned_bytes: u64 = 0,
) -> (
	required: u64,
	status: Status,
	diagnostic: Recovery_Diagnostic,
) {
	if catalog == nil || catalog._handle == nil {return 0, .Invalid_Argument, {}}
	status = c_recovery_world_admit(
		catalog._handle,
		world,
		additional_owned_bytes,
		&required,
		&diagnostic,
	); return
}

// Existing full decoder and constructor checks, then coupled fresh metadata
// before publishing the owner; no second snapshot_info getter is needed.
recovery_read_info :: proc(
	catalog: ^Recovery_Catalog,
	bytes: []u8,
	additional_owned_bytes: u64 = 0,
) -> (
	snapshot: Snapshot,
	info: Snapshot_Info,
	status: Status,
) {
	if catalog == nil || catalog._handle == nil {return {}, {}, .Invalid_Argument}
	status = c_recovery_read_info(
		catalog._handle,
		raw_data(bytes),
		u64(len(bytes)),
		additional_owned_bytes,
		&snapshot._handle,
		&info.metrics.image_used,
		&info.metrics.image_capacity,
		&info.metrics.geometry_bytes,
		&info.metrics.geometry_count,
		&info.storage.normalized_bytes,
		&info.storage.wrapper_malloc_bytes,
		&info.storage.native_requested_bytes,
		nil,
	); return
}
recovery_read_info_diagnostic :: proc(
	catalog: ^Recovery_Catalog,
	bytes: []u8,
	additional_owned_bytes: u64 = 0,
) -> (
	snapshot: Snapshot,
	info: Snapshot_Info,
	status: Status,
	diagnostic: Recovery_Diagnostic,
) {
	if catalog == nil || catalog._handle == nil {return {}, {}, .Invalid_Argument, {}}
	status = c_recovery_read_info(
		catalog._handle,
		raw_data(bytes),
		u64(len(bytes)),
		additional_owned_bytes,
		&snapshot._handle,
		&info.metrics.image_used,
		&info.metrics.image_capacity,
		&info.metrics.geometry_bytes,
		&info.metrics.geometry_count,
		&info.storage.normalized_bytes,
		&info.storage.wrapper_malloc_bytes,
		&info.storage.native_requested_bytes,
		&diagnostic,
	); return
}
