package scrapyard_catalog_upgrade

import "core:strings"
import sc "godot:replay/schema"
import e "godot:replay/evolution"
import current "../content"
import old49 "../revisions/content49"
import old50 "../revisions/content50"

// Explicit migration decision: Ability_Family keeps the existing 0..4 meanings,
// adds Turret=5, and every old ability gets a zero/disabled turret definition.
// All other prior leaves must preserve their exact canonical bytes and types.
copy_catalog :: proc(source: $S, $D: typeid) -> D {
	a, b: sc.Schema
	defer sc.destroy(&a)
	defer sc.destroy(&b)
	if sc.init(&a, S).error != .None || sc.init(&b, D).error != .None {
		panic("catalog revision schema")
	}
	input, output := make([]u8, a.wire_size), make([]u8, b.wire_size)
	defer delete(input)
	defer delete(output)
	if sc.encode(&a, source, input).error != .None {
		panic("invalid source catalog")
	}
	index := make(map[string]int)
	defer delete(index)
	for field, i in b.fields {
		index[field.path] = i
	}
	for field in a.fields {
		at, found := index[field.path]
		if !found {
			if strings.contains(field.path, ".turret.") {
				continue
			}
			panic("unmapped prior catalog field")
		}
		target := b.fields[at]
		if field.kind != target.kind ||
		   field.width != target.width ||
		   field.authority_only != target.authority_only ||
		   field.bit_mask != target.bit_mask {
			panic("changed catalog field")
		}
		if field.kind == .Enumeration {
			family := strings.has_prefix(field.path, "$.abilities[") && strings.has_suffix(field.path, ".family")
			if !family && len(field.enum_names) != len(target.enum_names) {
				panic("unreviewed enum conversion")
			}
			for name, i in field.enum_names {
				if family && i == 5 && len(target.enum_names) == 5 {
					continue
				}
				if i >= len(target.enum_names) ||
				   name != target.enum_names[i] ||
				   field.enum_values[i] != target.enum_values[i] {
					panic("enum meaning changed")
				}
			}
		}
		copy(
			output[target.wire_offset:target.wire_offset + target.width],
			input[field.wire_offset:field.wire_offset + field.width],
		)
	}
	result: D
	if sc.decode(&b, &result, output).error != .None {
		panic("invalid catalog conversion")
	}
	return result
}

from50 :: proc(source: old50.Catalog_50) -> current.Catalog {
	return copy_catalog(source, current.Catalog)
}

to50 :: proc(source: current.Catalog) -> old50.Catalog_50 {
	value := source
	// Historical-model projections/fixture builders cannot invent a Turret enum
	// in an old contract. Live upgrades use from50 and never discard old data.
	for &ability in value.abilities {
		if ability.family == .Turret {
			ability = {}
		}
	}
	for value.ability_count > 0 && value.abilities[value.ability_count - 1].name.count == 0 {
		value.ability_count -= 1
	}
	return copy_catalog(value, old50.Catalog_50)
}

from49 :: proc(source: old49.Catalog_49, added: []string) -> current.Catalog {
	bridge, report := e.copy_preserved(source, old50.Catalog_50{}, added)
	if report.error != .None {
		panic("unreviewed catalog49 conversion")
	}
	return from50(bridge)
}

to49 :: proc(source: current.Catalog, removed: []string) -> old49.Catalog_49 {
	bridge := to50(source)
	result, report := e.remove_added(bridge, old49.Catalog_49{}, removed)
	if report.error != .None {
		panic("unreviewed catalog49 projection")
	}
	return result
}
