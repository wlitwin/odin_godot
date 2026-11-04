#ifndef OGB3_STATE_DUMP_INTERNAL_H
#define OGB3_STATE_DUMP_INTERNAL_H
#include <stdint.h>

/* Private fresh-constructor helper, not a public ABI or a count certificate.
 * On success the caller owns wrapper-allocated bytes. On failure neither
 * output changes. The packed world must remain idle under the single caller. */
int32_t ogb3_state_dump_alloc_internal(uint32_t world, uint8_t **out_bytes,
                                       uint64_t *out_size);
#endif
