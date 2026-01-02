import Cocoa
import Defaults
import SwiftUI

var defaultsSuite =
  ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
  ? UserDefaults(suiteName: UUID().uuidString)!
  : .standard

extension Defaults.Keys {
  static let configDir = Key<String>(
    "configDir", default: UserConfig.defaultDirectory(), suite: defaultsSuite)
  static let showMenuBarIcon = Key<Bool>(
    "showInMenubar", default: true, suite: defaultsSuite)
  static let forceEnglishKeyboardLayout = Key<Bool>(
    "forceEnglishKeyboardLayout", default: false, suite: defaultsSuite)
  static let modifierKeyConfiguration = Key<ModifierKeyConfig>(
    "modifierKeyConfiguration", default: .controlGroupOptionSticky, suite: defaultsSuite)
  static let theme = Key<Theme>(
    "theme", default: .mysteryBox, suite: defaultsSuite)
  // Storage key kept as "useCustomAccentColor" for backward compatibility
  static let useCustomColors = Key<Bool>(
    "useCustomAccentColor", default: false, suite: defaultsSuite)
  static let customAccentColor = Key<Data>(
    "customAccentColor", default: NSColor.controlAccentColor.archivedData, suite: defaultsSuite)
  static let customBackgroundColor = Key<Data>(
    "customBackgroundColor", default: NSColor.clear.archivedData, suite: defaultsSuite)

  static let autoOpenCheatsheet = Key<AutoOpenCheatsheetSetting>(
    "autoOpenCheatsheet",
    default: .delay, suite: defaultsSuite)
  static let cheatsheetDelayMS = Key<Int>(
    "cheatsheetDelayMS", default: 2000, suite: defaultsSuite)
  static let expandGroupsInCheatsheet = Key<Bool>(
    "expandGroupsInCheatsheet", default: false, suite: defaultsSuite)
  static let showAppIconsInCheatsheet = Key<Bool>(
    "showAppIconsInCheatsheet", default: true, suite: defaultsSuite)
  static let showDetailsInCheatsheet = Key<Bool>(
    "showDetailsInCheatsheet", default: true, suite: defaultsSuite)
  static let showFaviconsInCheatsheet = Key<Bool>(
    "showFaviconsInCheatsheet", default: true, suite: defaultsSuite)
  static let reactivateBehavior = Key<ReactivateBehavior>(
    "reactivateBehavior", default: .hide, suite: defaultsSuite)
  static let screen = Key<Screen>(
    "screen", default: .primary, suite: defaultsSuite)

  static let groupShortcuts = Key<Set<String>>(
    "groupShortcuts",
    default: Set(), suite: defaultsSuite)
}

enum AutoOpenCheatsheetSetting: String, Defaults.Serializable {
  case never
  case always
  case delay
}

enum ModifierKeyConfig: String, Codable, Defaults.Serializable, CaseIterable, Identifiable {
  case controlGroupOptionSticky
  case optionGroupControlSticky

  var id: Self { self }

  var description: String {
    switch self {
    case .controlGroupOptionSticky:
      return "⌃ Group sequences, ⌥ Sticky mode"
    case .optionGroupControlSticky:
      return "⌥ Group sequences, ⌃ Sticky mode"
    }
  }
}

enum ReactivateBehavior: String, Defaults.Serializable {
  case hide
  case reset
  case nothing
}

enum Screen: String, Defaults.Serializable {
  case primary
  case mouse
  case activeWindow
}

// MARK: - Custom Accent Color Helpers

extension NSColor {
  /// Archives the color to Data for storage (returns empty Data on failure)
  var archivedData: Data {
    (try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)) ?? Data()
  }

  /// Unarchives a color from Data
  static func fromArchivedData(_ data: Data) -> NSColor? {
    try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
  }
}

/// Returns the current accent color (custom if enabled, otherwise system accent)
func currentAccentColor() -> Color {
  if Defaults[.useCustomColors],
     let nsColor = NSColor.fromArchivedData(Defaults[.customAccentColor]) {
    return Color(nsColor)
  }
  return Color.accentColor
}

/// Returns the current background color (custom if enabled, otherwise nil/clear)
func currentBackgroundColor() -> Color? {
  if Defaults[.useCustomColors],
     let nsColor = NSColor.fromArchivedData(Defaults[.customBackgroundColor]),
     nsColor.alphaComponent > 0 {
    return Color(nsColor)
  }
  return nil
}
