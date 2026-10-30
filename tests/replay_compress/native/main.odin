package main
import "core:fmt"
import c "../shared"
main :: proc(){code,hash:=c.verify();assert(code==0);fmt.printf("COMPRESS_CORPUS_OK cases=32 hash=%d\n",hash)}
