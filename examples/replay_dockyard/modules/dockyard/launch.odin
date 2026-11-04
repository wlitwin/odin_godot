package dockyard_duo
import "core:strconv"
import gd "godot:godot"
launch_int :: proc(environment:cstring,query:string,fallback:int)->int{
 text:=gd.launch_param(environment,query)
 if len(text)==0{return fallback}
 value,valid:=strconv.parse_int(text);return valid?value:fallback
}
