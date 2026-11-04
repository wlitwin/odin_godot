/* Core's permanent AOT image uses its actual wasm relocation/table interval.
 * The link coordinator derives the count from dylink.0, relinks once, and checks
 * that the final interval size agrees. No JS pointer-number bridge is used. */
#include <stdint.h>
#include <pthread.h>
#ifndef ODIN_BOX3D_TABLE_SIZE
#error "the verified web link coordinator supplies the actual table size"
#endif
__attribute__((visibility("default")))
uint32_t odin_box3d_table_size(void) { return ODIN_BOX3D_TABLE_SIZE; }
__attribute__((visibility("default")))
uintptr_t odin_box3d_thread_id(void) { return (uintptr_t)pthread_self(); }

static pthread_mutex_t managed_mutex = PTHREAD_MUTEX_INITIALIZER;
__attribute__((visibility("default")))
void odin_box3d_managed_lock(void) { pthread_mutex_lock(&managed_mutex); }
__attribute__((visibility("default")))
void odin_box3d_managed_unlock(void) { pthread_mutex_unlock(&managed_mutex); }
__attribute__((visibility("default")))
uint32_t odin_box3d_managed_mutex_bytes(void) { return sizeof(managed_mutex); }
