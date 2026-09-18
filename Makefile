APP = ScrollToggle
SRC = src/main.m src/DeviceProfile.m src/DeviceStore.m src/DeviceSelection.m src/MouseDeviceMonitor.m
HEADERS = src/DeviceProfile.h src/DeviceStore.h src/DeviceSelection.h src/MouseDeviceMonitor.h
PLIST = resources/Info.plist

BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS = $(CONTENTS)/MacOS
BINARY = $(MACOS)/$(APP)

INSTALL_APP = /Applications/$(APP).app

CC = clang
CFLAGS = -fobjc-arc -mmacosx-version-min=13.0
FRAMEWORKS = -framework Cocoa -framework ServiceManagement -framework IOKit

all: $(APP_BUNDLE)

$(APP_BUNDLE): $(SRC) $(HEADERS) $(PLIST)
	rm -rf $(APP_BUNDLE)
	mkdir -p $(MACOS)

	$(CC) $(CFLAGS) $(FRAMEWORKS) $(SRC) -o $(BINARY)

	cp $(PLIST) $(CONTENTS)/Info.plist

install: $(APP_BUNDLE)
	rm -rf $(INSTALL_APP)
	cp -R $(APP_BUNDLE) /Applications/

clean:
	rm -rf $(APP_BUNDLE)

reinstall: clean all
	-killall $(APP)
	rm -rf $(INSTALL_APP)
	cp -R $(APP_BUNDLE) /Applications/
	open $(INSTALL_APP)

run: reinstall

.PHONY: all install clean reinstall run
