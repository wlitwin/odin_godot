package main
import "core:fmt"
import corpus "../shared"
main :: proc(){code,hash:=corpus.verify();assert(code==0,fmt.tprintf("layout corpus %d",code));fmt.printf("LAYOUT_CORPUS_OK cases=4 hash=%d\n",hash)}
