#ifndef ST_DEVICE_ACTIVITY_ROUTING_H
#define ST_DEVICE_ACTIVITY_ROUTING_H

#include <stdbool.h>

typedef enum {
    STActivityDeviceKindUnknown,
    STActivityDeviceKindMouse,
    STActivityDeviceKindTrackpad
} STActivityDeviceKind;

bool STActivityRoutesInputValue(STActivityDeviceKind kind);
bool STActivityRoutesInputReport(STActivityDeviceKind kind);

#endif
