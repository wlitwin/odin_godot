package main
import "core:fmt"
import corpus "shared"
main :: proc() {
 code,hash:=corpus.verify();assert(code==0,fmt.tprintf("selection corpus %d",code))
 fmt.printf("DELTA_SELECTION_OK cases=768 budgets=7 hash=%d\n",hash)
}
