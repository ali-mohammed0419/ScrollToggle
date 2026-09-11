APP = ScrollToggle
SRC = main.m

APP_BUNDLE = $(APP).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS = $(CONTENTS)/MacOS
BINARY = $(MACOS)/$(APP)

INSTALL_APP = /Applications/$(APP_BUNDLE)

CC = clang
CFLAGS = -fobjc-arc -mmacosx-version-min=13.0
FRAMEWORKS = -framework Cocoa -framework ServiceManagement

all: $(APP_BUNDLE)

$(APP_BUNDLE): $(SRC) Info.plist
	rm -rf $(APP_BUNDLE)
	mkdir -p $(MACOS)

	$(CC) $(CFLAGS) $(FRAMEWORKS) $(SRC) -o $(BINARY)

	cp Info.plist $(CONTENTS)/Info.plist

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