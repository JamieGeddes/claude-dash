APP_NAME = ClaudeDash
BUILD_DIR = build
APP = $(BUILD_DIR)/$(APP_NAME).app
BINARY = .build/release/$(APP_NAME)
RESOURCE_BUNDLE = .build/release/$(APP_NAME)_$(APP_NAME).bundle

.PHONY: build test run release app install clean

build:
	swift build

test:
	swift test

run:
	swift run

release:
	swift build -c release

app: release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BINARY) $(APP)/Contents/MacOS/
	if [ -d "$(RESOURCE_BUNDLE)" ]; then cp -R "$(RESOURCE_BUNDLE)" $(APP)/Contents/Resources/; fi
	cp Scripts/Info.plist $(APP)/Contents/Info.plist
	codesign --force --sign - $(APP)
	@echo "Built $(APP)"

install: app
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP) /Applications/
	@echo "Installed /Applications/$(APP_NAME).app"

clean:
	rm -rf $(BUILD_DIR) .build
