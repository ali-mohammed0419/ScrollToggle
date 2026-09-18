#ifndef ST_MOUSE_NUDGE_FILTER_H
#define ST_MOUSE_NUDGE_FILTER_H

#include <stdbool.h>
#include <stdint.h>

enum {
    STMouseNudgeDistanceThreshold = 8,
    STMouseNudgeReportThreshold = 2
};

typedef struct {
    uint64_t generation;
    uint64_t windowStart;
    uint64_t lastReportTimestamp;
    uint32_t distance;
    uint16_t reportCount;
    bool hasWindow;
} STMouseNudgeState;

void STMouseNudgeReset(STMouseNudgeState *state, uint64_t generation);

// Returns true after two distinct reports total at least eight raw movement
// counts inside the supplied timestamp window.
bool STMouseNudgeRecordMovement(STMouseNudgeState *state,
                                int64_t delta,
                                uint64_t timestamp,
                                uint64_t windowTicks,
                                uint64_t generation);

#endif
