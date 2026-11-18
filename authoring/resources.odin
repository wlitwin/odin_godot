package authoring

import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strings"
import gd "godot:godot"
import rt "godot:runtime"

// Owns references and source paths for a complete candidate batch. Destroy on
// every exit after extraction; script pointers borrowed from it share its lifetime.
Resource_Batch :: struct {
    resources: []gd.Resource,
    paths:     []string,
    count:     int,
    allocator: mem.Allocator,
}

resource_batch_destroy :: proc(batch: ^Resource_Batch) {
    for i in 0 ..< batch.count {
        gd.release_ref(batch.resources[i])
        delete(batch.paths[i], batch.allocator)
    }
    delete(batch.resources, batch.allocator)
    delete(batch.paths, batch.allocator)
    batch^ = {}
}

resource_batch_load :: proc(
    batch: ^Resource_Batch,
    directory: string,
    capacity: int,
    allocator := context.allocator,
) -> Report {
    if len(batch.resources) > 0 || len(batch.paths) > 0 || capacity < 1 || capacity > 65536 {
        return problem(.Invalid, directory, "invalid or already initialized Resource batch")
    }
    candidate := Resource_Batch {
        allocator = allocator,
    }
    candidate.resources = make([]gd.Resource, capacity, allocator)
    candidate.paths = make([]string, capacity, allocator)
    defer resource_batch_destroy(&candidate)
    name := gd.new_string_odin(directory)
    dir := gd.dir_access_open(name)
    gd.free_string(name)
    if dir == nil {return problem(.Missing, directory, "could not open authoring directory")}
    defer gd.release_ref(dir)
    files := gd.dir_access_get_files(dir) // Godot returns sorted filenames.
    defer gd.free_packed_string_array(files)
    filenames := make([dynamic]string, allocator)
    defer {
        for filename in filenames {delete(filename, allocator)}
        delete(filenames)
    }
    for i in 0 ..< gd.packed_string_array_size(&files) {
        file := gd.packed_string_array_get(&files, i)
        text := gd.gd_string_to_odin(file)
        gd.free_string(file)
        filename := strings.trim_suffix(text, ".remap")
        if !strings.has_suffix(filename, ".tres") && !strings.has_suffix(filename, ".res") {continue}
        append(&filenames, strings.clone(filename, allocator))
    }
    // Normalize before sorting: an exported remap may sort after another valid
    // Resource sharing its prefix (a.tres.extra.tres versus a.tres.remap).
    slice.sort(filenames[:])
    for filename in filenames {
        path := fmt.tprintf("%s/%s", strings.trim_suffix(directory, "/"), filename)
        // A source plus its export remap represent one logical Resource.
        if candidate.count > 0 && candidate.paths[candidate.count - 1] == path {continue}
        if candidate.count == capacity {return problem(.Capacity, path, "Resource batch capacity exceeded")}
        resource := gd.load(fmt.ctprintf("%s", path))
        if resource == nil {return problem(.Missing, path, "could not load authored Resource")}
        candidate.resources[candidate.count] = resource
        candidate.paths[candidate.count] = strings.clone(path, allocator)
        candidate.count += 1
    }
    batch^ = candidate
    candidate = {}
    return {}
}

resource_script :: proc(resource: gd.Resource, $Script: typeid, path: string) -> (^Script, Report) {
    script := rt.script_of(cast(gd.Object)resource, Script)
    if script ==
       nil {return nil, problem(.Invalid, path, fmt.tprintf("expected Resource script %v", typeid_of(Script)))}
    return script, {}
}

Catalog_Entry :: struct($Script: typeid) {
    resource: gd.Resource,
    script:   ^Script,
    path:     string,
    id:       int,
}

Catalog :: struct($Script: typeid) {
    batch:      Resource_Batch,
    entries:    []Catalog_Entry(Script),
    high_water: int, // max(id) + 1, including holes/reserved rows; not the row count.
}

catalog_destroy :: proc(catalog: ^Catalog($Script)) {
    delete(catalog.entries, catalog.batch.allocator)
    resource_batch_destroy(&catalog.batch)
    catalog^ = {}
}

// Validate all types and stable IDs before exposing any entries. For an ordered
// rulebook use id_field="": filenames decide order, entries receive dense IDs.
// Base duplicates always fail; intentional overlays belong in a separate step.
catalog_load :: proc(
    catalog: ^Catalog($Script),
    directory: string,
    capacity: int,
    minimum_id := 0,
    id_field := "id",
    allocator := context.allocator,
) -> Report {
    if len(catalog.entries) != 0 ||
       len(catalog.batch.resources) != 0 ||
       minimum_id < 0 ||
       minimum_id >= capacity ||
       (id_field == "" && minimum_id != 0) {
        return problem(.Invalid, directory, "invalid catalog bounds or already initialized catalog")
    }
    candidate: Catalog(Script)
    defer catalog_destroy(&candidate)
    report := resource_batch_load(&candidate.batch, directory, capacity, allocator)
    if report.error != .None {return report}
    candidate.entries = make([]Catalog_Entry(Script), candidate.batch.count, allocator)
    for resource, i in candidate.batch.resources[:candidate.batch.count] {
        path := candidate.batch.paths[i]
        script, script_report := resource_script(resource, Script, path)
        if script_report.error != .None {return script_report}
        id := i
        if id_field != "" {
            field, found := resolve_field(script, type_info_of(Script), id_field)
            if !found {return problem(.Invalid, path, fmt.tprintf("missing integer ID field %s", id_field))}
            value, ok := read_integer(field)
            if !ok || value < i64(minimum_id) || value >= i64(capacity) {
                return problem(
                    .Invalid,
                    fmt.tprintf("%s.%s", path, id_field),
                    fmt.tprintf("ID must be an integer in %d..%d", minimum_id, capacity - 1),
                )
            }
            id = int(value)
            for previous in candidate.entries[:i] {
                if previous.id == id {
                    return problem(
                        .Duplicate,
                        fmt.tprintf("%s.%s", path, id_field),
                        fmt.tprintf("duplicate ID %d: %s and %s", id, previous.path, path),
                    )
                }
            }
        }
        candidate.entries[i] = {resource, script, path, id}
        candidate.high_water = max(candidate.high_water, id + 1)
    }
    catalog^ = candidate
    candidate = {}
    return {}
}
