APP_NAME := WindowGestures
BUNDLE_ID := com.amilabs.WindowGestures
EXECUTABLE_NAME := WindowGesturesApp
CONFIGURATION ?= debug
BUILD_DIR := .build/$(CONFIGURATION)
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
APP_EXECUTABLE := $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
DEBUG_BUILD_DIR := .build/debug
DEBUG_APP_BUNDLE := $(DEBUG_BUILD_DIR)/$(APP_NAME).app
INSTALL_APP ?= $(HOME)/Applications/$(APP_NAME).app
INSTALL_DIR = $(dir $(INSTALL_APP))

.PHONY: test build install-debug run-debug reset-accessibility debug-verify-bundle check clean

test:
	swift test

build:
	swift build -c $(CONFIGURATION)
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(EXECUTABLE_NAME)" "$(APP_EXECUTABLE)"
	/usr/libexec/PlistBuddy -c "Clear dict" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :CFBundleName string $(APP_NAME)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $(APP_NAME)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $(BUNDLE_ID)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $(APP_NAME)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 0.1.0" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 13.0" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :NSPrincipalClass string NSApplication" "$(APP_BUNDLE)/Contents/Info.plist"

install-debug:
	pkill -x $(EXECUTABLE_NAME) || true
	pkill -x $(APP_NAME) || true
	$(MAKE) build CONFIGURATION=debug
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_APP)"
	ditto "$(DEBUG_APP_BUNDLE)" "$(INSTALL_APP)"
	chmod +x "$(INSTALL_APP)/Contents/MacOS/$(APP_NAME)"
	codesign --force --deep --sign - "$(INSTALL_APP)"

run-debug:
	$(MAKE) install-debug
	open "$(INSTALL_APP)"
	pgrep -af $(APP_NAME) || true

reset-accessibility:
	@echo "App bundle id: $(BUNDLE_ID)"; \
	tccutil reset Accessibility "$(BUNDLE_ID)"; \
	echo "If WindowGestures still appears stale, remove and re-add $(INSTALL_APP) in System Settings > Privacy & Security > Accessibility."

debug-verify-bundle: install-debug
	@echo "defaults read $(INSTALL_APP)/Contents/Info:"; \
	defaults read "$(INSTALL_APP)/Contents/Info"; \
	echo "CFBundleIdentifier:"; \
	/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$(INSTALL_APP)/Contents/Info.plist"; \
	echo "CFBundleExecutable:"; \
	/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$(INSTALL_APP)/Contents/Info.plist"; \
	echo "codesign -dv --verbose=4:"; \
	codesign -dv --verbose=4 "$(INSTALL_APP)"; \
	echo "pgrep -af WindowGestures:"; \
	pgrep -af $(APP_NAME) || true

check: test build

clean:
	swift package clean
