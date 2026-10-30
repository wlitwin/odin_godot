package scrapyard_profile

import game "../game"
import content "../content"

AUTOMATIC_ALL :: u8(15) // skin, iron, Q, E

// Automatic is local intent. The network/game only receives resolved choices.
resolve :: proc(value: game.Profile, automatic: u8, seat: u16, catalog: ^content.Catalog) -> (game.Profile, bool) {
	if seat == 0 || seat > game.SEATS || automatic & ~AUTOMATIC_ALL != 0 {
		return {}, false
	}
	next := value
	if automatic & 1 != 0 {
		next.look = u8(seat) % game.LOOKS
	}
	if automatic & 2 != 0 {
		if catalog.gun_count == 0 {
			return {}, false
		}
		id := u8((int(seat) - 1) % int(catalog.gun_count))
		next.iron = content.gun_present(catalog, id) ? id : content.next_gun(catalog, id)
	}
	for slot in 0 ..< 2 {
		if automatic & (u8(4) << uint(slot)) == 0 {
			continue
		}
		id := u8(slot + 1)
		next.abilities[slot] = content.ability_present(catalog, id) ? id : content.next_ability(catalog, 0)
	}
	return next,
		game.profile_valid(next) &&
		content.gun_present(catalog, next.iron) &&
		content.ability_present(catalog, next.abilities[0]) &&
		content.ability_present(catalog, next.abilities[1])
}

// Each picker traverses AUTO, then the loaded choices in ID order. Reversing
// across an endpoint returns to AUTO. Sparse catalogs never expose empty rows.
cycle :: proc(
	catalog: ^content.Catalog,
	value: game.Profile,
	automatic: u8,
	field, direction: int,
) -> (
	game.Profile,
	u8,
) {
	assert(field >= 0 && field < 4 && (direction == -1 || direction == 1) && automatic & ~AUTOMATIC_ALL == 0)
	next := value
	next.ready = false
	mask := automatic
	bit := u8(1) << uint(field)
	current := field == 0 ? int(value.look) : field == 1 ? int(value.iron) : int(value.abilities[field - 2])
	count := field == 0 ? int(game.LOOKS) : field == 1 ? int(catalog.gun_count) : int(catalog.ability_count)
	index := mask & bit != 0 ? (direction > 0 ? -1 : count) : current
	for _ in 0 ..= count {
		index += direction
		if index < 0 || index >= count {
			return next, mask | bit
		}
		present :=
			field == 0 ||
			(field == 1 ? content.gun_present(catalog, u8(index)) : content.ability_present(catalog, u8(index)))
		if !present {
			continue
		}
		mask &~= bit
		switch field {
		case 0:
			next.look = u8(index)
		case 1:
			next.iron = u8(index)
		case 2, 3:
			next.abilities[field - 2] = u8(index)
		}
		return next, mask
	}
	return next, mask | bit
}

matching_choices :: proc(a, b: game.Profile) -> bool {
	return a.look == b.look && a.iron == b.iron && a.abilities == b.abilities
}
