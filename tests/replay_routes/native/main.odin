package main
import "core:fmt"
import corpus "../corpus"
main :: proc() {result:=corpus.run();assert(result==0);fmt.println("REPLAY_ROUTES_NATIVE_OK")}
