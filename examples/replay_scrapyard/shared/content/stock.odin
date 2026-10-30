package scrapyard_content

import sc "godot:replay/schema"
import d "godot:replay/definitions"

// Committed output of the same typed Godot bake used by interactive content_load.
// Loading is a cold-path operation; the returned catalog is an independent value.
stock :: proc() -> Catalog {
	schema: sc.Schema
	report := sc.init(&schema, Catalog)
	defer sc.destroy(&schema)
	if report.error != .None {
		panic("invalid stock schema")
	}
	value: Catalog
	_, report = sc.unpack(
		&schema,
		&value,
		#load("stock.rpldef", []u8),
		{kind = d.ARTIFACT_KIND, epoch = 1, content = 0x525343524150304b},
	)
	if report.error != .None || !valid(value) {
		panic("invalid baked stock catalog; run tools/stock.py --check")
	}
	return value
}
