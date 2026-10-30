package main
import "core:fmt"
import "core:os"
import corpus "../shared"
main :: proc() {
	result:=corpus.run();if !result.ok {os.exit(1)}
	fmt.printf("%d %d %d\n",result.fingerprint,result.hash,result.count)
	for byte in result.bytes[:result.count] {fmt.printf("%02x",byte)};fmt.println()
}
