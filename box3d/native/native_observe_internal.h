#ifndef OGB3_NATIVE_OBSERVE_INTERNAL_H
#define OGB3_NATIVE_OBSERVE_INTERNAL_H
#if defined(OGB3_NATIVE_OBSERVATION) && OGB3_NATIVE_OBSERVATION
#include "native_observe.h"
uint64_t ogb3_obs_enter(uint32_t phase);
void ogb3_obs_leave(uint64_t id, int32_t native_status);
#define OGB3_OBS_BEGIN(name, phase) uint64_t name = ogb3_obs_enter(phase)
#define OGB3_OBS_END(name, status) ogb3_obs_leave(name, status)
#define OGB3_OBS_RETURN(name, expression) do { int32_t ogb3_obs_result_ = (expression); ogb3_obs_leave(name, ogb3_obs_result_); return ogb3_obs_result_; } while (0)
#else
#define OGB3_OBS_BEGIN(name, phase)
#define OGB3_OBS_END(name, status) ((void)0)
#define OGB3_OBS_RETURN(name, expression) return (expression)
#endif
#endif
