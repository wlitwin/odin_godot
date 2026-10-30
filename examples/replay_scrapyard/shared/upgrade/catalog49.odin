package scrapyard_upgrade

import "core:fmt"
import mapping "../upgrade_catalog"
import content "../content"
import frozen "../revisions/content49"

// All source dependencies are frozen independently of the live content package.
Catalog_49 :: frozen.Catalog_49

pulse_additions :: proc() -> [32]string {
	paths: [32]string
	for i in 0 ..< 8 {
		for field, j in ([4]string{"windup", "cooldown", "radius", "damage"}) {
			paths[i * 4 + j] = fmt.tprintf("$.mobs[%d].pulse.%s", i, field)
		}
	}
	return paths
}

catalog_current :: proc(old: Catalog_49) -> content.Catalog {
	paths := pulse_additions()
	// Content 49 never had pulse attacks: explicit zero defaults preserve its rules.
	return mapping.from49(old, paths[:])
}

catalog_49 :: proc(old: content.Catalog) -> Catalog_49 {
	paths := pulse_additions()
	return mapping.to49(old, paths[:])
}

name_49 :: proc(text: string) -> struct {
		count: u8,
		bytes: [31]u8,
	} {
	value := content.name(text)
	return {value.count, value.bytes}
}
