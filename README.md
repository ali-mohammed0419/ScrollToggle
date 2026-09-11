# ScrollToggle

ScrollToggle is a small macOS menu-bar utility for switching between Natural Scrolling and Traditional Scrolling. Left-click the menu-bar icon to toggle modes. Right-click it to choose a mode, manage launch-at-login, or quit the app.

## Build instructions

- `make` builds `ScrollToggle.app`
- `make install` builds the app and copies it to `/Applications`
- `make clean` removes the generated app bundle
- `make reinstall` rebuilds the app, stops any running copy, installs it to `/Applications`, and opens it

## Disclaimer

This is a quick personal tool built to solve a specific need. It changes the macOS system scrolling preference, so use it with caution and review the code before running it on your system.
