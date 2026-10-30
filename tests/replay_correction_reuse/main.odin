package main
import "core:fmt"
import c "shared"
main :: proc() {hash,reused,ok:=c.verify();assert(ok);fmt.printf("CORRECTION_REUSE_OK cases=128 hash=%d reused=%d\n",hash,reused);bench()}
