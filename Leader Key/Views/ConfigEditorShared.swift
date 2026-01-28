import AppKit
import ObjectiveC

enum ConfigEditorUI {
  static func setButtonTitle(_ button: NSButton, text: String, placeholder: Bool) {
    let attr = NSMutableAttributedString(string: text)
    let color: NSColor = placeholder ? .secondaryLabelColor : .labelColor
    attr.addAttribute(
      .foregroundColor, value: color, range: NSRange(location: 0, length: attr.length))
    button.title = text
    button.attributedTitle = attr
  }

  /// Unified context menu that handles both single-item and multi-select scenarios.
  /// Eliminates duplicate if/else branching in cell views.
  static func presentContextualMenu(
    anchor: NSView?,
    selectedCount: Int,
    openWithCount: Int,
    // Single-item callbacks
    onDuplicate: @escaping () -> Void,
    onDelete: @escaping () -> Void,
    onSetOpenWith: (() -> Void)? = nil,
    onClearOpenWith: (() -> Void)? = nil,
    // Bulk callbacks
    onBulkDelete: @escaping () -> Void,
    onBulkSetOpenWith: (() -> Void)?,
    onBulkSetAppIcon: @escaping () -> Void,
    onBulkSetSymbol: @escaping () -> Void,
    onBulkClearIcon: @escaping () -> Void
  ) {
    if selectedCount > 1 {
      presentBulkMoreMenu(
        anchor: anchor,
        count: selectedCount,
        openWithCount: openWithCount,
        onBulkSetOpenWith: openWithCount > 0 ? onBulkSetOpenWith : nil,
        onBulkSetAppIcon: onBulkSetAppIcon,
        onBulkSetSymbol: onBulkSetSymbol,
        onBulkClearIcon: onBulkClearIcon,
        onBulkDelete: onBulkDelete
      )
    } else {
      presentMoreMenu(
        anchor: anchor,
        onSetOpenWith: onSetOpenWith,
        onClearOpenWith: onClearOpenWith,
        onDuplicate: onDuplicate,
        onDelete: onDelete
      )
    }
  }

  static func presentMoreMenu(
    anchor: NSView?,
    onSetOpenWith: (() -> Void)? = nil,
    onClearOpenWith: (() -> Void)? = nil,
    onDuplicate: @escaping () -> Void,
    onDelete: @escaping () -> Void
  ) {
    guard let anchor else { return }
    let menu = NSMenu()

    // Add Open With options if provided
    if onSetOpenWith != nil {
      menu.addItem(
        withTitle: "Set Open With App…",
        action: #selector(MenuHandler.setOpenWith),
        keyEquivalent: ""
      )
      if onClearOpenWith != nil {
        menu.addItem(
          withTitle: "Clear Open With",
          action: #selector(MenuHandler.clearOpenWith),
          keyEquivalent: ""
        )
      }
      menu.addItem(NSMenuItem.separator())
    }

    menu.addItem(
      withTitle: "Duplicate",
      action: #selector(MenuHandler.duplicate),
      keyEquivalent: ""
    )
    menu.addItem(
      withTitle: "Delete",
      action: #selector(MenuHandler.delete),
      keyEquivalent: ""
    )
    let handler = MenuHandler(
      onSetOpenWith: onSetOpenWith,
      onClearOpenWith: onClearOpenWith,
      onDuplicate: onDuplicate,
      onDelete: onDelete
    )
    for item in menu.items { item.target = handler }
    objc_setAssociatedObject(
      menu,
      &handlerAssociationKey,
      handler,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
    let point = NSPoint(x: 0, y: anchor.bounds.height)
    menu.popUp(positioning: nil, at: point, in: anchor)
  }

  /// Presents a menu for bulk operations on multiple selected items
  static func presentBulkMoreMenu(
    anchor: NSView?,
    count: Int,
    openWithCount: Int,
    onBulkSetOpenWith: (() -> Void)?,
    onBulkSetAppIcon: @escaping () -> Void,
    onBulkSetSymbol: @escaping () -> Void,
    onBulkClearIcon: @escaping () -> Void,
    onBulkDelete: @escaping () -> Void
  ) {
    guard let anchor else { return }
    let menu = NSMenu()

    // Icon submenu
    let iconMenu = NSMenu()
    iconMenu.addItem(
      withTitle: "App Icon…",
      action: #selector(MenuHandler.bulkSetAppIcon),
      keyEquivalent: ""
    )
    iconMenu.addItem(
      withTitle: "Symbol…",
      action: #selector(MenuHandler.bulkSetSymbol),
      keyEquivalent: ""
    )
    iconMenu.addItem(NSMenuItem.separator())
    iconMenu.addItem(
      withTitle: "Clear Icons",
      action: #selector(MenuHandler.bulkClearIcon),
      keyEquivalent: ""
    )

    let iconItem = NSMenuItem(title: "Set Icon for \(count) Items", action: nil, keyEquivalent: "")
    iconItem.submenu = iconMenu
    menu.addItem(iconItem)

    // Add bulk Open With option if any selected items support it
    if onBulkSetOpenWith != nil, openWithCount > 0 {
      let title = openWithCount == count
        ? "Set Open With App for \(count) Items…"
        : "Set Open With App for \(openWithCount) of \(count) Items…"
      menu.addItem(
        withTitle: title,
        action: #selector(MenuHandler.bulkSetOpenWith),
        keyEquivalent: ""
      )
    }

    menu.addItem(NSMenuItem.separator())

    menu.addItem(
      withTitle: "Delete \(count) Items",
      action: #selector(MenuHandler.bulkDelete),
      keyEquivalent: ""
    )

    let handler = MenuHandler(
      onBulkSetOpenWith: onBulkSetOpenWith,
      onBulkSetAppIcon: onBulkSetAppIcon,
      onBulkSetSymbol: onBulkSetSymbol,
      onBulkClearIcon: onBulkClearIcon,
      onBulkDelete: onBulkDelete
    )
    for item in menu.items { item.target = handler }
    for item in iconMenu.items { item.target = handler }
    objc_setAssociatedObject(
      menu,
      &handlerAssociationKey,
      handler,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
    let point = NSPoint(x: 0, y: anchor.bounds.height)
    menu.popUp(positioning: nil, at: point, in: anchor)
  }

  static func presentIconMenu(
    anchor: NSView?,
    onPickAppIcon: @escaping () -> Void,
    onPickSymbol: @escaping () -> Void,
    onClear: @escaping () -> Void
  ) {
    guard let anchor else { return }
    let menu = NSMenu()
    menu.addItem(
      withTitle: "App Icon…",
      action: #selector(MenuHandler.pickAppIcon),
      keyEquivalent: ""
    )
    menu.addItem(
      withTitle: "Symbol…",
      action: #selector(MenuHandler.pickSymbol),
      keyEquivalent: ""
    )
    menu.addItem(NSMenuItem.separator())
    menu.addItem(withTitle: "Clear", action: #selector(MenuHandler.clearIcon), keyEquivalent: "")
    let handler = MenuHandler(
      onPickAppIcon: onPickAppIcon,
      onPickSymbol: onPickSymbol,
      onClearIcon: onClear
    )
    for item in menu.items { item.target = handler }
    objc_setAssociatedObject(
      menu,
      &handlerAssociationKey,
      handler,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
    let point = NSPoint(x: 0, y: anchor.bounds.height)
    menu.popUp(positioning: nil, at: point, in: anchor)
  }

  private static var handlerAssociationKey: UInt8 = 0

  /// Menu handler using action dictionary pattern for cleaner code.
  private final class MenuHandler: NSObject {
    private enum Action: String {
      case pickAppIcon, pickSymbol, clearIcon
      case setOpenWith, clearOpenWith
      case duplicate, delete
      case bulkSetOpenWith, bulkSetAppIcon, bulkSetSymbol, bulkClearIcon, bulkDelete
    }

    private var actions: [Action: () -> Void] = [:]

    private func register(_ action: Action, handler: @escaping () -> Void) {
      actions[action] = handler
    }

    convenience init(
      onPickAppIcon: (() -> Void)? = nil,
      onPickSymbol: (() -> Void)? = nil,
      onClearIcon: (() -> Void)? = nil,
      onSetOpenWith: (() -> Void)? = nil,
      onClearOpenWith: (() -> Void)? = nil,
      onDuplicate: (() -> Void)? = nil,
      onDelete: (() -> Void)? = nil,
      onBulkSetOpenWith: (() -> Void)? = nil,
      onBulkSetAppIcon: (() -> Void)? = nil,
      onBulkSetSymbol: (() -> Void)? = nil,
      onBulkClearIcon: (() -> Void)? = nil,
      onBulkDelete: (() -> Void)? = nil
    ) {
      self.init()
      if let h = onPickAppIcon { register(.pickAppIcon, handler: h) }
      if let h = onPickSymbol { register(.pickSymbol, handler: h) }
      if let h = onClearIcon { register(.clearIcon, handler: h) }
      if let h = onSetOpenWith { register(.setOpenWith, handler: h) }
      if let h = onClearOpenWith { register(.clearOpenWith, handler: h) }
      if let h = onDuplicate { register(.duplicate, handler: h) }
      if let h = onDelete { register(.delete, handler: h) }
      if let h = onBulkSetOpenWith { register(.bulkSetOpenWith, handler: h) }
      if let h = onBulkSetAppIcon { register(.bulkSetAppIcon, handler: h) }
      if let h = onBulkSetSymbol { register(.bulkSetSymbol, handler: h) }
      if let h = onBulkClearIcon { register(.bulkClearIcon, handler: h) }
      if let h = onBulkDelete { register(.bulkDelete, handler: h) }
    }

    @objc func pickAppIcon() { actions[.pickAppIcon]?() }
    @objc func pickSymbol() { actions[.pickSymbol]?() }
    @objc func clearIcon() { actions[.clearIcon]?() }
    @objc func setOpenWith() { actions[.setOpenWith]?() }
    @objc func clearOpenWith() { actions[.clearOpenWith]?() }
    @objc func duplicate() { actions[.duplicate]?() }
    @objc func delete() { actions[.delete]?() }
    @objc func bulkSetOpenWith() { actions[.bulkSetOpenWith]?() }
    @objc func bulkSetAppIcon() { actions[.bulkSetAppIcon]?() }
    @objc func bulkSetSymbol() { actions[.bulkSetSymbol]?() }
    @objc func bulkClearIcon() { actions[.bulkClearIcon]?() }
    @objc func bulkDelete() { actions[.bulkDelete]?() }
  }
}

extension Action {
  func resolvedIcon() -> NSImage? {
    if let iconPath = iconPath, !iconPath.isEmpty {
      if iconPath.hasSuffix(".app") { return NSWorkspace.shared.icon(forFile: iconPath) }
      if let img = NSImage(systemSymbolName: iconPath, accessibilityDescription: nil) { return img }
    }
    switch type {
    case .application:
      return NSWorkspace.shared.icon(forFile: value)
    case .url:
      return NSImage(systemSymbolName: "link", accessibilityDescription: nil)
    case .command:
      return NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
    case .folder:
      return NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
    default:
      return NSImage(systemSymbolName: "questionmark", accessibilityDescription: nil)
    }
  }
}

extension Group {
  func resolvedIcon() -> NSImage? {
    if let iconPath = iconPath, !iconPath.isEmpty {
      if iconPath.hasSuffix(".app") { return NSWorkspace.shared.icon(forFile: iconPath) }
      if let img = NSImage(systemSymbolName: iconPath, accessibilityDescription: nil) { return img }
    }
    return NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
  }
}
