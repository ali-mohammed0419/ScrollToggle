#include "DeviceActivityRouting.h"

#include <assert.h>
#include <stdio.h>

int main(void) {
    assert(STActivityRoutesInputValue(STActivityDeviceKindMouse));
    assert(!STActivityRoutesInputReport(STActivityDeviceKindMouse));

    assert(!STActivityRoutesInputValue(STActivityDeviceKindTrackpad));
    assert(STActivityRoutesInputReport(STActivityDeviceKindTrackpad));

    assert(!STActivityRoutesInputValue(STActivityDeviceKindUnknown));
    assert(!STActivityRoutesInputReport(STActivityDeviceKindUnknown));

    puts("DeviceActivityRoutingTests passed");
    return 0;
}
