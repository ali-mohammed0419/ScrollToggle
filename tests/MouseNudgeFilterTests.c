#include "MouseNudgeFilter.h"

#include <assert.h>
#include <stdio.h>

static void testRequiresTwoReports(void) {
    STMouseNudgeState state = {0};
    assert(!STMouseNudgeRecordMovement(&state, 8, 100, 100, 1));
    assert(STMouseNudgeRecordMovement(&state, 1, 101, 100, 1));
}

static void testCombinesAxesFromOneReport(void) {
    STMouseNudgeState state = {0};
    assert(!STMouseNudgeRecordMovement(&state, 4, 100, 100, 1));
    assert(!STMouseNudgeRecordMovement(&state, 3, 100, 100, 1));
    assert(STMouseNudgeRecordMovement(&state, 1, 101, 100, 1));
}

static void testRejectsSubthresholdMovement(void) {
    STMouseNudgeState state = {0};
    assert(!STMouseNudgeRecordMovement(&state, 3, 100, 100, 1));
    assert(!STMouseNudgeRecordMovement(&state, -4, 101, 100, 1));
}

static void testExpiresWindowLazily(void) {
    STMouseNudgeState state = {0};
    assert(!STMouseNudgeRecordMovement(&state, 7, 100, 100, 1));
    assert(!STMouseNudgeRecordMovement(&state, 7, 201, 100, 1));
    assert(STMouseNudgeRecordMovement(&state, 1, 202, 100, 1));
}

static void testGenerationInvalidatesCandidate(void) {
    STMouseNudgeState state = {0};
    assert(!STMouseNudgeRecordMovement(&state, 7, 100, 100, 1));
    assert(!STMouseNudgeRecordMovement(&state, 1, 101, 100, 2));
    assert(STMouseNudgeRecordMovement(&state, 7, 102, 100, 2));
}

int main(void) {
    testRequiresTwoReports();
    testCombinesAxesFromOneReport();
    testRejectsSubthresholdMovement();
    testExpiresWindowLazily();
    testGenerationInvalidatesCandidate();
    puts("MouseNudgeFilterTests passed");
    return 0;
}
