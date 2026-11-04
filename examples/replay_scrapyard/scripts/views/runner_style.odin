//gd:extends Resource
//gd:class ScrapRunnerStyle
package scrap_views

import gd "godot:godot"

ScrapRunnerStyle :: struct {
    owner: gd.Resource,
    id: gd.Int `gd:"export,range=0:2:1"`,
    idle: ^gd.Resource `gd:"export,resource=Texture2D"`,
    run: ^gd.Resource `gd:"export,resource=Texture2D"`,
}
