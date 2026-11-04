#include "managed_callable_protocol.h"
#include <stddef.h>
#include <inttypes.h>
#include <stdio.h>
#define S(t) sizeof(t)
#define A(t) _Alignof(t)
#define O(t,f) offsetof(t,f)
int main(void){
 const uintptr_t fields[]={1,S(odin_managed_callable_value),A(odin_managed_callable_value),S(odin_managed_callable),A(odin_managed_callable),O(odin_managed_callable,token),S(odin_managed_call_error),O(odin_managed_call_error,argument),O(odin_managed_call_error,expected),S(odin_managed_callable_args),A(odin_managed_callable_args),O(odin_managed_callable_args,count),O(odin_managed_callable_args,reserved),O(odin_managed_callable_args,result),O(odin_managed_callable_args,error),S(odin_managed_callable_stats),S(odin_managed_callable_api),O(odin_managed_callable_api,fingerprint),O(odin_managed_callable_api,create),O(odin_managed_callable_api,close),O(odin_managed_callable_api,collect),O(odin_managed_callable_api,stats)};
 uint64_t h=UINT64_C(14695981039346656037);
 for(size_t i=0;i<S(fields)/S(fields[0]);++i){uint64_t v=fields[i];for(int j=0;j<8;++j){h^=v&255;h*=UINT64_C(1099511628211);v>>=8;}}
 printf("%"PRIu64"\n",h);return 0;
}
