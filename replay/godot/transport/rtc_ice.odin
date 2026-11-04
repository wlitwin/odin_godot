package replay_godot_transport

import wiregd "godot:replay/godot/internal/wire"

import "core:strings"
import gd "godot:godot"
import "godot:gdext"

Rtc_Ice_Error :: enum {
    None,
    Size,
    Json,
    Servers,
    Url,
    Credentials,
    Policy,
}

RTC_ICE_BYTES :: 8192

// Validates the bounded ICE subset used by the adapter before signaling opens.
// Other RTCConfiguration fields are passed through to the platform unchanged.
rtc_ice_validate :: proc(json: string) -> Rtc_Ice_Error {
    if json == "" {
        return .None
    }

    if len(json) > RTC_ICE_BYTES {
        return .Size
    }

    if !wiregd.json_depth(transmute([]u8)json) {
        return .Json
    }

    text := gd.new_string_odin(json)
    defer gd.free_string(text)
    value := gd.json_parse_string(text)
    defer gd.variant_destroy(&value)

    if gdext.variant_get_type(&value) != .Dictionary {
        return .Json
    }

    config := gd.variant_to_dictionary(&value)
    defer gd.free_dictionary(config)
    policy := wiregd.get(&config, "iceTransportPolicy")
    defer gd.variant_destroy(&policy)
    relay := false

    if gdext.variant_get_type(&policy) != .Nil {
        if gdext.variant_get_type(&policy) != .String {
            return .Policy
        }

        name := wiregd.get_string(&config, "iceTransportPolicy", 16)
        defer delete(name)

        if name != "all" && name != "relay" {
            return .Policy
        }

        relay = name == "relay"
    }

    servers_value := wiregd.get(&config, "iceServers")
    defer gd.variant_destroy(&servers_value)

    if gdext.variant_get_type(&servers_value) == .Nil {
        return relay ? .Policy : .None
    }

    if gdext.variant_get_type(&servers_value) != .Array {
        return .Servers
    }

    servers := gd.variant_to_array(&servers_value)
    defer gd.free_array(servers)
    count := gd.array_size(&servers)

    if count > 8 {
        return .Servers
    }

    has_turn := false

    for i in 0 ..< count {
        entry := gd.array_get(&servers, i)
        defer gd.variant_destroy(&entry)

        if gdext.variant_get_type(&entry) != .Dictionary {
            return .Servers
        }

        server := gd.variant_to_dictionary(&entry)
        defer gd.free_dictionary(server)
        urls := wiregd.get(&server, "urls")
        defer gd.variant_destroy(&urls)
        turn := false

        if gdext.variant_get_type(&urls) == .String {
            u := gd.variant_to_string(&urls)
            defer gd.free_string(u)
            valid: bool
            turn, valid = rtc_ice_url(gd.gd_string_to_odin(u))

            if !valid {
                return .Url
            }
        } else if gdext.variant_get_type(&urls) == .Array {
            list := gd.variant_to_array(&urls)
            defer gd.free_array(list)

            if gd.array_size(&list) < 1 || gd.array_size(&list) > 8 {
                return .Url
            }

            for j in 0 ..< gd.array_size(&list) {
                item := gd.array_get(&list, j)
                defer gd.variant_destroy(&item)

                if gdext.variant_get_type(&item) != .String {
                    return .Url
                }

                u := gd.variant_to_string(&item)
                defer gd.free_string(u)
                is_turn, valid := rtc_ice_url(gd.gd_string_to_odin(u))

                if !valid {
                    return .Url
                }

                turn = turn || is_turn
            }
        } else {
            return .Url
        }

        user := wiregd.get(&server, "username")
        defer gd.variant_destroy(&user)
        password := wiregd.get(&server, "credential")
        defer gd.variant_destroy(&password)

        if gdext.variant_get_type(&user) != .Nil && gdext.variant_get_type(&user) != .String {
            return .Credentials
        }

        if gdext.variant_get_type(&password) != .Nil && gdext.variant_get_type(&password) != .String {
            return .Credentials
        }

        if turn {
            username := wiregd.get_string(&server, "username", 256)
            defer delete(username)
            credential := wiregd.get_string(&server, "credential", 512)
            defer delete(credential)

            if len(username) == 0 || len(credential) == 0 {
                return .Credentials
            }
        }

        has_turn = has_turn || turn
    }

    return relay && !has_turn ? .Policy : .None
}

// Deployment data never comes from URL query parameters. Native embeddings use
// an environment value; browser hosts set replayIceConfig before starting Godot.
// The returned string borrows the current temporary allocator; opening copies it.
rtc_ice_settings :: proc(environment: cstring) -> (string, Rtc_Ice_Error) {
    json := ""

    when gd.IS_WEB {
        code := gd.new_string_odin(
            `(()=>{try{const value=globalThis.replayIceConfig;if(value===undefined)return "";const text=typeof value==="string"?value:JSON.stringify(value);return typeof text==="string"&&text.length<=8192?text:"invalid";}catch{return "invalid";}})()`,
        )
        defer gd.free_string(code)
        value := gd.java_script_bridge_eval(gd.singleton_java_script_bridge(), code, true)
        defer gd.variant_destroy(&value)

        if gdext.variant_get_type(&value) != .String {
            return "", .Json
        }

        text := gd.variant_to_string(&value)
        defer gd.free_string(text)
        json = gd.gd_string_to_odin(text)
    } else {
        json = gd.env_string(environment, "")
    }

    error := rtc_ice_validate(json)
    return error == .None ? json : "", error
}

@(private)
rtc_ice_url :: proc(url: string) -> (turn, valid: bool) {
    if len(url) < 6 || len(url) > 512 {
        return false, false
    }

    for b in url {
        if b <= 32 || b > 126 || b == '@' || b == '#' || b == '\\' {
            return false, false
        }
    }

    prefix := 0

    for candidate in ([4]string{"stun:", "stuns:", "turn:", "turns:"}) {
        if strings.has_prefix(url, candidate) {
            prefix = len(candidate)
            break
        }
    }

    if prefix == 0 || prefix == len(url) || strings.has_prefix(url[prefix:], "//") {
        return false, false
    }

    turn = strings.has_prefix(url, "turn:") || strings.has_prefix(url, "turns:")
    rest := url[prefix:]

    if at := strings.index_byte(rest, '?'); at >= 0 {
        if !turn || (rest[at:] != "?transport=udp" && rest[at:] != "?transport=tcp") {
            return false, false
        }

        rest = rest[:at]
    }

    if len(rest) == 0 {
        return false, false
    }

    port := ""

    if rest[0] == '[' {
        end := strings.index_byte(rest, ']')

        if end <= 1 {
            return false, false
        }

        for b in rest[1:end] {
            if !(b >= '0' && b <= '9') && !(b >= 'a' && b <= 'f') && !(b >= 'A' && b <= 'F') && b != ':' && b != '.' {
                return false, false
            }
        }

        if end + 1 < len(rest) {
            if rest[end + 1] != ':' {
                return false, false
            }

            port = rest[end + 2:]

            if port == "" {
                return false, false
            }
        }
    } else {
        host := rest

        if at := strings.index_byte(rest, ':'); at >= 0 {
            host, port = rest[:at], rest[at + 1:]

            if port == "" {
                return false, false
            }
        }

        if len(host) == 0 {
            return false, false
        }

        for b in host {
            if !(b >= 'a' && b <= 'z') &&
               !(b >= 'A' && b <= 'Z') &&
               !(b >= '0' && b <= '9') &&
               b != '-' &&
               b != '.' &&
               b != '_' {
                return false, false
            }
        }
    }

    if port != "" {
        if len(port) > 5 {
            return false, false
        }

        value := 0

        for b in port {
            if b < '0' || b > '9' {
                return false, false
            }

            value = value * 10 + int(b - '0')
        }

        if value < 1 || value > 65535 {
            return false, false
        }
    }

    return turn, true
}
