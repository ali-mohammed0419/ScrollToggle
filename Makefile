APP = ScrollToggle
SRC = src/main.m src/DeviceProfile.m src/DeviceStore.m src/DeviceSelection.m src/MouseDeviceMonitor.m src/MouseNudgeFilter.c src/DeviceActivityRouting.c
HEADERS = src/DeviceProfile.h src/DeviceStore.h src/DeviceSelection.h src/MouseDeviceMonitor.h src/MouseNudgeFilter.h src/DeviceActivityRouting.h
PLIST = resources/Info.plist

BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS = $(CONTENTS)/MacOS
BINARY = $(MACOS)/$(APP)
NUDGE_TEST_BINARY = $(BUILD_DIR)/MouseNudgeFilterTests
SELECTION_TEST_BINARY = $(BUILD_DIR)/DeviceSelectionTests
ROUTING_TEST_BINARY = $(BUILD_DIR)/DeviceActivityRoutingTests

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
	codesign --force --sign - $(APP_BUNDLE)

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

test: $(NUDGE_TEST_BINARY) $(SELECTION_TEST_BINARY) $(ROUTING_TEST_BINARY)
	$(NUDGE_TEST_BINARY)
	$(SELECTION_TEST_BINARY)
	$(ROUTING_TEST_BINARY)

$(NUDGE_TEST_BINARY): tests/MouseNudgeFilterTests.c src/MouseNudgeFilter.c src/MouseNudgeFilter.h
	mkdir -p $(BUILD_DIR)
	$(CC) -std=c11 -Isrc tests/MouseNudgeFilterTests.c src/MouseNudgeFilter.c -o $(NUDGE_TEST_BINARY)

$(SELECTION_TEST_BINARY): tests/DeviceSelectionTests.m src/DeviceSelection.m src/DeviceSelection.h src/DeviceProfile.m src/DeviceProfile.h
	mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -Isrc -framework Foundation tests/DeviceSelectionTests.m src/DeviceSelection.m src/DeviceProfile.m -o $(SELECTION_TEST_BINARY)

$(ROUTING_TEST_BINARY): tests/DeviceActivityRoutingTests.c src/DeviceActivityRouting.c src/DeviceActivityRouting.h
	mkdir -p $(BUILD_DIR)
	$(CC) -std=c11 -Isrc tests/DeviceActivityRoutingTests.c src/DeviceActivityRouting.c -o $(ROUTING_TEST_BINARY)

.PHONY: all install clean reinstall run test
