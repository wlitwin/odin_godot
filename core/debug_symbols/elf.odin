package debug_symbols

import "core:mem"

MAX_FILE_BYTES :: 128 * 1024 * 1024
MAX_SYMBOLS :: 262144

Function :: struct {
    address, size: u64,
    name:          cstring,
}

// Names borrow data. The caller must retain both data and functions while a
// reader uses a lookup result. ELF metadata never supplies source line numbers.
Image :: struct {
    data:      []u8,
    functions: [dynamic]Function,
    bias:      uintptr,
}

@(private)
range :: proc "contextless" (data: []u8, offset, size: u64) -> bool {
    return offset <= u64(len(data)) && size <= u64(len(data)) - offset
}

@(private)
number :: proc "contextless" (data: []u8, at: u64, size: int) -> u64 {
    value := u64(0)

    for i in 0 ..< size {
        value |= u64(data[int(at) + i]) << uint(8 * i)
    }

    return value
}

// Parse bounded ELF64 little-endian function ranges. Unsupported/stripped
// metadata returns false, so callers retain module+offset diagnostics.
parse :: proc(data: []u8, module_base: uintptr, allocator := context.allocator) -> (Image, bool) {
    image := Image {
        data = data,
    }

    if len(data) < 64 ||
       len(data) > MAX_FILE_BYTES ||
       data[0] != 127 ||
       string(data[1:4]) != "ELF" ||
       data[4] != 2 ||
       data[5] != 1 ||
       data[6] != 1 {
        return {}, false
    }

    kind := number(data, 16, 2)
    machine := number(data, 18, 2)

    if (kind != 2 && kind != 3) ||
       (machine != 62 && machine != 183) ||
       number(data, 20, 4) != 1 ||
       number(data, 52, 2) != 64 {
        return {}, false
    }

    phoff, shoff := number(data, 32, 8), number(data, 40, 8)
    phnum, shnum := number(data, 56, 2), number(data, 60, 2)

    if number(data, 54, 2) != 56 ||
       number(data, 58, 2) != 64 ||
       phnum == 0 ||
       phnum > 1024 ||
       shnum == 0 ||
       shnum > 16384 ||
       !range(data, phoff, phnum * 56) ||
       !range(data, shoff, shnum * 64) {
        return {}, false
    }

    found_header := false

    for i := u64(0); i < phnum; i += 1 {
        at := phoff + i * 56

        if number(data, at, 4) != 1 {
            continue
        }

        offset, address := number(data, at + 8, 8), number(data, at + 16, 8)
        bytes, memory := number(data, at + 32, 8), number(data, at + 40, 8)

        if !range(data, offset, bytes) || bytes > memory || memory > max(u64) - address {
            return {}, false
        }

        if offset == 0 && bytes >= 64 {
            if found_header {
                return {}, false
            }

            found_header = true

            if kind == 3 {
                if address > u64(module_base) {
                    return {}, false
                }

                image.bias = module_base - uintptr(address)
            }
        }
    }

    if !found_header {
        return {}, false
    }

    image.functions = make([dynamic]Function, allocator)
    success := false

    defer if !success {
        delete(image.functions)
    }

    for i := u64(0); i < shnum; i += 1 {
        section := shoff + i * 64

        if number(data, section + 4, 4) != 2 {
            continue
        } // SHT_SYMTAB

        offset, bytes := number(data, section + 24, 8), number(data, section + 32, 8)
        link, stride := number(data, section + 40, 4), number(data, section + 56, 8)

        if stride != 24 ||
           bytes % 24 != 0 ||
           bytes / 24 > MAX_SYMBOLS ||
           link >= shnum ||
           !range(data, offset, bytes) {
            return {}, false
        }

        strings_section := shoff + link * 64

        if number(data, strings_section + 4, 4) != 3 {
            return {}, false
        }

        strings_offset := number(data, strings_section + 24, 8)
        strings_size := number(data, strings_section + 32, 8)

        if !range(data, strings_offset, strings_size) {
            return {}, false
        }

        for j := u64(0); j < bytes / 24; j += 1 {
            at := offset + j * 24

            if number(data, at + 4, 1) & 15 != 2 {
                continue
            } // STT_FUNC

            index := number(data, at + 6, 2)

            if index == 0 || index >= shnum {
                continue
            }

            name_offset := number(data, at, 4)
            address, size := number(data, at + 8, 8), number(data, at + 16, 8)

            if size == 0 {
                continue
            }

            target := shoff + index * 64
            flags := number(data, target + 8, 8)
            section_address, section_size := number(data, target + 16, 8), number(data, target + 32, 8)

            if flags & 6 != 6 {
                continue
            } // SHF_ALLOC | SHF_EXECINSTR

            if address < section_address ||
               address - section_address > section_size ||
               size > section_size - (address - section_address) ||
               address > u64(max(uintptr) - image.bias) ||
               size > max(u64) - address {
                return {}, false
            }

            executable := false

            for k := u64(0); k < phnum; k += 1 {
                program := phoff + k * 56

                if number(data, program, 4) != 1 || number(data, program + 4, 4) & 1 == 0 {
                    continue
                }

                low, length := number(data, program + 16, 8), number(data, program + 32, 8)

                if address >= low && address - low <= length && size <= length - (address - low) {
                    executable = true
                    break
                }
            }

            if !executable || name_offset >= strings_size {
                return {}, false
            }

            end := name_offset

            for end < strings_size && data[int(strings_offset + end)] != 0 {
                end += 1
            }

            if end == strings_size {
                return {}, false
            }

            if end == name_offset {
                continue
            }

            if len(image.functions) >= MAX_SYMBOLS {
                return {}, false
            }

            append(&image.functions, Function{address, size, cast(cstring)&data[int(strings_offset + name_offset)]})
        }
    }

    if len(image.functions) == 0 {
        return {}, false
    }

    success = true
    return image, true
}

// Exact containment only: zero-sized symbols and gaps never become guessed
// function names. The caller owns the lifetime of the returned borrowed name.
lookup :: proc "contextless" (image: ^Image, address: uintptr) -> (cstring, uintptr) {
    if image == nil || address < image.bias {
        return nil, 0
    }

    relative := u64(address - image.bias)
    best: ^Function

    for &function in image.functions {
        if relative >= function.address &&
           relative - function.address < function.size &&
           (best == nil || function.size < best.size) {
            best = &function
        }
    }

    if best == nil {
        return nil, 0
    }

    return best.name, image.bias + uintptr(best.address)
}

destroy :: proc(image: ^Image) {
    if image == nil {
        return
    }

    delete(image.functions)
    image^ = {}
}
