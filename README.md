# ScrollToggle

ScrollToggle is a small macOS menu-bar utility for switching between Natural Scrolling and Traditional Scrolling. It remembers a separate scrolling preference for the built-in trackpad and for every external Bluetooth or wired mouse it sees, then activates the profile for the device you most recently used.

Trackpad input activates the trackpad immediately. To avoid switching because of sensor noise or a desk bump, an inactive mouse must produce two movement reports totaling eight raw movement counts within 100 milliseconds. A mouse click or wheel movement activates the mouse immediately. Detection is driven entirely by HID events and does not poll in the background.

Left-click the menu-bar icon to toggle and save the scrolling mode for the active device. Right-click it to see connected and remembered devices; hover over any device to change its Natural Scrolling preference. The menu also provides launch-at-login and quit controls.

Automatic device switching requires permission in System Settings → Privacy & Security → Input Monitoring. Relaunch ScrollToggle after granting access.

## Build instructions

- `make` builds `build/ScrollToggle.app`
- `make install` builds the app and copies it to `/Applications`
- `make clean` removes the generated app bundle
- `make test` runs the activity-filter and device-selection tests
- `make reinstall` rebuilds the app, stops any running copy, installs it to `/Applications`, and opens it

Source files live in `src/`, bundle metadata lives in `resources/`, and generated build output is placed in `build/`.

## Disclaimer

This is a quick personal tool built to solve a specific need. It changes the macOS system scrolling preference, so use it with caution and review the code before running it on your system.
