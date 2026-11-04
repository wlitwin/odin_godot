// Test-only control/transport plumbing. Production packets remain opaque here.
package network_common
import "core:encoding/hex"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import bd "godot:box3d/diagnostics"
SOCKET_LIBRARY :: #config(BOX3D_NETWORK_SOCKET_LIBRARY, "system:c")
SOCKET_LINK ::
	"system:" +
	SOCKET_LIBRARY when len(SOCKET_LIBRARY) > 0 &&
	SOCKET_LIBRARY[0] == '/' else SOCKET_LIBRARY
foreign import socket_lib {SOCKET_LINK}
foreign socket_lib {
	bn_open :: proc "c" (_: u32, _: u32, _: u64) -> rawptr ---
	bn_live_bytes :: proc "c" () -> u64 ---
	bn_peak_rss :: proc "c" () -> u64 ---
	bn_owned_bytes :: proc "c" () -> u64 ---
	bn_send :: proc "c" (_: rawptr, _: u32, _: u32, _: u64, _: [^]u8, _: u32) -> i32 ---
	bn_poll :: proc "c" (_: rawptr) -> i32 ---
	bn_receive :: proc "c" (_: rawptr, _: ^u32, _: ^u64, _: [^]u8, _: u32, _: ^u32) -> i32 ---
	bn_stats :: proc "c" (_: rawptr, _: [^]u64) ---
	bn_close :: proc "c" (_: rawptr) ---
}
Endpoint :: struct {
	socket:                                  rawptr,
	role, round:                             u32,
	generation, remote_generation, sequence: u64,
	connected:                               bool,
	failed:                                  bool,
	packet:                                  [65536]u8,
	sent, received:                          u64,
}
open :: proc(e: ^Endpoint, port: u32, role: u32, generation: u64 = 1) -> bool {
	e^ = {
		role              = role,
		generation        = generation,
		remote_generation = 1,
		connected         = false,
	}
	e.socket = bn_open(port, role, generation); return e.socket != nil
}
socket_owned_bytes :: proc() -> u64 {return bn_owned_bytes()}
owned_bytes :: proc() -> u64 {return bn_owned_bytes() + u64(size_of(Endpoint))}
close :: proc(e: ^Endpoint) {if e.socket != nil {bn_close(e.socket)}; e^ = {}}
send :: proc(e: ^Endpoint, channel: u32, bytes: []u8) -> i32 {
	next := e.sequence + 1
	result := bn_send(e.socket, channel, e.round, next, raw_data(bytes), u32(len(bytes)))
	if result == 1 {e.sent += 1; e.sequence = next}
	if result < 0 {e.failed = true}
	return result
}
poll :: proc(e: ^Endpoint) {if bn_poll(e.socket) < 0 {e.failed = true}}
receive :: proc(
	e: ^Endpoint,
	dst: []u8,
) -> (
	result: i32,
	channel: u32,
	sequence: u64,
	count: u32,
) {
	result = bn_receive(e.socket, &channel, &sequence, raw_data(dst), u32(len(dst)), &count)
	if result == 1 {
		e.received += 1
		if channel <
		   2 {digest := bd.hash_bytes(dst[:count]); text := hex_bytes(digest[:]); defer delete(text); reply("{\"event\":\"packet_received\",\"role\":%d,\"generation\":%d,\"sender_generation\":%d,\"round\":%d,\"channel\":%d,\"sequence\":%d,\"bytes\":%d,\"sha256\":\"%s\"}", e.role, e.generation, e.remote_generation, e.round, channel, sequence, count, text)}
	}
	if result < 0 {e.failed = true}
	return
}
stats :: proc(e: ^Endpoint) -> [5]u64 {values: [5]u64; bn_stats(e.socket, raw_data(values[:]))
	return values}
hex_bytes :: proc(bytes: []u8) -> string {
	data, error := hex.encode(bytes); assert(error == nil); return string(data)
}
signature_hex :: proc(signature: bd.Signature) -> string {
	bytes: [bd.SIGNATURE_BYTES]u8; n, error := bd.signature_encode(signature, bytes[:]); assert(error == .None && n == len(bytes)); return hex_bytes(bytes[:])
}
write_bytes :: proc(path: string, bytes: []u8) {assert(os.write_entire_file(path, bytes) == nil)}
Args :: struct {
	role:              u32,
	port:              u32,
	out:               string,
	variant:           string,
	generation, epoch: u64,
}
args :: proc() -> Args {
	assert(
		len(os.args) >= 4,
	); role, er := strconv.parse_u64(os.args[1]); port, ep := strconv.parse_u64(os.args[2]); assert(er && ep)
	return {
		role = u32(role),
		port = u32(port),
		out = os.args[3],
		variant = len(os.args) > 4 ? os.args[4] : "clean",
		generation = len(os.args) > 5 ? number(os.args[5]) : 1,
		epoch = len(os.args) > 6 ? number(os.args[6]) : 1,
	}
}
// A bounded stdin command, separate from socket packets. No state bytes enter here.
Command :: struct {
	storage: string,
	fields:  []string,
}
read_command :: proc() -> Command {
	buffer: [512]u8; n := 0
	for n <
	    len(
		    buffer,
	    ) {one: [1]u8; count, error := os.read(os.stdin, one[:]); if count == 0 || error != nil {return {}}; if one[0] == 10 {break}; buffer[n] = one[0]; n += 1}
	assert(
		n < len(buffer),
	); storage := strings.clone(string(buffer[:n])); return {storage, strings.fields(storage)}
}
command_destroy :: proc(c: ^Command) {delete(c.fields); delete(c.storage); c^ = {}}
number :: proc(text: string) -> u64 {n, error := strconv.parse_u64(text); assert(error); return n}
reply :: proc(format: string, args: ..any) {
	if len(format) >= 2 &&
	   format[0] == '{' &&
	   format[len(format) - 1] ==
		   '}' {fmt.print("{"); fmt.printf(format[1:len(format) - 1], ..args); fmt.print("}\n")} else {fmt.printf(format, ..args); fmt.print("\n")}
}

handle_lifecycle :: proc(e: ^Endpoint, bytes: []u8) -> bool {
	assert(len(bytes) == 12)
	connected: u32; generation: u64
	for v, i in bytes[:4] {connected |= u32(v) << uint(8 * i)}
	for v, i in bytes[4:] {generation |= u64(v) << uint(8 * i)}
	assert(connected <= 1 && generation > 0)
	was := e.connected; e.connected = connected == 1; e.remote_generation = generation
	return was && !e.connected
}

peak_rss :: proc() -> u64 {return bn_peak_rss()}

socket_live_bytes :: proc() -> u64 {return bn_live_bytes()}
