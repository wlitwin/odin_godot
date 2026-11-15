package replay_godot_scene

import "core:fmt"
import "core:mem"
import "core:strings"
import gd "godot:godot"
import rt "godot:runtime"
import d "godot:replay/definitions"

// One owner for the complete candidate batch. Resources stay retained through
// extraction/publication, including loop iterations and failure cleanup.
Resource_Batch :: struct {
    resources: []gd.Resource,
    count:     int,
    allocator: mem.Allocator,
}

resource_batch_destroy :: proc(batch: ^Resource_Batch) {
    for resource in batch.resources[:batch.count] {
        gd.release_ref(resource)
    }

    delete(batch.resources, batch.allocator)
    batch^ = {}
}

resource_batch_load :: proc(
    batch: ^Resource_Batch,
    directory: string,
    capacity: int,
    allocator := context.allocator,
) -> d.Report {
    if len(batch.resources) > 0 || capacity < 1 || capacity > 65536 {
        return d.problem(.Invalid, directory, "invalid or already initialized Resource batch")
    }

    candidate := Resource_Batch {
        allocator = allocator,
    }
    candidate.resources = make([]gd.Resource, capacity, allocator)
    defer resource_batch_destroy(&candidate)
    name := gd.new_string_odin(directory)
    dir := gd.dir_access_open(name)
    gd.free_string(name)

    if dir == nil {
        return d.problem(.Missing, directory, "could not open authoring directory")
    }

    defer gd.release_ref(dir)
    files := gd.dir_access_get_files(dir)
    defer gd.free_packed_string_array(files)

    for i in 0 ..< gd.packed_string_array_size(&files) {
        file := gd.packed_string_array_get(&files, i)
        text := gd.gd_string_to_odin(file)
        filename := strings.trim_suffix(text, ".remap")

        if strings.has_suffix(filename, ".tres") || strings.has_suffix(filename, ".res") {
            path := fmt.tprintf("%s/%s", directory, filename)

            if candidate.count == capacity {
                gd.free_string(file)
                return d.problem(.Capacity, path, "Resource batch capacity exceeded")
            }

            resource := gd.load(fmt.ctprintf("%s", path))

            if resource == nil {
                gd.free_string(file)
                return d.problem(.Missing, path, "could not load authored Resource")
            }

            candidate.resources[candidate.count] = resource
            candidate.count += 1
        }

        gd.free_string(file)
    }

    batch^ = candidate
    candidate = {}
    return {}
}

// Borrowed script pointer; resource ownership must cover every use. Diagnostics
// copy the field path/type description and survive temporary strings.
resource_script :: proc(resource: gd.Resource, $Script: typeid, path: string) -> (^Script, d.Report) {
    script := rt.script_of(cast(gd.Object)resource, Script)

    if script == nil {
        return nil, d.problem(.Invalid, path, fmt.tprintf("expected Resource script %v", typeid_of(Script)))
    }

    return script, {}
}
