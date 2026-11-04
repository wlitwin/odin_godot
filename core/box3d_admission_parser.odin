package core

// Opt-in SDK executable metadata admission. This is not a general loader or a
// security sandbox for arbitrary authored machine code. No external command,
// sidecar claim, native struct cast or initializer runs while these bytes parse.
BOX3D_BINARY_MAX_BYTES :: 64 * 1024 * 1024

Box3D_Binary_Arch :: enum {
    ARM64,
    X86_64,
}

Box3D_Binary_Error :: enum {
    None,
    Malformed,
    Unsupported,
    Wrong_Architecture,
    Too_Large,
    Defined_Native,
    Noncanonical_Native,
    Missing_Canonical_Native,
}

Box3D_Binary_Diagnostic :: struct {
    error:                                 Box3D_Binary_Error,
    offset:                                u64,
    symbols, dependencies, native_imports: u32,
    macho, canonical_native:               bool,
}

@(private)
B3A :: struct {
    data:  []u8,
    arch:  Box3D_Binary_Arch,
    diag:  Box3D_Binary_Diagnostic,
    names: u64,
}

@(private)
b3a_fail :: proc "contextless" (p: ^B3A, e: Box3D_Binary_Error, off: u64) {
    if p.diag.error == .None {
        p.diag.error = e
        p.diag.offset = off
    }
}

@(private)
b3a_range :: proc "contextless" (p: ^B3A, off, size: u64) -> bool {
    if off > u64(len(p.data)) || size > u64(len(p.data)) - off {
        b3a_fail(p, .Malformed, off)
        return false
    }

    return true
}

@(private)
b3a_num :: proc "contextless" (p: ^B3A, off: u64, n: int, big := false) -> u64 {
    if !b3a_range(p, off, u64(n)) {
        return 0
    }

    v := u64(0)

    for i in 0 ..< n {
        j := n - i - 1

        if big {
            j = i
        }

        v = (v << 8) | u64(p.data[int(off) + j])
    }

    return v
}

@(private)
b3a_name :: proc "contextless" (p: ^B3A, start, end: u64) -> string {
    if start >= end || !b3a_range(p, start, end - start) {
        b3a_fail(p, .Malformed, start)
        return ""
    }

    for off := start; off < end; off += 1 {
        p.names += 1

        if p.names > 32 * 1024 * 1024 || off - start > 16384 {
            b3a_fail(p, .Too_Large, off)
            return ""
        }

        if p.data[int(off)] == 0 {
            return string(p.data[int(start):int(off)])
        }
    }

    b3a_fail(p, .Malformed, start)
    return ""
}

@(private)
b3a_native :: proc "contextless" (name: string) -> bool {
    return (len(name) >= 5 && name[:5] == "ogb3_") || (len(name) >= 6 && name[:6] == "_ogb3_")
}

@(private)
b3a_dep :: proc "contextless" (p: ^B3A, name: string, macho: bool, off: u64) -> bool {
    if p.diag.dependencies >= 256 {
        b3a_fail(p, .Too_Large, off)
        return false
    }

    p.diag.dependencies += 1
    canonical := "libogb3.so"

    if macho {
        canonical = "@rpath/libogb3.dylib"
    }

    if name == canonical {
        if p.diag.canonical_native {
            b3a_fail(p, .Malformed, off)
        }

        p.diag.canonical_native = true
        return true
    }

    if macho {
        if name == "/usr/lib/libSystem.B.dylib" ||
           name == "/System/Library/Frameworks/Cocoa.framework/Versions/A/Cocoa" {
            return false
        }
    } else {
        loader := "ld-linux-x86-64.so.2"

        if p.arch == .ARM64 {
            loader = "ld-linux-aarch64.so.1"
        }

        if name == "libc.so.6" || name == "libm.so.6" || name == loader {
            return false
        }
    }

    b3a_fail(p, .Noncanonical_Native, off)
    return false
}

@(private)
b3a_import :: proc "contextless" (p: ^B3A, name: string, ordinal: u64, deps: []bool, off: u64) {
    if !b3a_native(name) {
        return
    }

    p.diag.native_imports += 1

    if ordinal == 0 || ordinal > u64(len(deps)) || !deps[int(ordinal) - 1] {
        b3a_fail(p, .Noncanonical_Native, off)
    }
}

@(private)
b3a_uleb :: proc "contextless" (p: ^B3A, pos: ^u64, end: u64) -> u64 {
    v := u64(0)

    for i in 0 ..< 10 {
        if pos^ >= end || !b3a_range(p, pos^, 1) {
            b3a_fail(p, .Malformed, pos^)
            return 0
        }

        b := p.data[int(pos^)]
        pos^ += 1

        if i == 9 && (b & 0xfe) != 0 {
            b3a_fail(p, .Malformed, pos^ - 1)
            return 0
        }

        v |= u64(b & 127) << u32(i * 7)

        if b & 128 == 0 {
            return v
        }
    }

    b3a_fail(p, .Malformed, pos^)
    return 0
}

@(private)
B3A_Trie :: struct {
    base, size: u64,
    ancestors:  [129]u64,
    nodes:      u32,
}

@(private)
b3a_trie_node :: proc "contextless" (p: ^B3A, t: ^B3A_Trie, node: u64, prefix: [6]u8, length: u64, depth: int) {
    if p.diag.error != .None {
        return
    }

    if depth >= 128 || t.nodes >= 65536 {
        b3a_fail(p, .Too_Large, t.base + node)
        return
    }

    if node >= t.size {
        b3a_fail(p, .Malformed, t.base + node)
        return
    }

    for old in t.ancestors[:depth] {
        if old == node {
            b3a_fail(p, .Malformed, t.base + node)
            return
        }
    }

    t.ancestors[depth] = node
    t.nodes += 1
    pos := t.base + node
    end := t.base + t.size
    terminal := b3a_uleb(p, &pos, end)

    if terminal > end - pos {
        b3a_fail(p, .Malformed, pos)
        return
    }

    terminal_end := pos + terminal

    if terminal != 0 {
        head := prefix

        if (length >= 5 && string(head[:5]) == "ogb3_") || (length >= 6 && string(head[:]) == "_ogb3_") {
            b3a_fail(p, .Defined_Native, pos)
            return
        }

        flags := b3a_uleb(p, &pos, terminal_end)

        if flags & 8 != 0 {
            _ = b3a_uleb(p, &pos, terminal_end)
            _ = b3a_name(p, pos, terminal_end)
            pos = terminal_end
        } else {
            _ = b3a_uleb(p, &pos, terminal_end)

            if flags & 16 != 0 {
                _ = b3a_uleb(p, &pos, terminal_end)
            }
        }

        if pos != terminal_end {
            b3a_fail(p, .Malformed, pos)
            return
        }
    }

    pos = terminal_end

    if pos >= end {
        b3a_fail(p, .Malformed, pos)
        return
    }

    children := int(p.data[int(pos)])
    pos += 1

    for _ in 0 ..< children {
        edge := b3a_name(p, pos, end)

        if len(edge) == 0 {
            b3a_fail(p, .Malformed, pos)
            return
        }

        pos += u64(len(edge)) + 1
        child := b3a_uleb(p, &pos, end)
        next := prefix

        if length + u64(len(edge)) > 16384 {
            b3a_fail(p, .Too_Large, pos)
            return
        }

        for c, i in edge {
            if length + u64(i) < 6 {
                next[int(length) + i] = u8(c)
            }
        }

        b3a_trie_node(p, t, child, next, length + u64(len(edge)), depth + 1)

        if p.diag.error != .None {
            return
        }
    }
}

@(private)
b3a_chained :: proc "contextless" (p: ^B3A, off, size: u64, deps: []bool) {
    if size < 28 || !b3a_range(p, off, size) {
        b3a_fail(p, .Malformed, off)
        return
    }

    version := b3a_num(p, off, 4)
    starts := b3a_num(p, off + 4, 4)
    imports := b3a_num(p, off + 8, 4)
    strings := b3a_num(p, off + 12, 4)
    count := b3a_num(p, off + 16, 4)
    format := b3a_num(p, off + 20, 4)
    compression := b3a_num(p, off + 24, 4)

    if version != 0 || compression != 0 || format < 1 || format > 3 {
        b3a_fail(p, .Unsupported, off)
        return
    }

    entry := u64(4)

    if format == 2 {
        entry = 8
    } else if format == 3 {
        entry = 16
    }

    if count > 1048576 ||
       imports > size ||
       count > (size - imports) / entry ||
       strings > size ||
       starts > size ||
       size - starts < 4 {
        b3a_fail(p, .Malformed, off)
        return
    }

    segs := b3a_num(p, off + starts, 4)

    if segs > 64 || segs > (size - starts - 4) / 4 {
        b3a_fail(p, .Malformed, off + starts)
        return
    }

    for i := u64(0); i < segs; i += 1 {
        relative := b3a_num(p, off + starts + 4 + 4 * i, 4)

        if relative == 0 {
            continue
        }

        if relative > size - starts || size - starts - relative < 22 {
            b3a_fail(p, .Malformed, off + starts + relative)
            return
        }

        s := off + starts + relative
        bytes := b3a_num(p, s, 4)
        pages := b3a_num(p, s + 20, 2)

        if bytes < 22 || bytes > size - starts - relative || pages > (bytes - 22) / 2 {
            b3a_fail(p, .Malformed, s)
            return
        }
    }

    for i := u64(0); i < count; i += 1 {
        at := off + imports + i * entry
        word := b3a_num(p, at, 4)
        ordinal := word & 255
        nameoff := word >> 9

        if format == 3 {
            wide := b3a_num(p, at, 8)
            ordinal = wide & 65535
            nameoff = wide >> 32

            if (wide >> 17) & 32767 != 0 {
                b3a_fail(p, .Malformed, at)
                return
            }
        }

        if nameoff >= size - strings {
            b3a_fail(p, .Malformed, at)
            return
        }

        name := b3a_name(p, off + strings + nameoff, off + size)
        b3a_import(p, name, ordinal, deps, at)

        if p.diag.error != .None {
            return
        }
    }
}

@(private)
b3a_macho :: proc "contextless" (p: ^B3A, base, size: u64, arch: Box3D_Binary_Arch) {
    if size < 32 || !b3a_range(p, base, size) {
        b3a_fail(p, .Malformed, base)
        return
    }

    p.diag.macho = true

    if b3a_num(p, base, 4) != 0xfeedfacf {
        b3a_fail(p, .Unsupported, base)
        return
    }

    cpu := u64(0x100000c)
    sub := u64(0)

    if arch == .X86_64 {
        cpu = 0x1000007
        sub = 3
    }

    if b3a_num(p, base + 4, 4) != cpu || b3a_num(p, base + 8, 4) & 0xffffff != sub {
        b3a_fail(p, .Wrong_Architecture, base + 4)
        return
    }

    if b3a_num(p, base + 12, 4) != 6 || b3a_num(p, base + 24, 4) & 0x80 == 0 {
        b3a_fail(p, .Unsupported, base + 12)
        return
    }

    ncmds := b3a_num(p, base + 16, 4)
    cmdbytes := b3a_num(p, base + 20, 4)

    if ncmds > 1024 || cmdbytes > size - 32 || ncmds > cmdbytes / 8 {
        b3a_fail(p, .Malformed, base + 16)
        return
    }

    pos := base + 32
    cmdend := pos + cmdbytes
    symoff, nsyms, stroff, strsize, exportoff, exportsize, fixoff, fixsize: u64
    has_sym, has_exports, has_fix: bool
    deps: [256]bool
    depcount := 0

    for _ in 0 ..< int(ncmds) {
        if cmdend - pos < 8 {
            b3a_fail(p, .Malformed, pos)
            return
        }

        cmd := b3a_num(p, pos, 4)
        length := b3a_num(p, pos + 4, 4)

        if length < 8 || length & 7 != 0 || length > cmdend - pos {
            b3a_fail(p, .Malformed, pos)
            return
        }

        switch cmd {
        case 2:
            if length != 24 || has_sym {
                b3a_fail(p, .Malformed, pos)
                return
            }

            has_sym = true
            symoff = b3a_num(p, pos + 8, 4)
            nsyms = b3a_num(p, pos + 12, 4)
            stroff = b3a_num(p, pos + 16, 4)
            strsize = b3a_num(p, pos + 20, 4)
        case 12, 0x80000018:
            if length < 24 || depcount == 256 {
                b3a_fail(p, .Malformed, pos)
                return
            }

            nameoff := b3a_num(p, pos + 8, 4)

            if nameoff < 24 || nameoff >= length {
                b3a_fail(p, .Malformed, pos + 8)
                return
            }

            name := b3a_name(p, pos + nameoff, pos + length)
            deps[depcount] = b3a_dep(p, name, true, pos + nameoff)

            if deps[depcount] && cmd != 12 {
                b3a_fail(p, .Unsupported, pos)
                return
            }

            depcount += 1
        case 13, 0x8000001c:
            minimum := u64(24)

            if cmd == 0x8000001c {
                minimum = 12
            }

            if length < minimum {
                b3a_fail(p, .Malformed, pos)
                return
            }

            nameoff := b3a_num(p, pos + 8, 4)

            if nameoff < minimum || nameoff >= length {
                b3a_fail(p, .Malformed, pos + 8)
                return
            }

            _ = b3a_name(p, pos + nameoff, pos + length)
        case 0x80000033, 0x80000034, 0x1d, 0x26, 0x29:
            if length != 16 {
                b3a_fail(p, .Malformed, pos)
                return
            }

            off := b3a_num(p, pos + 8, 4)
            bytes := b3a_num(p, pos + 12, 4)

            if off > size || bytes > size - off {
                b3a_fail(p, .Malformed, pos + 8)
                return
            }

            if cmd == 0x80000033 {
                if has_exports {
                    b3a_fail(p, .Malformed, pos)
                    return
                }

                has_exports = true
                exportoff = off
                exportsize = bytes
            }

            if cmd == 0x80000034 {
                if has_fix {
                    b3a_fail(p, .Malformed, pos)
                    return
                }

                has_fix = true
                fixoff = off
                fixsize = bytes
            }
        case 0x22, 0x80000022:
            if length != 48 {
                b3a_fail(p, .Malformed, pos)
                return
            }

            for i in 0 ..< 5 {
                off := b3a_num(p, pos + 8 + u64(i * 8), 4)
                bytes := b3a_num(p, pos + 12 + u64(i * 8), 4)

                if off > size || bytes > size - off {
                    b3a_fail(p, .Malformed, pos)
                    return
                }

                if i > 0 && i < 4 && bytes != 0 {
                    b3a_fail(p, .Unsupported, pos)
                    return
                }

                if i == 4 && bytes != 0 {
                    if has_exports {
                        b3a_fail(p, .Malformed, pos)
                        return
                    }

                    has_exports = true
                    exportoff = off
                    exportsize = bytes
                }
            }
        case 0x19:
            if length < 72 {
                b3a_fail(p, .Malformed, pos)
                return
            }

            sections := b3a_num(p, pos + 64, 4)
            fileoff := b3a_num(p, pos + 40, 8)
            filesize := b3a_num(p, pos + 48, 8)

            if sections > 256 || length != 72 + sections * 80 || fileoff > size || filesize > size - fileoff {
                b3a_fail(p, .Malformed, pos)
                return
            }
        case 0x8000001f, 0x80000023, 0x20, 0x27:
            b3a_fail(p, .Unsupported, pos)
            return
        case: // Other standard fixed metadata is not a dependency or symbol provider.
        }

        if p.diag.error != .None {
            return
        }

        pos += length
    }

    if pos != cmdend ||
       !has_sym ||
       nsyms > 1048576 ||
       symoff > size ||
       nsyms > (size - symoff) / 16 ||
       stroff > size ||
       strsize > size - stroff ||
       strsize == 0 {
        b3a_fail(p, .Malformed, pos)
        return
    }

    for i := u64(0); i < nsyms; i += 1 {
        at := base + symoff + 16 * i
        nameindex := b3a_num(p, at, 4)
        kind := b3a_num(p, at + 4, 1)
        desc := b3a_num(p, at + 6, 2)

        if nameindex >= strsize {
            b3a_fail(p, .Malformed, at)
            return
        }

        name := b3a_name(p, base + stroff + nameindex, base + stroff + strsize)

        if p.diag.symbols >= 1048576 {
            b3a_fail(p, .Too_Large, at)
            return
        }

        p.diag.symbols += 1

        if kind & 0xe0 == 0 && b3a_native(name) {
            if kind & 0x0e != 0 {
                b3a_fail(p, .Defined_Native, at)
                return
            }

            b3a_import(p, name, desc >> 8, deps[:depcount], at)
        }

        if p.diag.error != .None {
            return
        }
    }

    if has_exports && exportsize != 0 {
        t := B3A_Trie {
            base = base + exportoff,
            size = exportsize,
        }
        b3a_trie_node(p, &t, 0, {}, 0, 0)
    }

    if p.diag.error == .None && has_fix {
        b3a_chained(p, base + fixoff, fixsize, deps[:depcount])
    }

    if p.diag.native_imports != 0 && !p.diag.canonical_native {
        b3a_fail(p, .Missing_Canonical_Native, base)
    }
}

// Require one file-backed PT_LOAD to contain the entire virtual range, with
// no second memory mapping overlapping even part of it. Section addresses alone
// are not evidence of the bytes the dynamic loader will use.
@(private)
b3a_elf_file :: proc "contextless" (p: ^B3A, phoff, phnum, address, size: u64, expected: u64) -> bool {
    if size == 0 || size > max(u64) - address {
        b3a_fail(p, .Malformed, expected)
        return false
    }

    found := false

    for i := u64(0); i < phnum; i += 1 {
        at := phoff + 56 * i

        if b3a_num(p, at, 4) != 1 {
            continue
        }

        off := b3a_num(p, at + 8, 8)
        va := b3a_num(p, at + 16, 8)
        filebytes := b3a_num(p, at + 32, 8)
        memory := b3a_num(p, at + 40, 8)

        if memory > max(u64) - va {
            b3a_fail(p, .Malformed, at)
            return false
        }

        if address < va + memory && va < address + size {
            if found ||
               address < va ||
               address - va > filebytes ||
               size > filebytes - (address - va) ||
               off > max(u64) - (address - va) ||
               off + (address - va) != expected {
                b3a_fail(p, .Malformed, at)
                return false
            }

            found = true
        }
    }

    if !found {
        b3a_fail(p, .Malformed, expected)
    }

    return found
}

@(private)
b3a_elf :: proc "contextless" (p: ^B3A, arch: Box3D_Binary_Arch) {
    if !b3a_range(p, 0, 64) {
        return
    }

    if p.data[4] != 2 || p.data[5] != 1 || p.data[6] != 1 || (p.data[7] != 0 && p.data[7] != 3) {
        b3a_fail(p, .Unsupported, 4)
        return
    }

    machine := u64(62)

    if arch == .ARM64 {
        machine = 183
    }

    if b3a_num(p, 18, 2) != machine {
        b3a_fail(p, .Wrong_Architecture, 18)
        return
    }

    if b3a_num(p, 16, 2) != 3 || b3a_num(p, 20, 4) != 1 || b3a_num(p, 52, 2) != 64 {
        b3a_fail(p, .Unsupported, 16)
        return
    }

    phoff := b3a_num(p, 32, 8)
    shoff := b3a_num(p, 40, 8)
    phnum := b3a_num(p, 56, 2)
    shnum := b3a_num(p, 60, 2)

    if b3a_num(p, 54, 2) != 56 ||
       b3a_num(p, 58, 2) != 64 ||
       phnum == 0 ||
       phnum > 1024 ||
       shnum == 0 ||
       shnum > 16384 ||
       b3a_num(p, 62, 2) >= shnum {
        b3a_fail(p, .Unsupported, 52)
        return
    }

    if !b3a_range(p, phoff, phnum * 56) || !b3a_range(p, shoff, shnum * 64) {
        return
    }

    dynamic_off, dynamic_size, dynamic_addr: u64
    has_program_dynamic := false

    for i := u64(0); i < phnum; i += 1 {
        at := phoff + i * 56
        kind := b3a_num(p, at, 4)
        off := b3a_num(p, at + 8, 8)
        addr := b3a_num(p, at + 16, 8)
        size := b3a_num(p, at + 32, 8)
        memsize := b3a_num(p, at + 40, 8)

        if !b3a_range(p, off, size) || size > memsize || memsize > max(u64) - addr {
            b3a_fail(p, .Malformed, at)
            return
        }

        if kind == 2 {
            if has_program_dynamic {
                b3a_fail(p, .Malformed, at)
                return
            }

            has_program_dynamic = true
            dynamic_off = off
            dynamic_size = size
            dynamic_addr = addr
        }
    }

    dynsym, dynsection: u64
    has_dynsym, has_dynamic: bool

    for i := u64(0); i < shnum; i += 1 {
        at := shoff + 64 * i
        kind := b3a_num(p, at + 4, 4)
        off := b3a_num(p, at + 24, 8)
        size := b3a_num(p, at + 32, 8)

        if kind != 8 && !b3a_range(p, off, size) {
            return
        }

        if kind == 11 {
            if has_dynsym {
                b3a_fail(p, .Unsupported, at)
                return
            }

            has_dynsym = true
            dynsym = at
        }

        if kind == 6 {
            if has_dynamic {
                b3a_fail(p, .Unsupported, at)
                return
            }

            has_dynamic = true
            dynsection = at
        }

        if kind == 2 || kind == 11 {
            link := b3a_num(p, at + 40, 4)
            entry := b3a_num(p, at + 56, 8)

            if entry != 24 || size % 24 != 0 || size / 24 > 1048576 || link >= shnum {
                b3a_fail(p, .Malformed, at)
                return
            }

            strings := shoff + link * 64

            if b3a_num(p, strings + 4, 4) != 3 {
                b3a_fail(p, .Malformed, strings)
                return
            }

            stroff := b3a_num(p, strings + 24, 8)
            strsize := b3a_num(p, strings + 32, 8)

            if strsize == 0 {
                b3a_fail(p, .Malformed, strings)
                return
            }

            if !b3a_range(p, stroff, strsize) {
                return
            }

            for j := u64(0); j < size / 24; j += 1 {
                symbol := off + 24 * j
                index := b3a_num(p, symbol, 4)
                section := b3a_num(p, symbol + 6, 2)

                if index >= strsize {
                    b3a_fail(p, .Malformed, symbol)
                    return
                }

                if section == 65535 {
                    b3a_fail(p, .Unsupported, symbol)
                    return
                }

                name := b3a_name(p, stroff + index, stroff + strsize)

                if p.diag.symbols >= 1048576 {
                    b3a_fail(p, .Too_Large, symbol)
                    return
                }

                p.diag.symbols += 1

                if b3a_native(name) {
                    if section != 0 {
                        b3a_fail(p, .Defined_Native, symbol)
                        return
                    }

                    p.diag.native_imports += 1
                }

                if p.diag.error != .None {
                    return
                }
            }
        }
    }

    if !has_dynsym || !has_dynamic || !has_program_dynamic {
        b3a_fail(p, .Unsupported, shoff)
        return
    }

    if !b3a_elf_file(
        p,
        phoff,
        phnum,
        b3a_num(p, dynsym + 16, 8),
        b3a_num(p, dynsym + 32, 8),
        b3a_num(p, dynsym + 24, 8),
    ) {
        return
    }

    off := b3a_num(p, dynsection + 24, 8)
    size := b3a_num(p, dynsection + 32, 8)
    addr := b3a_num(p, dynsection + 16, 8)
    link := b3a_num(p, dynsection + 40, 4)

    if off != dynamic_off ||
       size != dynamic_size ||
       addr != dynamic_addr ||
       size % 16 != 0 ||
       size / 16 > 8192 ||
       link >= shnum ||
       b3a_num(p, dynsection + 56, 8) != 16 {
        b3a_fail(p, .Malformed, dynsection)
        return
    }

    if !b3a_elf_file(p, phoff, phnum, addr, size, off) {
        return
    }

    strings := shoff + link * 64
    stroff := b3a_num(p, strings + 24, 8)
    strsize := b3a_num(p, strings + 32, 8)
    straddr := b3a_num(p, strings + 16, 8)

    if b3a_num(p, strings + 4, 4) != 3 || !b3a_range(p, stroff, strsize) {
        b3a_fail(p, .Malformed, strings)
        return
    }

    if !b3a_elf_file(p, phoff, phnum, straddr, strsize, stroff) {
        return
    }

    if b3a_num(p, dynsym + 40, 4) != link {
        b3a_fail(p, .Malformed, dynsym)
        return
    }

    seen_null, seen_strtab, seen_strsize, seen_symtab, seen_syment: bool

    for i := u64(0); i < size / 16; i += 1 {
        at := off + 16 * i
        tag := b3a_num(p, at, 8)
        value := b3a_num(p, at + 8, 8)

        if tag == 0 {
            seen_null = true
            break
        }

        switch tag {
        case 1, 14, 15, 29:
            if value >= strsize {
                b3a_fail(p, .Malformed, at)
                return
            }

            name := b3a_name(p, stroff + value, stroff + strsize)

            if tag == 1 {
                _ = b3a_dep(p, name, false, at)
            }
        case 5:
            if seen_strtab || value != straddr {
                b3a_fail(p, .Malformed, at)
                return
            }

            seen_strtab = true
        case 10:
            if seen_strsize || value != strsize {
                b3a_fail(p, .Malformed, at)
                return
            }

            seen_strsize = true
        case 6:
            if seen_symtab || value != b3a_num(p, dynsym + 16, 8) {
                b3a_fail(p, .Malformed, at)
                return
            }

            seen_symtab = true
        case 11:
            if seen_syment || value != 24 {
                b3a_fail(p, .Malformed, at)
                return
            }

            seen_syment = true
        case 0x7ffffffd, 0x7fffffff, 0x6ffffefb, 0x6ffffefc:
            b3a_fail(p, .Unsupported, at)
            return
        }

        if p.diag.error != .None {
            return
        }
    }

    if !seen_null || !seen_strtab || !seen_strsize || !seen_symtab || !seen_syment {
        b3a_fail(p, .Malformed, off)
        return
    }

    if p.diag.native_imports != 0 && !p.diag.canonical_native {
        b3a_fail(p, .Missing_Canonical_Native, off)
    }
}

box3d_binary_admit :: proc "contextless" (data: []u8, arch: Box3D_Binary_Arch) -> Box3D_Binary_Diagnostic {
    p := B3A {
        data = data,
        arch = arch,
    }

    if len(data) > BOX3D_BINARY_MAX_BYTES {
        p.diag.error = .Too_Large
        return p.diag
    }

    if len(data) < 4 {
        p.diag.error = .Malformed
        return p.diag
    }

    if data[0] == 127 && string(data[1:4]) == "ELF" {
        b3a_elf(&p, arch)
        return p.diag
    }

    magic := b3a_num(&p, 0, 4, true)

    if magic == 0xcafebabe || magic == 0xcafebabf {
        wide := magic == 0xcafebabf
        n := b3a_num(&p, 4, 4, true)
        entry := u64(20)

        if wide {
            entry = 32
        }

        if n == 0 || n > 64 || !b3a_range(&p, 8, n * entry) {
            p.diag.error = .Malformed
            return p.diag
        }

        offsets, sizes: [64]u64
        found := false
        selected_off, selected_size: u64
        cpu := u64(0x100000c)
        sub := u64(0)

        if arch == .X86_64 {
            cpu = 0x1000007
            sub = 3
        }

        for i := u64(0); i < n; i += 1 {
            at := 8 + i * entry
            kind := b3a_num(&p, at, 4, true)
            subkind := b3a_num(&p, at + 4, 4, true) & 0xffffff
            off, size, alignment: u64

            if wide {
                off = b3a_num(&p, at + 8, 8, true)
                size = b3a_num(&p, at + 16, 8, true)
                alignment = b3a_num(&p, at + 24, 4, true)

                if b3a_num(&p, at + 28, 4, true) != 0 {
                    b3a_fail(&p, .Malformed, at + 28)
                }
            } else {
                off = b3a_num(&p, at + 8, 4, true)
                size = b3a_num(&p, at + 12, 4, true)
                alignment = b3a_num(&p, at + 16, 4, true)
            }

            if off < 8 + n * entry ||
               size < 32 ||
               alignment > 31 ||
               off % (u64(1) << u32(alignment)) != 0 ||
               !b3a_range(&p, off, size) {
                b3a_fail(&p, .Malformed, at)
                return p.diag
            }

            for j := u64(0); j < i; j += 1 {
                if off < offsets[int(j)] + sizes[int(j)] && offsets[int(j)] < off + size {
                    b3a_fail(&p, .Malformed, at)
                    return p.diag
                }
            }

            offsets[int(i)] = off
            sizes[int(i)] = size

            if kind == cpu && subkind == sub {
                if found {
                    b3a_fail(&p, .Malformed, at)
                    return p.diag
                }

                found = true
                selected_off = off
                selected_size = size
            }
        }

        if !found {
            p.diag.error = .Wrong_Architecture
            return p.diag
        }

        b3a_macho(&p, selected_off, selected_size, arch)
        return p.diag
    }

    b3a_macho(&p, 0, u64(len(data)), arch)
    return p.diag
}
