package box3d

MOTION_FILTER_ALL :: Motion_Filter{category_bits=max(u64),mask_bits=max(u64),include_sensors=1}
// New complete deterministic query family. Native sorts the COMPLETE bounded
// result set before any copy; Capacity never publishes a truncated prefix.
query_aabb :: proc(world:World,lower,upper:Vec3,filter:Motion_Filter,out:[]Motion_Hit)->(count:u32,status:Status){
 if u64(len(out))>u64(max(u32)){return 0,.Capacity}
 if status=motion_abi_check();status!=.Ok{return};if status=domain_access_check();status!=.Ok{return}
 lo,hi,f:=lower,upper,filter;status=raw_query_aabb(world,&lo,&hi,&f,raw_data(out),u32(len(out)),&count);return
}
query_ray_sorted :: proc(world:World,origin,translation:Vec3,filter:Motion_Filter,out:[]Motion_Hit)->(count:u32,status:Status){
 if u64(len(out))>u64(max(u32)){return 0,.Capacity}
 if status=motion_abi_check();status!=.Ok{return};if status=domain_access_check();status!=.Ok{return}
 o,v,f:=origin,translation,filter;status=raw_query_ray_sorted(world,&o,&v,&f,raw_data(out),u32(len(out)),&count);return
}
query_capsule :: proc(world:World,origin:Vec3,capsule:Motion_Capsule,filter:Motion_Filter,out:[]Motion_Hit)->(count:u32,status:Status){
 if u64(len(out))>u64(max(u32)){return 0,.Capacity}
 if status=motion_abi_check();status!=.Ok{return};if status=domain_access_check();status!=.Ok{return}
 o,c,f:=origin,capsule,filter;status=raw_query_capsule(world,&o,&c,&f,raw_data(out),u32(len(out)),&count);return
}
query_capsule_cast :: proc(world:World,origin:Vec3,capsule:Motion_Capsule,translation:Vec3,filter:Motion_Filter,out:[]Motion_Hit)->(count:u32,status:Status){
 if u64(len(out))>u64(max(u32)){return 0,.Capacity}
 if status=motion_abi_check();status!=.Ok{return};if status=domain_access_check();status!=.Ok{return}
 o,c,v,f:=origin,capsule,translation,filter;status=raw_query_capsule_cast(world,&o,&c,&v,&f,raw_data(out),u32(len(out)),&count);return
}

QUERY_FILTER_ALL :: Query_Filter{category_bits = max(u64), mask_bits = max(u64)}

// count is the TOTAL available, including results that did not fit. On .Capacity
// only out[:min(len(out), int(count))] contains copied results. On any other
// failure do not consume out. Empty output slices are valid capacity queries.
// Order follows Box3D; sort copied results by stable game identity if needed.
query_overlap_aabb :: proc(world: World, lower, upper: Vec3, filter: Query_Filter, out: []Shape) -> (count: u32, status: Status) {
	lower := lower
	upper := upper
	filter := filter
	if u64(len(out)) > u64(max(u32)) {return 0, .Capacity}
	status = c_world_overlap_aabb(world, &lower, &upper, &filter, raw_data(out), u32(len(out)), &count)
	return
}

// translation is the complete ray displacement. The returned fraction is in
// [0,1]. Hits are copied records, independent of subsequent native mutations.
query_ray :: proc(world: World, origin, translation: Vec3, filter: Query_Filter, out: []Ray_Hit) -> (count: u32, status: Status) {
	origin := origin
	translation := translation
	filter := filter
	if u64(len(out)) > u64(max(u32)) {return 0, .Capacity}
	status = c_world_cast_ray(world, &origin, &translation, &filter, raw_data(out), u32(len(out)), &count)
	return
}

// Sensor_Event.began is u32 0/1 at the C boundary. Events are copied, not borrowed.
// Capture adapters' deterministic events before the next step/restore clears the
// native output buffers. Event handles can refer to destroyed objects.
world_sensor_events :: proc(world: World, out: []Sensor_Event) -> (count: u32, status: Status) {
	if u64(len(out)) > u64(max(u32)) {return 0, .Capacity}
	status = c_world_sensor_events(world, raw_data(out), u32(len(out)), &count)
	return
}
