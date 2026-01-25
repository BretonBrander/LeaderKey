import Foundation

// MARK: - Encoding Helpers

/// Converts a key to its textual representation for JSON encoding
private func textualKey(for key: String?) -> String? {
  guard let k = key else { return nil }
  return KeyMaps.text(for: k) ?? k
}

// MARK: - Action Types

enum Type: String, Codable {
  case group
  case application
  case url
  case command
  case folder
  case file
  case script
}

// MARK: - Script Arguments

struct ScriptArgument: Codable, Equatable {
  var name: String
  var defaultValue: String?

  init(name: String, defaultValue: String? = nil) {
    self.name = name
    self.defaultValue = defaultValue
  }
}

// MARK: - Item Protocol

protocol Item {
  var key: String? { get }
  var type: Type { get }
  var label: String? { get }
  var displayName: String { get }
  var iconPath: String? { get set }
}

// MARK: - Action

struct Action: Item, Codable, Equatable {
  // UI-only stable identity. Not persisted to JSON.
  var uiid: UUID = UUID()

  var key: String?
  var type: Type
  var label: String?
  var value: String
  var iconPath: String?
  var openWith: String?  // Optional app path to open folder/URL with instead of default
  var arguments: [ScriptArgument]?  // Arguments for script type actions

  var displayName: String {
    guard let labelValue = label else { return bestGuessDisplayName }
    guard !labelValue.isEmpty else { return bestGuessDisplayName }
    return labelValue
  }

  var bestGuessDisplayName: String {
    switch type {
    case .application:
      return (value as NSString).lastPathComponent.replacingOccurrences(
        of: ".app", with: "")
    case .command:
      return value.components(separatedBy: " ").first ?? value
    case .folder:
      return (value as NSString).lastPathComponent
    case .file:
      return (value as NSString).lastPathComponent
    case .script:
      return (value as NSString).lastPathComponent.replacingOccurrences(
        of: ".sh", with: "")
    case .url:
      return "URL"
    default:
      return value
    }
  }

  private enum CodingKeys: String, CodingKey {
    case key, type, label, value, iconPath, openWith, arguments
  }

  init(
    uiid: UUID = UUID(), key: String?, type: Type, label: String? = nil, value: String,
    iconPath: String? = nil, openWith: String? = nil, arguments: [ScriptArgument]? = nil
  ) {
    self.uiid = uiid
    self.key = key
    self.type = type
    self.label = label
    self.value = value
    self.iconPath = iconPath
    self.openWith = openWith
    self.arguments = arguments
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.uiid = UUID()
    self.key = try c.decodeIfPresent(String.self, forKey: .key)
    self.type = try c.decode(Type.self, forKey: .type)
    self.label = try c.decodeIfPresent(String.self, forKey: .label)
    self.value = try c.decode(String.self, forKey: .value)
    self.iconPath = try c.decodeIfPresent(String.self, forKey: .iconPath)
    self.openWith = try c.decodeIfPresent(String.self, forKey: .openWith)
    self.arguments = try c.decodeIfPresent([ScriptArgument].self, forKey: .arguments)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(textualKey(for: key), forKey: .key)
    try c.encode(type, forKey: .type)
    try c.encode(value, forKey: .value)
    if let l = label, !l.isEmpty { try c.encode(l, forKey: .label) }
    try c.encodeIfPresent(iconPath, forKey: .iconPath)
    try c.encodeIfPresent(openWith, forKey: .openWith)
    if let args = arguments, !args.isEmpty { try c.encode(args, forKey: .arguments) }
  }
}

// MARK: - Group

struct Group: Item, Codable, Equatable {
  // UI-only stable identity. Not persisted to JSON.
  var uiid: UUID = UUID()

  var key: String?
  var type: Type = .group
  var label: String?
  var iconPath: String?
  var actions: [ActionOrGroup]

  var displayName: String {
    guard let labelValue = label else { return "Group" }
    if labelValue.isEmpty { return "Group" }
    return labelValue
  }

  static func == (lhs: Group, rhs: Group) -> Bool {
    return lhs.key == rhs.key && lhs.type == rhs.type && lhs.label == rhs.label
      && lhs.iconPath == rhs.iconPath && lhs.actions == rhs.actions
  }

  private enum CodingKeys: String, CodingKey {
    case key, type, label, iconPath, actions
  }

  init(
    uiid: UUID = UUID(), key: String?, type: Type = .group, label: String? = nil,
    iconPath: String? = nil, actions: [ActionOrGroup]
  ) {
    self.uiid = uiid
    self.key = key
    self.type = type
    self.label = label
    self.iconPath = iconPath
    self.actions = actions
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.uiid = UUID()
    self.key = try c.decodeIfPresent(String.self, forKey: .key)
    self.type = .group
    self.label = try c.decodeIfPresent(String.self, forKey: .label)
    self.iconPath = try c.decodeIfPresent(String.self, forKey: .iconPath)
    self.actions = try c.decode([ActionOrGroup].self, forKey: .actions)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(textualKey(for: key), forKey: .key)
    try c.encode(Type.group, forKey: .type)
    try c.encode(actions, forKey: .actions)
    if let l = label, !l.isEmpty { try c.encode(l, forKey: .label) }
    try c.encodeIfPresent(iconPath, forKey: .iconPath)
  }
}

// MARK: - ActionOrGroup (discriminated union)

enum ActionOrGroup: Codable, Equatable {
  case action(Action)
  case group(Group)

  var item: Item {
    switch self {
    case .group(let group): return group
    case .action(let action): return action
    }
  }

  var uiid: UUID {
    switch self {
    case .action(let a): return a.uiid
    case .group(let g): return g.uiid
    }
  }

  private enum CodingKeys: String, CodingKey {
    case key, type, value, actions, label, iconPath, openWith, arguments
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let key = try container.decode(String?.self, forKey: .key)
    let type = try container.decode(Type.self, forKey: .type)
    let label = try container.decodeIfPresent(String.self, forKey: .label)
    let iconPath = try container.decodeIfPresent(String.self, forKey: .iconPath)

    switch type {
    case .group:
      let actions = try container.decode([ActionOrGroup].self, forKey: .actions)
      self = .group(Group(key: key, label: label, iconPath: iconPath, actions: actions))
    default:
      let value = try container.decode(String.self, forKey: .value)
      let openWith = try container.decodeIfPresent(String.self, forKey: .openWith)
      let arguments = try container.decodeIfPresent([ScriptArgument].self, forKey: .arguments)
      self = .action(
        Action(
          key: key, type: type, label: label, value: value, iconPath: iconPath,
          openWith: openWith, arguments: arguments))
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .action(let action):
      try container.encodeIfPresent(textualKey(for: action.key), forKey: .key)
      try container.encode(action.type, forKey: .type)
      try container.encode(action.value, forKey: .value)
      if let l = action.label, !l.isEmpty { try container.encode(l, forKey: .label) }
      try container.encodeIfPresent(action.iconPath, forKey: .iconPath)
      try container.encodeIfPresent(action.openWith, forKey: .openWith)
      if let args = action.arguments, !args.isEmpty { try container.encode(args, forKey: .arguments) }
    case .group(let group):
      try container.encodeIfPresent(textualKey(for: group.key), forKey: .key)
      try container.encode(Type.group, forKey: .type)
      try container.encode(group.actions, forKey: .actions)
      if let l = group.label, !l.isEmpty { try container.encode(l, forKey: .label) }
      try container.encodeIfPresent(group.iconPath, forKey: .iconPath)
    }
  }
}

// MARK: - Default Configuration

let emptyRoot = Group(key: "🚫", label: "Config error", actions: [])

let defaultConfig = """
  {
      "type": "group",
      "actions": [
          { "key": "t", "type": "application", "value": "/System/Applications/Utilities/Terminal.app" },
          { "key": ",", "type": "url", "value": "leaderkey://settings", "label": "Leader Key Settings" },
          {
              "key": "o",
              "type": "group",
              "actions": [
                  { "key": "s", "type": "application", "value": "/Applications/Safari.app" },
                  { "key": "e", "type": "application", "value": "/Applications/Mail.app" },
                  { "key": "i", "type": "application", "value": "/System/Applications/Music.app" },
                  { "key": "m", "type": "application", "value": "/Applications/Messages.app" }
              ]
          },
          {
              "key": "r",
              "type": "group",
              "actions": [
                  { "key": "e", "type": "url", "value": "raycast://extensions/raycast/emoji-symbols/search-emoji-symbols" },
                  { "key": "p", "type": "url", "value": "raycast://confetti" },
                  { "key": "c", "type": "url", "value": "raycast://extensions/raycast/system/open-camera" }
              ]
          }
      ]
  }
  """

