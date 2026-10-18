.PHONY: bootstrap generate format format-check lint build release test test-app verify lint-workflows release-dry-run ci run install open clean

PROJECT := Charbon.xcodeproj
SCHEME := Charbon
ARCHITECTURE := $(shell uname -m)
DESTINATION := platform=macOS,arch=$(ARCHITECTURE)
DERIVED_DATA := .build/DerivedData
APP := $(DERIVED_DATA)/Build/Products/Debug/Charbon.app
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release/Charbon.app
INSTALL_DIR := /Applications
VERSION := $(shell awk '$$1 == "MARKETING_VERSION:" { print $$2; exit }' project.yml)
BUILD_NUMBER := $(shell awk '$$1 == "CURRENT_PROJECT_VERSION:" { print $$2; exit }' project.yml)

bootstrap:
	brew bundle
	$(MAKE) generate

generate:
	xcodegen generate

format:
	swift-format format --in-place Package.swift
	swift-format format --in-place --recursive Sources Tests

format-check:
	swift-format lint --strict Package.swift
	swift-format lint --strict --recursive Sources Tests

lint:
	$(MAKE) format-check
	swiftlint lint --strict

build: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		build

test:
	swift test --parallel

test-app: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		-only-testing:CharbonAppTests \
		test

verify: lint test test-app

lint-workflows:
	actionlint
	shellcheck Scripts/release/*.sh

# Runs the whole release pipeline locally, signed ad hoc and without notarization.
release-dry-run: generate
	Scripts/release/preflight.sh v$(VERSION)
	ALLOW_ADHOC_SIGNING=1 SIGNING_IDENTITY=- \
		Scripts/release/build-app.sh $(VERSION) $(BUILD_NUMBER)
	ALLOW_ADHOC_SIGNING=1 SIGNING_IDENTITY=- \
		Scripts/release/make-dmg.sh $(VERSION)
	Scripts/release/package-release.sh $(VERSION)
	ALLOW_ADHOC_SIGNING=1 ALLOW_UNNOTARIZED=1 \
		Scripts/release/verify-distribution.sh \
		.build/release/dist/Charbon-$(VERSION).dmg $(VERSION) $(BUILD_NUMBER)

ci: verify lint-workflows release-dry-run

# Builds without a team, signs ad hoc and launches the app from the build folder.
run: build
	codesign --force --deep -s - $(APP)
	open $(APP)

release: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		build
	codesign --force --deep -s - $(RELEASE_APP)

# Builds the Release app, signs it ad hoc and copies it to /Applications.
install: release
	-pkill -x Charbon
	rm -rf $(INSTALL_DIR)/Charbon.app
	cp -R $(RELEASE_APP) $(INSTALL_DIR)/Charbon.app
	@echo "Installed. Open it with: open $(INSTALL_DIR)/Charbon.app"

open: generate
	open $(PROJECT)

clean: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-derivedDataPath $(DERIVED_DATA) \
		clean
