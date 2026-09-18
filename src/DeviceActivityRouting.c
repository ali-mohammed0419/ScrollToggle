#include "DeviceActivityRouting.h"

bool STActivityRoutesInputValue(STActivityDeviceKind kind) {
    return kind == STActivityDeviceKindMouse;
}

bool STActivityRoutesInputReport(STActivityDeviceKind kind) {
    return kind == STActivityDeviceKindTrackpad;
}
