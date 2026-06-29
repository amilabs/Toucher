APP_NAME := Toucher
BUNDLE_ID := com.amilabs.Toucher
APP_VERSION := 0.5.7
BUILD_DATE := $(shell date "+%Y-%m-%d %H:%M")
REPOSITORY_URL := https://github.com/amilabs/Toucher
SIGN_IDENTITY ?= WindowGestures Local Dev
EXECUTABLE_NAME := WindowGesturesApp
CONFIGURATION ?= debug
BUILD_DIR := .build/$(CONFIGURATION)
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
APP_EXECUTABLE := $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
DEBUG_BUILD_DIR := .build/debug
DEBUG_APP_BUNDLE := $(DEBUG_BUILD_DIR)/$(APP_NAME).app
INSTALL_APP ?= $(HOME)/Applications/$(APP_NAME).app
INSTALL_DIR = $(dir $(INSTALL_APP))
WINDOWGESTURES_GESTURE_BACKEND ?=

.PHONY: test build check-sign-identity install-debug run-debug reset-accessibility debug-reset-accessibility debug-verify-bundle debug-signing-info debug-cpu-note check clean

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
	/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $(APP_VERSION)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :ToucherBuildDate string $(BUILD_DATE)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :ToucherRepositoryURL string $(REPOSITORY_URL)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 13.0" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :NSPrincipalClass string NSApplication" "$(APP_BUNDLE)/Contents/Info.plist"

check-sign-identity:
	@if [ "$(SIGN_IDENTITY)" = "-" ]; then \
		echo "Using explicit ad-hoc signing identity"; \
	elif security find-identity -v -p codesigning | grep -F '"$(SIGN_IDENTITY)"' >/dev/null; then \
		echo "Using signing identity: $(SIGN_IDENTITY)"; \
	else \
		echo "Missing valid code signing identity: $(SIGN_IDENTITY)"; \
		echo "Create a local Code Signing certificate named '$(SIGN_IDENTITY)' or explicitly run with SIGN_IDENTITY=- for ad-hoc signing."; \
		exit 1; \
	fi

install-debug: check-sign-identity
	pkill -x $(EXECUTABLE_NAME) || true
	pkill -x WindowGestures || true
	pkill -x $(APP_NAME) || true
	$(MAKE) build CONFIGURATION=debug
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_APP)"
	ditto "$(DEBUG_APP_BUNDLE)" "$(INSTALL_APP)"
	chmod +x "$(INSTALL_APP)/Contents/MacOS/$(APP_NAME)"
	codesign --force --deep --sign "$(SIGN_IDENTITY)" "$(INSTALL_APP)"
	touch "$(INSTALL_APP)"

run-debug:
	$(MAKE) install-debug
	@if [ -n "$(WINDOWGESTURES_GESTURE_BACKEND)" ]; then \
		open --env WINDOWGESTURES_GESTURE_BACKEND="$(WINDOWGESTURES_GESTURE_BACKEND)" "$(INSTALL_APP)"; \
	else \
		open "$(INSTALL_APP)"; \
	fi
	pgrep -af $(APP_NAME) || true

reset-accessibility:
	@echo "App bundle id: $(BUNDLE_ID)"; \
	tccutil reset Accessibility "$(BUNDLE_ID)"; \
	echo "If Toucher still shows the wrong Accessibility state, remove and re-add $(INSTALL_APP) in System Settings > Privacy & Security > Accessibility."

debug-reset-accessibility: reset-accessibility

debug-verify-bundle: install-debug
	@echo "defaults read $(INSTALL_APP)/Contents/Info:"; \
	defaults read "$(INSTALL_APP)/Contents/Info"; \
	echo "CFBundleIdentifier:"; \
	/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$(INSTALL_APP)/Contents/Info.plist"; \
	echo "CFBundleExecutable:"; \
	/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$(INSTALL_APP)/Contents/Info.plist"; \
	echo "codesign -dv --verbose=4:"; \
	codesign -dv --verbose=4 "$(INSTALL_APP)"; \
	echo "pgrep -af Toucher:"; \
	pgrep -af $(APP_NAME) || true

debug-signing-info:
	@echo "security find-identity -v -p codesigning:"; \
	security find-identity -v -p codesigning; \
	echo "codesign -dv --verbose=4:"; \
	codesign -dv --verbose=4 "$(INSTALL_APP)"; \
	echo "codesign --verify --deep --strict --verbose=2:"; \
	codesign --verify --deep --strict --verbose=2 "$(INSTALL_APP)"

debug-cpu-note:
	@echo "Check Toucher idle CPU in Activity Monitor, or run:"; \
	echo 'top -pid $$(pgrep -x Toucher)'

check: test build

clean:
	swift package clean
