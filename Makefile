# Makefile for Flow Demo App
# Build the FlowDemo macOS application

BUILD_DIR = $(CURDIR)/build
APP_PATH = $(BUILD_DIR)/Debug/FlowDemo.app

.PHONY: all build clean run help

# Default target
all: build

# Build the demo app for macOS (Debug configuration, universal binary)
build:
	@echo "Building FlowDemo for macOS (Debug, universal)..."
	xcodebuild build \
		-project Demo/FlowDemo.xcodeproj \
		-scheme FlowDemo \
		-configuration Debug \
		-destination "generic/platform=macOS" \
		SYMROOT="$(BUILD_DIR)" \
		OBJROOT="$(BUILD_DIR)/Intermediates"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf "$(BUILD_DIR)"

# Run the built app
run: build
	@echo "Running FlowDemo..."
	@open "$(APP_PATH)"

# Show available targets
help:
	@echo "Flow Demo App - Available Make Targets:"
	@echo ""
	@echo "  make build    - Build the FlowDemo app for macOS (Debug, universal)"
	@echo "  make run      - Build and run the FlowDemo app"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make help     - Show this help message"
	@echo ""
	@echo "Default target: build"
	@echo "Build output: $(BUILD_DIR)"
