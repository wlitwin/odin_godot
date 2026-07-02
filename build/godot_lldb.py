# godot_lldb.py — lldb type summaries for odin_godot's Godot value types.
#
# Loaded automatically by build/debug_game.sh (`command script import ...`); manual use:
#   (lldb) command script import path/to/godot_lldb.py
#
# Why: godot.String / String_Name / Variant are OPAQUE handles on the Odin side (one
# pointer into engine-owned memory), so `frame variable` shows a raw word — useless.
# These summaries chase the pointer into the engine's actual data structures and show
# the value:   name = "Player"   sig = StringName("body_entered")   v = Variant(Int) 42
#
# The layouts read here are Godot 4.x internals (CowData: u64 size at data-8; StringName
# _Data: cname at +8, String name at +16; Variant: 4-byte type tag + payload at +8) —
# stable across 4.x, but every read is guarded: on any surprise the summary degrades to
# '<?>' rather than erroring. 64-bit processes only (the only targets we debug natively).
import lldb

_PTR = 8  # native debugging is 64-bit only

_MAX_CHARS = 512  # clamp pathological/corrupt sizes instead of reading megabytes


def _read_ptr(process, addr):
    err = lldb.SBError()
    v = process.ReadPointerFromMemory(addr, err)
    return (v, err.Success())


def _read_u64(process, addr):
    err = lldb.SBError()
    v = process.ReadUnsignedFromMemory(addr, 8, err)
    return (v, err.Success())


def _cow_string(process, data_ptr):
    """Decode a Godot String's CowData<char32_t>: data_ptr aims at element 0, the u64
    element count (INCLUDING the NUL terminator) sits 8 bytes before it."""
    if data_ptr == 0:
        return '""'
    size, ok = _read_u64(process, data_ptr - 8)
    if not ok or size == 0:
        return '""' if ok else "<?>"
    n = min(size - 1, _MAX_CHARS)  # drop the NUL
    if n <= 0:
        return '""'
    err = lldb.SBError()
    raw = process.ReadMemory(data_ptr, n * 4, err)
    if err.Fail() or raw is None:
        return "<?>"
    s = raw.decode("utf-32-le", errors="replace")
    suffix = "…" if size - 1 > _MAX_CHARS else ""
    return '"%s%s"' % (s, suffix)


def _value_addr(value):
    addr = value.GetLoadAddress()
    if addr == lldb.LLDB_INVALID_ADDRESS:
        return None
    return addr


def string_summary(value, internal_dict):
    try:
        addr = _value_addr(value)
        if addr is None:
            return "<no addr>"
        process = value.GetProcess()
        data_ptr, ok = _read_ptr(process, addr)
        if not ok:
            return "<?>"
        return _cow_string(process, data_ptr)
    except Exception:
        return "<?>"


def string_name_summary(value, internal_dict):
    """StringName -> _Data*: the interned `String name` sits at +8, after the two u32
    refcounts (4.6 layout — earlier 4.x also kept a `const char *cname` there)."""
    try:
        addr = _value_addr(value)
        if addr is None:
            return "<no addr>"
        process = value.GetProcess()
        data, ok = _read_ptr(process, addr)
        if not ok or data == 0:
            return 'StringName("")' if ok else "<?>"
        name_cow, ok = _read_ptr(process, data + 8)
        if not ok:
            return "<?>"
        return "StringName(%s)" % _cow_string(process, name_cow)
    except Exception:
        return "<?>"


# GDExtension Variant_Type order (gdext/lib.odin — mirrors the engine's Variant::Type).
_VARIANT_TYPES = [
    "Nil", "Bool", "Int", "Float", "String",
    "Vector2", "Vector2i", "Rect2", "Rect2i", "Vector3", "Vector3i",
    "Transform2d", "Vector4", "Vector4i", "Plane", "Quaternion", "Aabb",
    "Basis", "Transform3d", "Projection",
    "Color", "String_Name", "Node_Path", "Rid", "Object", "Callable",
    "Signal", "Dictionary", "Array",
    "Packed_Byte_Array", "Packed_Int32_Array", "Packed_Int64_Array",
    "Packed_Float32_Array", "Packed_Float64_Array", "Packed_String_Array",
    "Packed_Vector2_Array", "Packed_Vector3_Array", "Packed_Color_Array",
    "Packed_Vector4_Array",
]


def variant_summary(value, internal_dict):
    """Variant = { type: i32, payload at +8 }. Decode the tag always; inline the value
    for the common scalar/pointer payloads."""
    try:
        addr = _value_addr(value)
        if addr is None:
            return "<no addr>"
        process = value.GetProcess()
        err = lldb.SBError()
        tag = process.ReadUnsignedFromMemory(addr, 4, err)
        if err.Fail():
            return "<?>"
        tname = _VARIANT_TYPES[tag] if tag < len(_VARIANT_TYPES) else "type#%d" % tag
        payload = addr + 8
        if tname == "Nil":
            return "Variant(Nil)"
        if tname == "Bool":
            b, ok = _read_u64(process, payload)
            return "Variant(Bool) %s" % ("true" if (b & 1) else "false") if ok else "<?>"
        if tname == "Int":
            u, ok = _read_u64(process, payload)
            if not ok:
                return "<?>"
            i = u - (1 << 64) if u >= (1 << 63) else u
            return "Variant(Int) %d" % i
        if tname == "Float":
            import struct as _s
            raw = process.ReadMemory(payload, 8, err)
            if err.Fail() or raw is None:
                return "<?>"
            return "Variant(Float) %g" % _s.unpack("<d", raw)[0]
        if tname == "String":
            p, ok = _read_ptr(process, payload)
            return "Variant(String) %s" % _cow_string(process, p) if ok else "<?>"
        if tname in ("Vector2", "Vector3", "Vector4", "Color"):
            import struct as _s
            n = {"Vector2": 2, "Vector3": 3, "Vector4": 4, "Color": 4}[tname]
            raw = process.ReadMemory(payload, n * 4, err)
            if err.Fail() or raw is None:
                return "<?>"
            comps = _s.unpack("<%df" % n, raw)
            return "Variant(%s) (%s)" % (tname, ", ".join("%g" % c for c in comps))
        if tname == "Object":
            p, ok = _read_ptr(process, payload)
            return "Variant(Object) %s" % ("0x%x" % p if ok else "<?>")
        return "Variant(%s)" % tname
    except Exception:
        return "<?>"


def __lldb_init_module(debugger, internal_dict):
    m = __name__
    for tname, fn in (
        ("godot::String", "string_summary"),
        ("godot::String_Name", "string_name_summary"),
        ("godot::Variant", "variant_summary"),
    ):
        debugger.HandleCommand(
            'type summary add -w godot -F %s.%s "%s"' % (m, fn, tname)
        )
    debugger.HandleCommand("type category enable godot")
    print("godot_lldb: summaries loaded for godot::String, String_Name, Variant")
