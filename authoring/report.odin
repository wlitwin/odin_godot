package authoring

Error :: enum {
    None,
    Invalid,
    Missing,
    Capacity,
    Duplicate,
}

// Copied diagnostics survive Resource release and temporary allocator resets.
Report :: struct {
    error:                     Error,
    path:                      [512]u8,
    message:                   [1024]u8,
    path_count, message_count: u16,
    truncated:                 bool,
}

problem :: proc(error: Error, path, message: string) -> Report {
    result := Report {
        error = error,
    }
    result.path_count = u16(copy(result.path[:], path))
    result.message_count = u16(copy(result.message[:], message))
    result.truncated = int(result.path_count) != len(path) || int(result.message_count) != len(message)
    return result
}

report_path :: proc(report: ^Report) -> string {
    return string(report.path[:report.path_count])
}

report_message :: proc(report: ^Report) -> string {
    return string(report.message[:report.message_count])
}
