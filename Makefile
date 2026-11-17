SCHEME := Lenscam
PROJECT := ios/Lenscam.xcodeproj
BUNDLE_ID := com.kekaflow.lenscam
CONFIGURATION := Debug
DERIVED := build/DerivedData
SIMULATOR ?= iPhone 17

.PHONY: help sim device

help:
	@echo "make sim       Build Lenscam and run it on the iPhone simulator"
	@echo "make device    Build Lenscam and install it on the connected iPhone"
	@echo ""
	@echo "Overrides:"
	@echo "  SIMULATOR='iPhone 17 Pro' make sim"
	@echo "  DEVICE_ID=<udid> make device"

sim:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" \
		-destination "platform=iOS Simulator,name=$(SIMULATOR)" \
		-derivedDataPath "$(DERIVED)" \
		build
	@xcrun simctl boot "$(SIMULATOR)" >/dev/null 2>&1 || true
	xcrun simctl bootstatus "$(SIMULATOR)" -b
	open -a Simulator
	@APP=$$(find "$(DERIVED)/Build/Products" -path "*$(CONFIGURATION)-iphonesimulator/$(SCHEME).app" -type d | head -1); \
	if [ -z "$$APP" ]; then echo "Simulator build did not produce $(SCHEME).app" >&2; exit 1; fi; \
	xcrun simctl install booted "$$APP"; \
	xcrun simctl launch booted "$(BUNDLE_ID)"

device:
	@set -e; \
	UDID="$(DEVICE_ID)"; \
	if [ -z "$$UDID" ]; then \
		UDID=$$(xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -showdestinations 2>/dev/null | awk -F '[,}]' '/platform:iOS, arch:arm64/ { for (i = 1; i <= NF; i++) if ($$i ~ /id:/) { split($$i, a, ":"); gsub(/ /, "", a[2]); print a[2]; exit } }'); \
	fi; \
	if [ -z "$$UDID" ]; then echo "No connected iPhone. Unlock the phone, trust this Mac, and try again." >&2; exit 1; fi; \
	echo "Building for $$UDID"; \
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" \
		-destination "platform=iOS,id=$$UDID" \
		-allowProvisioningUpdates \
		-derivedDataPath "$(DERIVED)" \
		CODE_SIGNING_REQUIRED=YES \
		build; \
	APP=$$(find "$(DERIVED)/Build/Products" -path "*$(CONFIGURATION)-iphoneos/$(SCHEME).app" -type d | head -1); \
	if [ -z "$$APP" ]; then echo "Device build did not produce $(SCHEME).app" >&2; exit 1; fi; \
	xcrun devicectl device install app --device "$$UDID" "$$APP"; \
	if ! xcrun devicectl device process launch --device "$$UDID" "$(BUNDLE_ID)"; then \
		echo "Lenscam is installed. Unlock the iPhone to open it."; \
	fi
