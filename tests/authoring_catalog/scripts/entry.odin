//gd:extends Resource
//gd:class CatalogEntry
package catalog_probe

import gd "godot:godot"

CatalogEntry :: struct {
    owner: gd.Resource,
    id:    gd.Int `gd:"export"`,
}
