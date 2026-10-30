package main
import "core:fmt"
import corpus "shared"
main :: proc() {code,hash,cases:=corpus.verify();assert(code==0,fmt.tprintf("erasure corpus %d",code));fmt.printf("ERASURE_CORPUS_OK cases=%d hash=%d\n",cases,hash)}
