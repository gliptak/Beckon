PROJECT := Beckon.xcodeproj
SCHEME := Beckon
CONFIG ?= Release
DERIVED_DATA := .build
APP_PATH := $(DERIVED_DATA)/Build/Products/$(CONFIG)/Beckon.app
APP_BINARY := $(APP_PATH)/Contents/MacOS/Beckon
UNIVERSAL_ARCHS := arm64 x86_64
TEST_DESTINATION ?= platform=macOS,arch=arm64
UNSIGNED_FLAGS := CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

.PHONY: help list build release debug universal test ci run clean

help:
	@echo "Targets:"
	@echo "  make list      - List schemes and targets"
	@echo "  make build     - Build universal Release app (arm64 + x86_64, unsigned)"
	@echo "  make universal - Alias for build"
	@echo "  make release   - Alias for build"
	@echo "  make debug     - Build universal Debug app (arm64 + x86_64, unsigned)"
	@echo "  make test      - Run unit tests"
	@echo "  make ci        - Run local CI checks (test + release build)"
	@echo "  make run       - Build universal Release and launch app"
	@echo "                   (run uses signing so Accessibility permission can persist)"
	@echo "  make clean     - Remove local build output"

list:
	xcodebuild -list -project $(PROJECT)

build:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(DERIVED_DATA) \
		ARCHS="$(UNIVERSAL_ARCHS)" \
		ONLY_ACTIVE_ARCH=NO \
		$(UNSIGNED_FLAGS) \
		build
	@echo "Built app binary architectures:"
	@lipo -info "$(APP_BINARY)"

release: build

universal: build

debug:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(DERIVED_DATA) \
		ARCHS="$(UNIVERSAL_ARCHS)" \
		ONLY_ACTIVE_ARCH=NO \
		$(UNSIGNED_FLAGS) \
		build
	@echo "Built app binary architectures:"
	@lipo -info "$(APP_BINARY)"

test:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination "$(TEST_DESTINATION)" \
		-derivedDataPath $(DERIVED_DATA) \
		test

ci: test build

run:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(DERIVED_DATA) \
		ARCHS="$(UNIVERSAL_ARCHS)" \
		ONLY_ACTIVE_ARCH=NO \
		build
	@echo "Built app binary architectures:"
	@lipo -info "$(APP_BINARY)"
	open $(APP_PATH)

clean:
	rm -rf $(DERIVED_DATA)
