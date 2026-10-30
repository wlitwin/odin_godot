package replay_play

Item_Id :: distinct u16
Stack :: struct {item: Item_Id, count: u16}

// Pure bounded inventory operations. Limits are immutable game definitions;
// slot arrays and item lifetimes remain in the simulation frame.
stack_valid :: proc(stack: Stack, limit: u16) -> bool {
	return stack.item == 0 ? stack.count == 0 : stack.count > 0 && stack.count <= limit
}

inventory_count :: proc(slots: []Stack, item: Item_Id) -> u32 {
	n := u32(0)
	for stack in slots {if stack.item == item {n += u32(stack.count)}}
	return n
}

inventory_add :: proc(slots: []Stack, item: Item_Id, count, limit: u16) -> u16 {
	if item == 0 || count == 0 || limit == 0 {return 0}
	left := count
	for &stack in slots {
		if stack.item != item || stack.count >= limit {continue}
		n := min(left, limit - stack.count)
		stack.count += n; left -= n
		if left == 0 {return count}
	}
	for &stack in slots {
		if stack.item != 0 || stack.count != 0 {continue}
		n := min(left, limit)
		stack = {item, n}; left -= n
		if left == 0 {return count}
	}
	return count - left
}

inventory_take :: proc(slots: []Stack, index: int, count: u16) -> Stack {
	if index < 0 || index >= len(slots) || count == 0 {return {}}
	stack := &slots[index]
	if stack.item == 0 || stack.count == 0 {return {}}
	taken := Stack{stack.item, min(count, stack.count)}
	stack.count -= taken.count
	if stack.count == 0 {stack^ = {}}
	return taken
}

// Transfer directly between entities. Only the amount that fits leaves source.
// source must not alias destination storage; use separate entity inventories.
inventory_transfer :: proc(source: ^Stack, destination: []Stack, count, limit: u16) -> u16 {
	if source.item == 0 || source.count == 0 {return 0}
	moved := inventory_add(destination, source.item, min(count, source.count), limit)
	source.count -= moved
	if source.count == 0 {source^ = {}}
	return moved
}
