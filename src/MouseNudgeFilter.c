#include "MouseNudgeFilter.h"

#include <limits.h>

void STMouseNudgeReset(STMouseNudgeState *state, uint64_t generation) {
    state->generation = generation;
    state->windowStart = 0;
    state->lastReportTimestamp = 0;
    state->distance = 0;
    state->reportCount = 0;
    state->hasWindow = false;
}

static uint64_t STUnsignedMagnitude(int64_t value) {
    if (value >= 0) {
        return (uint64_t)value;
    }
    return (uint64_t)(-(value + 1)) + 1;
}

bool STMouseNudgeRecordMovement(STMouseNudgeState *state,
                                int64_t delta,
                                uint64_t timestamp,
                                uint64_t windowTicks,
                                uint64_t generation) {
    if (delta == 0) {
        return false;
    }

    bool expired = state->hasWindow &&
        (timestamp < state->windowStart ||
         timestamp - state->windowStart > windowTicks);
    if (state->generation != generation || !state->hasWindow || expired) {
        STMouseNudgeReset(state, generation);
        state->hasWindow = true;
        state->windowStart = timestamp;
        state->lastReportTimestamp = timestamp;
        state->reportCount = 1;
    } else if (timestamp != state->lastReportTimestamp) {
        state->lastReportTimestamp = timestamp;
        if (state->reportCount < UINT16_MAX) {
            state->reportCount++;
        }
    }

    uint64_t magnitude = STUnsignedMagnitude(delta);
    uint64_t total = (uint64_t)state->distance + magnitude;
    state->distance = total >= STMouseNudgeDistanceThreshold
        ? STMouseNudgeDistanceThreshold
        : (uint32_t)total;

    return state->reportCount >= STMouseNudgeReportThreshold &&
        state->distance >= STMouseNudgeDistanceThreshold;
}
