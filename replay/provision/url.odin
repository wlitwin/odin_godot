package replay_provision

import "core:strings"

service_url_valid :: proc(url: string, local_development: bool = false) -> bool {
	if len(url) == 0 || len(url) > 2048 {return false}
	secure := strings.has_prefix(url, "wss://")
	if !secure && (!local_development || !strings.has_prefix(url, "ws://")) {return false}
	rest := url[secure ? 6 : 5:]
	end := len(rest)
	for b, i in rest {if b <= 32 || b == 127 || b == '\\' {return false}; if (b == '/' || b == '?' || b == '#') && end == len(rest) {end = i}}
	authority := rest[:end]
	if len(authority) == 0 {return false}
	for b in authority {if b == '@' {return false}}
	if secure {return true}
	port := ""
	for prefix in ([3]string{"127.0.0.1:", "localhost:", "[::1]:"}) {if strings.has_prefix(authority, prefix) {port = authority[len(prefix):]; break}}
	if len(port) < 1 || len(port) > 5 {return false}
	value := 0
	for b in port {if b < '0' || b > '9' {return false}; value = value * 10 + int(b - '0')}
	return value >= 1 && value <= 65535
}
