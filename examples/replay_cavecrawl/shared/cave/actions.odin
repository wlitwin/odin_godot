package cave

import "core:math"
import r "godot:replay"
import p "godot:replay/play"
import lb "godot:replay/lobby"

act :: proc(w: ^World, seat: u16, action: Action, ctx: ^r.Step(Event)) -> bool {
	if seat < 1 || seat > SEATS {return false}
	return act_at(w,seat,action,w.players[seat-1].position,ctx)
}

// Explicit action-time origin. The ordinary model passes its current position;
// external-owner profiles can supply a validated claim without moving the actor.
act_at :: proc(w:^World,seat:u16,action:Action,origin:[2]f32,ctx:^r.Step(Event))->bool {
	if seat<1 || seat>SEATS {return false}
	if action.verb==.Lobby {
		if !w.players[seat-1].connected {return false}
		result:=lb.apply(&w.lobby,seat,action.lobby,can_restart=w.won)
		if result==.Started {enter_floor(w,.Initial)}
		if result==.Restarted {
			w.won=false;w.depth=1;w.dens_used=0
			enter_floor(w,.Restart)
		}
		return result!=.Rejected
	}
	if w.won || w.lobby.phase==.Waiting {return false}
	player := &w.players[seat - 1]
	if !player.connected || player.hp <= 0 {return false}
	def := world_floor(w)
	kind := Event_Kind.None
	amount := i32(0)
	#partial switch action.verb {
	case .Take:
		if action.index >= 8 || !p.in_reach(origin, def.chest, REACH) {return false}
		stack := &w.chest[action.index]
		amount = i32(p.inventory_transfer(stack, player.bag[:], 99, stack_limit(stack.item)))
		if amount == 0 {return false}
		kind = .Loot
	case .Door:
		if !p.in_reach(origin, def.door, REACH) {return false}
		w.door_open = !w.door_open
		kind = .Door
	case .Drop:
		if action.index >= 6 {return false}
		stack := player.bag[action.index]
		if stack.item == 0 {return false}
		if !spawn_pickup(w, player.position + [2]f32{24, 0}, stack) {return false}
		player.bag[action.index] = {}
		kind, amount = .Loot, -i32(stack.count)
	case .Grab:
		pickup, exists := r.pool_get(&w.pickups, r.Handle(Pickup){u32(action.index), action.generation})
		if !exists || !p.in_reach(origin, pickup.position, REACH) {return false}
		amount = i32(p.inventory_transfer(&pickup.stack, player.bag[:], max(u16), stack_limit(pickup.stack.item)))
		if amount == 0 {return false}
		if pickup.stack.count == 0 {r.pool_remove(&w.pickups, r.Handle(Pickup){u32(action.index), action.generation})}
		kind = .Loot
	case .Throw:
		length := math.sqrt(action.aim[0] * action.aim[0] + action.aim[1] * action.aim[1])
		if length == 0 || player.rock_cd != 0 || player.stamina < 3 {return false}
		_, spawned := r.pool_insert(&w.rocks, Rock{position = origin,
			velocity = action.aim * (ROCK_SPEED / length), left = ROCK_TTL, shooter = seat})
		if !spawned {return false}
		player.rock_cd, player.stamina = 20, player.stamina - 3
		kind = .Thrown
	case .Heal:
		if player.hp >= MAX_HP || player.heal_cd != 0 || player.stamina < 5 {return false}
		player.hp = min(player.hp + 25, MAX_HP)
		player.heal_cd, player.stamina = 60, player.stamina - 5
		kind, amount = .Revived, 25
	case .Revive:
		if action.index >= SEATS {return false}
		friend := &w.players[action.index]
		if !friend.connected || friend.hp != 0 || !p.in_reach(origin, friend.position, REACH) {return false}
		friend.hp, friend.respawn_at = 30, 0
		kind, amount = .Revived, 30
	case .Carry:
		if w.relic.carrier != 0 || !p.in_reach(origin, w.relic.position, REACH) {return false}
		w.relic.carrier = seat
		w.relic.version += 1
		kind = .Carry
	case .Set_Down:
		if w.relic.carrier != seat {return false}
		w.relic.carrier = 0
		w.relic.version += 1
		kind = .Carry
	case .None: return false
	}
	event_position:=player.position
	if action.verb==.Take || action.verb==.Door || action.verb==.Grab || action.verb==.Throw || action.verb==.Revive || action.verb==.Carry {event_position=origin}
	r.emit(ctx, u64(seat), 100 + u64(action.verb), Event{kind, event_position, seat, amount})
	return true
}

spawn_pickup :: proc(w: ^World, position: [2]f32, stack: p.Stack) -> bool {
	if stack.item == 0 || stack.count == 0 {return true}
	_, ok := r.pool_insert(&w.pickups, Pickup{position, stack})
	return ok
}

spill :: proc(w: ^World, player: ^Player) {
	for &stack in player.bag {
		if stack.item == 0 {continue}
		if spawn_pickup(w, player.position + [2]f32{24, 0}, stack) {stack = {}}
	}
}

world_items :: proc(w: ^World, item: p.Item_Id) -> u32 {
	count := p.inventory_count(w.chest[:], item)
	for player in w.players {bag := player.bag; count += p.inventory_count(bag[:], item)}
	for pickup, i in w.pickups.values {if w.pickups.alive[i] && pickup.stack.item == item {count += u32(pickup.stack.count)}}
	return count
}
