#+build linux
package kit_authoring_demo

import "core:os"
import "core:strings"

native_image_count :: proc()->int {
	data,error:=os.read_entire_file("/proc/self/maps",context.allocator);if error!=nil{return -1};defer delete(data)
	lines:=strings.split(string(data),"\n");defer delete(lines)
	paths:=make(map[string]bool);defer delete(paths)
	for line in lines {
		if !strings.contains(line,"libogb3"){continue}
		if start:=strings.index_byte(line,'/');start>=0{paths[line[start:]]=true}
	}
	return len(paths)
}
