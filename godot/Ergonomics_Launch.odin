package godot

// Launch parameters — "how was this instance launched?", answered the same way on every
// platform. A networked game gets its role/relay/room told to it from OUTSIDE: on native
// that's an ENVIRONMENT VARIABLE (the acid harness and launch scripts steer host/client
// instances that way), on web it's the page URL's QUERY STRING (`?host=1&room=abc` — the
// friend-clicks-a-link front door). Both example games hand-rolled this pair ~120 lines
// each, byte-identical, JavaScriptBridge eval + a private query-string parser included —
// the promotion criterion in person. Written once, here.
//
//     role := gd.launch_param("COOP_ROLE", "role")        // env first, ?role= on web
//     url  := gd.web_query("url")                          // web-only knob ("" on native)
//
// Results are temp-allocated by default (copy what you keep), like gd.env_string.

import "godot:gdext"

// IS_WEB — compiled-for-the-browser? (The same test every game spelled itself.)
IS_WEB :: ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32

// launch_param reads `env_key` from the environment (any platform), then — on web — falls
// back to `query_key` in the page URL's query string; `fallback` when neither is set.
// The env/query names differ on purpose: env vars are conventionally UPPER_SNAKE and
// project-prefixed (`COOP_ROLE`), query params short and lower (`role`).
launch_param :: proc(env_key: cstring, query_key: string, fallback := "", allocator := context.temp_allocator) -> string {
	if v := env_string(env_key, "", allocator); v != "" {
		return v
	}
	if v := web_query(query_key, allocator); v != "" {
		return v
	}
	return fallback
}

// web_query reads one value from the page URL's query string — "" when absent, and ""
// always on native (compile-time: the JavaScriptBridge eval only exists in web builds).
// The value is percent-decoded (uri_decode).
web_query :: proc(key: string, allocator := context.temp_allocator) -> string {
	when IS_WEB {
		js := singleton_java_script_bridge()
		code := new_string_cstring("location.search || ''")
		defer free_string(code)
		v := java_script_bridge_eval(js, code, true)
		defer variant_destroy(&v)
		gs := variant_to_string(&v)
		defer free_string(gs)
		s := gd_string_to_odin(gs, context.temp_allocator)
		if len(s) > 0 && s[0] == '?' {s = s[1:]}
		start := 0
		for i := 0; i <= len(s); i += 1 {
			if i == len(s) || s[i] == '&' {
				kv := s[start:i]
				eq := -1
				for j in 0 ..< len(kv) {
					if kv[j] == '=' {eq = j;break}
				}
				if eq > 0 && kv[:eq] == key {
					return uri_decode(kv[eq + 1:], allocator)
				}
				start = i + 1
			}
		}
		return ""
	} else {
		return ""
	}
}

// uri_decode percent-decodes `s` (enough for query values: %XX escapes; malformed
// escapes pass through verbatim). Allocated from `allocator`.
uri_decode :: proc(s: string, allocator := context.temp_allocator) -> string {
	out := make([]u8, len(s), allocator)
	n := 0
	i := 0
	for i < len(s) {
		if s[i] == '%' && i + 2 < len(s) {
			hi := hex_val(s[i + 1])
			lo := hex_val(s[i + 2])
			if hi >= 0 && lo >= 0 {
				out[n] = u8(hi * 16 + lo)
				n += 1
				i += 3
				continue
			}
		}
		out[n] = s[i]
		n += 1
		i += 1
	}
	return string(out[:n])
}

@(private = "file")
hex_val :: proc "contextless" (c: u8) -> int {
	switch {
	case c >= '0' && c <= '9':
		return int(c - '0')
	case c >= 'a' && c <= 'f':
		return int(c - 'a' + 10)
	case c >= 'A' && c <= 'F':
		return int(c - 'A' + 10)
	}
	return -1
}

// gd_string_to_odin converts a Godot String to an Odin string of the FULL length
// (two-call pattern: measure, then fill) — unlike env_string's fixed clamp, a URL query
// string has no sane cap. Allocated from `allocator`.
gd_string_to_odin :: proc(s: String, allocator := context.temp_allocator) -> string {
	s := s
	n := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, nil, 0)
	if n <= 0 {
		return ""
	}
	buf := make([]u8, n, allocator)
	gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, cast(cstring)raw_data(buf), n)
	return string(buf)
}
