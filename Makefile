PROJECT := Beckon.xcodeproj
SCHEME := Beckon
CONFIG ?= Release
DERIVED_DATA := .build
APP_PATH := $(DERIVED_DATA)/Build/Products/$(CONFIG)/Beckon.app

.PHONY: help list build release debug run clean

help:
	@echo "Targets:"
	@echo "  make list      - List schemes and targets"
	@echo "  make build     - Build Release (unsigned)"
	@echo "  make release   - Alias for build"
	@echo "  make debug     - Build Debug (unsigned)"
	@echo "  make run       - Build Release and launch app"
	@echo "  make clean     - Remove local build output"

list:
	xcodebuild -list -project $(PROJECT)

build:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		build

release: build

debug:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		build

run: build
	open $(APP_PATH)

clean:
	rm -rf $(DERIVED_DATA)
