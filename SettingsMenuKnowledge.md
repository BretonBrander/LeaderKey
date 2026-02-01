# Settings Menu Knowledge Guide (macOS + Swift/Xcode)

## How to use this guide
This is a **menu of optional patterns** for macOS settings windows. Nothing here is mandatory. Use a section only **if your app needs that capability**. For example, if your app doesn’t use a global shortcut, you can skip the shortcut recorder section entirely. The goal is to provide implementation-ready recipes you can selectively apply.

## Table of contents
1. [Purpose](#purpose)
2. [Multi-section settings window (General + Advanced)](#1-multi-section-settings-window-general--advanced)
3. [Keyboard shortcut recorder (optional)](#2-keyboard-shortcut-recorder)
4. [Theme picker + optional custom colors](#3-theme-picker--optional-custom-colors)
5. [Launch at login (optional)](#4-launch-at-login)
6. [Config/file location picker (optional)](#5-configfile-location-picker)
7. [Advanced modifier/behavior configuration (optional)](#6-advanced-modifierbehavior-configuration)
8. [Cheatsheet/help overlay controls (optional)](#7-cheatsheet--help-overlay-controls)
9. [Activation behavior for global shortcut apps (optional)](#8-activation-behavior-for-global-shortcut-apps)
10. [Display target (multi-monitor apps only)](#9-display-target-multi-monitor-apps)
11. [Inline validation banner (optional)](#10-inline-validation-banner)
12. [Entry points to settings (optional)](#11-entry-points-to-settings-macos)
13. [Settings window visibility policy (optional)](#12-settings-window-visibility-policy)
14. [Feature-to-component mapping](#feature-to-component-mapping-quick-reference)
15. [Adaptation checklist](#adaptation-checklist)

---

## Purpose
This guide is a technical reference for building a macOS settings window in Swift using Xcode. It focuses on implementation-ready patterns and code snippets that you can adapt to your own app without forcing a specific visual layout.

---

## 1) Multi-Section Settings Window (General + Advanced)
**Use this only if your app needs multiple groups of settings.** A multi-pane window is useful when you want a clean primary surface plus deeper controls for power users.

### SwiftUI macOS example
```swift
import SwiftUI

struct SettingsWindow: View {
  enum Pane: Hashable { case general, advanced }
  @State private var selection: Pane = .general

  var body: some View {
    VStack(spacing: 12) {
      Picker("", selection: $selection) {
        Text("General").tag(Pane.general)
        Text("Advanced").tag(Pane.advanced)
      }
      .pickerStyle(.segmented)

      Divider()

      switch selection {
      case .general:
        GeneralSettingsView()
      case .advanced:
        AdvancedSettingsView()
      }
    }
    .padding(16)
    .frame(minWidth: 640, minHeight: 480)
  }
}
```

### AppKit window wiring (NSWindowController)
```swift
import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
  init() {
    let rootView = SettingsWindow()
    let hosting = NSHostingController(rootView: rootView)

    let window = NSWindow(contentViewController: hosting)
    window.title = "Settings"
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.setContentSize(NSSize(width: 720, height: 560))

    super.init(window: window)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
```

---

## 2) Keyboard Shortcut Recorder
**Only include this if your app is launched or controlled by a shortcut.** Use a dedicated recorder control for global shortcuts.

### SwiftUI placeholder interface
```swift
struct ShortcutRecorder: View {
  @Binding var shortcut: String?

  var body: some View {
    HStack {
      Text(shortcut ?? "None")
      Button("Record") { /* capture shortcut */ }
      Button("Clear") { shortcut = nil }
    }
  }
}
```

### Usage inside a settings section
```swift
struct GeneralSettingsView: View {
  @State private var shortcut: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Shortcut").font(.headline)
      ShortcutRecorder(shortcut: $shortcut)
    }
  }
}
```

---

## 3) Theme Picker + Optional Custom Colors
**Only include this if your app supports multiple themes or color customization.**

```swift
struct ThemeSettingsView: View {
  enum Theme: String, CaseIterable { case system, dark, light }

  @State private var theme: Theme = .system
  @State private var useCustomColors = false
  @State private var background = NSColor.windowBackgroundColor
  @State private var accent = NSColor.controlAccentColor

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Theme").font(.headline)

      Picker("Theme", selection: $theme) {
        ForEach(Theme.allCases, id: \.self) { theme in
          Text(theme.rawValue.capitalized).tag(theme)
        }
      }
      .frame(width: 200)

      Toggle("Enable custom colors", isOn: $useCustomColors)

      if useCustomColors {
        ColorPicker("Background", selection: Binding(
          get: { Color(background) },
          set: { background = NSColor($0) }
        ))
        ColorPicker("Accent", selection: Binding(
          get: { Color(accent) },
          set: { accent = NSColor($0) }
        ))

        Button("Reset") {
          background = .windowBackgroundColor
          accent = .controlAccentColor
        }
      }
    }
  }
}
```

---

## 4) Launch at Login
**Only include this if your app should run automatically on startup.**

```swift
struct LaunchAtLoginView: View {
  @State private var launchAtLogin = false

  var body: some View {
    Toggle("Launch at login", isOn: $launchAtLogin)
      .onChange(of: launchAtLogin) { newValue in
        // SMAppService.mainApp.register()/unregister()
      }
  }
}
```

---

## 5) Config/File Location Picker
**Only include this if users can edit or relocate a config file.**

```swift
struct ConfigLocationView: View {
  @State private var path = "~/Library/Application Support/MyApp/config.json"

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Config Location").font(.headline)
      Text(path).lineLimit(1).truncationMode(.middle)

      HStack {
        Button("Choose…") {
          let panel = NSOpenPanel()
          panel.canChooseFiles = true
          panel.canChooseDirectories = false
          if panel.runModal() == .OK, let url = panel.url {
            path = url.path
          }
        }
        Button("Reveal") {
          NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        }
        Button("Reset") {
          path = "~/Library/Application Support/MyApp/config.json"
        }
      }
    }
  }
}
```

---

## 6) Advanced Modifier/Behavior Configuration
**Only include this if your app supports modifier-driven or sticky behaviors.**

```swift
struct ModifierBehaviorView: View {
  enum ModifierBehavior: String, CaseIterable { case hold, sticky, disabled }
  @State private var behavior: ModifierBehavior = .hold

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Modifier Keys").font(.headline)

      Picker("Behavior", selection: $behavior) {
        ForEach(ModifierBehavior.allCases, id: \.self) { item in
          Text(item.rawValue.capitalized).tag(item)
        }
      }
      .frame(width: 240)

      Text("Explain how the modifier affects grouped actions or persistent UI state.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}
```

---

## 7) Cheatsheet / Help Overlay Controls
**Only include this if your app has a cheat sheet or help overlay.**

```swift
struct CheatsheetSettingsView: View {
  enum Mode: String, CaseIterable { case always, delay, never }
  @State private var mode: Mode = .always
  @State private var delayMS: Int = 500
  @State private var showIcons = true
  @State private var showDetails = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Cheatsheet").font(.headline)

      Picker("Show", selection: $mode) {
        ForEach(Mode.allCases, id: \.self) { item in
          Text(item.rawValue.capitalized).tag(item)
        }
      }
      .frame(width: 160)

      if mode == .delay {
        HStack(spacing: 8) {
          TextField("Delay", value: $delayMS, format: .number)
            .frame(width: 60)
          Text("ms")
        }
      }

      Toggle("Show icons", isOn: $showIcons)
      Toggle("Show details", isOn: $showDetails)
    }
  }
}
```

---

## 8) Activation Behavior for Global Shortcut Apps
**Only include this if your app is activated by a global shortcut.**

```swift
struct ActivationBehaviorView: View {
  enum Behavior: String, CaseIterable { case hide, reset, nothing }
  @State private var behavior: Behavior = .hide

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Activation").font(.headline)

      Picker("When re-activated", selection: $behavior) {
        ForEach(Behavior.allCases, id: \.self) { item in
          Text(item.rawValue.capitalized).tag(item)
        }
      }
      .frame(width: 240)
    }
  }
}
```

---

## 9) Display Target (Multi-Monitor Apps)
**Only include this if the app can appear on multiple screens.**

```swift
struct DisplayTargetView: View {
  enum DisplayTarget: String, CaseIterable {
    case primary, screenWithMouse, activeWindow
  }
  @State private var target: DisplayTarget = .primary

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Show on").font(.headline)

      Picker("Display", selection: $target) {
        Text("Primary screen").tag(DisplayTarget.primary)
        Text("Screen with mouse").tag(DisplayTarget.screenWithMouse)
        Text("Active window screen").tag(DisplayTarget.activeWindow)
      }
      .frame(width: 220)
    }
  }
}
```

---

## 10) Inline Validation Banner
**Only include this if the settings UI can surface validation errors.**

```swift
struct ValidationBanner: View {
  let errors: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Configuration has issues")
        .font(.headline)
      ForEach(errors.prefix(3), id: \.self) { error in
        Text("• \(error)")
          .font(.caption)
      }
      if errors.count > 3 {
        Text("• …and \(errors.count - 3) more")
          .font(.caption)
      }
    }
    .padding(8)
    .background(Color.red.opacity(0.1))
    .cornerRadius(8)
  }
}
```

---

## 11) Entry Points to Settings (macOS)
**Only include the entry points that make sense for your app.**

### Main menu and status item
```swift
// App menu
let settingsItem = NSMenuItem(
  title: "Settings…",
  action: #selector(openSettings),
  keyEquivalent: ","
)
settingsItem.target = self

// Status item menu
let statusSettingsItem = NSMenuItem(
  title: "Settings…",
  action: #selector(openSettings),
  keyEquivalent: ","
)
statusSettingsItem.target = self
```

### URL scheme (optional)
```swift
func application(_ application: NSApplication, open urls: [URL]) {
  for url in urls where url.absoluteString == "myapp://settings" {
    openSettings()
  }
}
```

---

## 12) Settings Window Visibility Policy
**Only include this if your app normally runs as a background/menu bar app.**

```swift
func openSettings() {
  NSApp.setActivationPolicy(.regular)
  settingsWindowController.showWindow(nil)
  NSApp.activate(ignoringOtherApps: true)
}

func settingsWindowDidClose() {
  NSApp.setActivationPolicy(.accessory)
}
```

---

## Feature-to-Component Mapping (Quick Reference)
Use this as a pick-list, not a checklist.

| Feature | SwiftUI / AppKit Control | Notes |
| --- | --- | --- |
| Keyboard shortcut | Custom recorder view | Requires event capture or library |
| Launch at login | Toggle + SMAppService | macOS login items |
| Theme selection | Picker | Keep options short |
| Custom colors | Toggle + ColorPicker | Include reset button |
| Config location | NSOpenPanel + NSWorkspace | Add reveal + reset |
| Cheatsheet options | Picker + Toggle | Keep related controls together |
| Activation behavior | Picker | Explain effect in UI copy |
| Display target | Picker | Useful for multi-monitor setups |

---

## Adaptation Checklist
- [ ] Identify core settings for the default pane.
- [ ] Group power-user settings into Advanced (if you have them).
- [ ] Add macOS entry points that fit your app (menu bar + main menu + optional URL scheme).
- [ ] Provide inline validation for settings that can break behavior.
- [ ] Keep settings reversible (reset buttons where needed).

This document is intentionally implementation-focused for Swift/Xcode macOS projects. Copy the snippets you need and adapt them to your architecture.
