---
name: leaderkey-unit-tests
description: Guide for writing, running, and maintaining XCTest unit tests for the Leader Key macOS app, including Xcode scheme/test plan settings, test target build settings, defaults isolation, and common test patterns. Use when adding or updating tests, debugging test failures, or reviewing test configuration in this repo.
---

# Leader Key Unit Tests

## Overview
Use this skill to add, run, or troubleshoot XCTest unit tests in Leader Key with the correct project settings and local test patterns.

## Quick Start
- Run all tests: `xcodebuild -scheme "Leader Key" -testPlan "TestPlan" test`
- Run a single test: `xcodebuild -scheme "Leader Key" -testPlan "TestPlan" -only-testing:Leader KeyTests/UserConfigTests/testInitializesWithDefaults test`
- Build: `xcodebuild -scheme "Leader Key" -configuration Debug build`

## Test Layout
- Place unit tests in `Leader KeyTests/`.
- Use `@testable import Leader_Key` (module name uses underscore).
- Follow file naming pattern `SomethingTests.swift` with `final class SomethingTests: XCTestCase`.

## Xcode Scheme and Test Plan
- Use scheme `Leader Key` at `Leader Key.xcodeproj/xcshareddata/xcschemes/Leader Key.xcscheme`.
- Use default test plan `Leader Key/Support/TestPlan.xctestplan`.
- Expect `testTimeoutsEnabled = true` in the test plan.
- Treat the `Leader Key.xctestplan` scheme reference as stale unless the file is added.
- Note the scheme lists `Leader KeyUITests`; confirm or add the UI test target before relying on it.

## Test Target Build Settings (Leader KeyTests)
- Locate target settings in `Leader Key.xcodeproj/project.pbxproj`.
- Use `BUNDLE_LOADER = $(TEST_HOST)` and `TEST_HOST = $(BUILT_PRODUCTS_DIR)/Leader Key.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Leader Key`.
- Expect bundle identifier `com.brnbw.Leader-KeyTests`.
- Target deployment is macOS 13.5.

## App Behavior Under Tests
- Use `AppDelegate.isRunningTests()` to detect `XCTestSessionIdentifier` and skip app boot in `applicationDidFinishLaunching`.
- Instantiate objects directly in unit tests instead of relying on full app launch.

## Defaults Isolation Pattern
- Rely on `Leader Key/Defaults.swift` to switch `defaultsSuite` to a random `UserDefaults` suite when `XCTestConfigurationFilePath` is set.
- Override `defaultsSuite` when a test needs explicit control, then restore it in `tearDown`.

```swift
override func setUp() {
  super.setUp()
  originalSuite = defaultsSuite
  defaultsSuite = UserDefaults(suiteName: UUID().uuidString)!
}

override func tearDown() {
  defaultsSuite = originalSuite
  super.tearDown()
}
```

## Filesystem Isolation Pattern
- Use a unique temp directory via `NSTemporaryDirectory()` and `UUID()` for tests that touch config files.
- Set `Defaults[.configDir]` to the temp path and remove it in `tearDown`.

## Alert Handling Pattern
- Implement `AlertHandler` in tests to capture alerts without showing UI.
- Use `TestAlertManager` in `Leader KeyTests/UserConfigTests.swift` as the model.

## Async Loading Pattern
- Wait for `UserConfig.ensureAndLoad()` to complete with an `XCTestExpectation` and a short `DispatchQueue.main.asyncAfter` delay (see `waitForConfigLoad()` in `Leader KeyTests/UserConfigTests.swift`).

## Common Test Themes
- Validate config structure and errors in `Leader KeyTests/ConfigValidatorTests.swift` using inline `Group` and `Action` builders.
- Validate keyboard layout behavior in `Leader KeyTests/KeyboardLayoutTests.swift` using `NSEvent.keyEvent` and `Controller.charForEvent`.
- Validate URL parsing in `Leader KeyTests/URLSchemeTests.swift` with `URLSchemeHandler.parse`.
