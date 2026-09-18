# ScrollToggle

ScrollToggle is a small macOS menu-bar utility for switching between Natural Scrolling and Traditional Scrolling. It remembers a separate scrolling preference for the built-in trackpad fallback and for every external Bluetooth or wired mouse it sees, then applies the appropriate preference as mice connect and disconnect.

Left-click the menu-bar icon to toggle and save the scrolling mode for the active device. Right-click it to see connected and remembered devices; hover over any device to change its Natural Scrolling preference. The menu also provides launch-at-login and quit controls.

## Build instructions

- `make` builds `ScrollToggle.app`
- `make install` builds the app and copies it to `/Applications`
- `make clean` removes the generated app bundle
- `make reinstall` rebuilds the app, stops any running copy, installs it to `/Applications`, and opens it

## Disclaimer

This is a quick personal tool built to solve a specific need. It changes the macOS system scrolling preference, so use it with caution and review the code before running it on your system.
