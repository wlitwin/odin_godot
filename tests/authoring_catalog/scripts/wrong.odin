//gd:extends Resource
//gd:class OtherEntry
package catalog_probe

import gd "godot:godot"

OtherEntry :: struct {
    owner: gd.Resource,
    id:    gd.Int `gd:"export"`,
}
