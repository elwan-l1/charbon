.PHONY: bootstrap generate format format-check lint build test test-app verify run open clean

PROJECT := Charbon.xcodeproj
SCHEME := Charbon
ARCHITECTURE := $(shell uname -m)
DESTINATION := platform=macOS,arch=$(ARCHITECTURE)
DERIVED_DATA := .build/DerivedData
APP := $(DERIVED_DATA)/Build/Products/Debug/Charbon.app

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

# Builds without a team, signs ad hoc and launches the app from the build folder.
run: build
	codesign --force --deep -s - $(APP)
	open $(APP)

open: generate
	open $(PROJECT)

clean: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-derivedDataPath $(DERIVED_DATA) \
		clean
