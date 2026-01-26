import Cocoa
import Combine
import Defaults
import SwiftUI

enum KeyHelpers: UInt16 {
  case enter = 36
  case tab = 48
  case space = 49
  case backspace = 51
  case escape = 53
  case forwardDelete = 117
  case upArrow = 126
  case downArrow = 125
  case leftArrow = 123
  case rightArrow = 124
}

class Controller {
  var userState: UserState
  var userConfig: UserConfig

  var window: MainWindow!
  var cheatsheetWindow: NSWindow!
  private var cheatsheetTimer: Timer?

  private var cancellables = Set<AnyCancellable>()
  private(set) var isPerformingDeletion = false  // Flag to prevent window hiding during deletion

  init(userState: UserState, userConfig: UserConfig) {
    self.userState = userState
    self.userConfig = userConfig

    Task {
      for await value in Defaults.updates(.theme) {
        let windowClass = Theme.classFor(value)
        self.window = await windowClass.init(controller: self)
      }
    }

    Events.sink { event in
      switch event {
      case .didReload:
        // This should all be handled by the themes
        self.userState.isShowingRefreshState = true
        self.show()
        // Delay for 4 * 300ms to wait for animation to be noticeable
        delay(Int(Pulsate.singleDurationS * 1000) * 3) {
          self.hide()
          self.userState.isShowingRefreshState = false
        }
      default: break
      }
    }.store(in: &cancellables)

    // Set up tap handler for cheatsheet items
    userState.onItemTapped = { [weak self] item in
      self?.handleItemTapped(item)
    }

    self.cheatsheetWindow = Cheatsheet.createWindow(for: userState)
  }

  func show() {
    Events.send(.willActivate)
    userState.isWindowVisible = true

    let screen = Defaults[.screen].getNSScreen() ?? NSScreen()
    window.show(on: screen) {
      Events.send(.didActivate)
    }

    if !window.hasCheatsheet || userState.isShowingRefreshState {
      return
    }

    switch Defaults[.autoOpenCheatsheet] {
    case .always:
      showCheatsheet()
    case .delay:
      scheduleCheatsheet()
    default: break
    }
  }

  func hide(afterClose: (() -> Void)? = nil) {
    Events.send(.willDeactivate)
    userState.isWindowVisible = false

    window.hide {
      self.clear()
      afterClose?()
      Events.send(.didDeactivate)
    }

    cheatsheetWindow?.orderOut(nil)
    cheatsheetTimer?.invalidate()
  }

  func keyDown(with event: NSEvent) {
    // Reset the delay timer
    if Defaults[.autoOpenCheatsheet] == .delay {
      scheduleCheatsheet()
    }

    if event.modifierFlags.contains(.command) {
      switch event.charactersIgnoringModifiers {
      case ",":
        NSApp.sendAction(
          #selector(AppDelegate.settingsMenuItemActionHandler(_:)), to: nil,
          from: nil)
        hide()
        return
      case "w":
        hide()
        return
      case "q":
        NSApp.terminate(nil)
        return
      default:
        break
      }
    }

    switch event.keyCode {
    case KeyHelpers.backspace.rawValue:
      // Only clear if Command is not pressed (Command+Delete is for deletion)
      if !event.modifierFlags.contains(.command) {
        clear()
        delay(1) {
          self.positionCheatsheetWindow()
        }
      } else {
        // Command+Backspace: delete selected item
        deleteSelectedItem()
      }
    case KeyHelpers.forwardDelete.rawValue:
      // Delete key: delete selected item (with or without Command)
      deleteSelectedItem()
    case KeyHelpers.escape.rawValue:
      if userState.navigationPath.isEmpty {
        window.shouldHideImmediately = true
        window.resignKey()
      } else {
        goBack()
      }
    case KeyHelpers.downArrow.rawValue, KeyHelpers.space.rawValue:
      moveSelection(by: 1)
    case KeyHelpers.upArrow.rawValue:
      moveSelection(by: -1)
    case KeyHelpers.enter.rawValue:
      if userState.selectedIndex != nil {
        executeSelectedItem()
      }
    case KeyHelpers.rightArrow.rawValue:
      enterSelectedGroup()
    case KeyHelpers.leftArrow.rawValue:
      goBack()
    default:
      guard let char = charForEvent(event) else { return }
      handleKey(char, withModifiers: event.modifierFlags)
    }
  }

  func handleKey(_ key: String, withModifiers modifiers: NSEvent.ModifierFlags? = nil, execute: Bool = true) {
    if key == "?" {
      showCheatsheet()
      return
    }

    let list =
      (userState.currentGroup != nil)
      ? userState.currentGroup : userConfig.root

    let hit = list?.actions.first { item in
      switch item {
      case .group(let group):
        // Normalize both keys for comparison
        let groupKey = KeyMaps.glyph(for: group.key ?? "") ?? group.key ?? ""
        let inputKey = KeyMaps.glyph(for: key) ?? key
        if groupKey == inputKey {
          return true
        }
      case .action(let action):
        // Normalize both keys for comparison
        let actionKey = KeyMaps.glyph(for: action.key ?? "") ?? action.key ?? ""
        let inputKey = KeyMaps.glyph(for: key) ?? key
        if actionKey == inputKey {
          return true
        }
      }
      return false
    }

    switch hit {
    case .action(let action):
      if execute {
        if let mods = modifiers, isInStickyMode(mods) {
          runAction(action)
        } else {
          hide {
            self.runAction(action)
          }
        }
      }
      // If execute is false, just stay visible showing the matched action
    case .group(let group):
      if execute, let mods = modifiers, shouldRunGroupSequenceWithModifiers(mods) {
        hide {
          self.runGroup(group)
        }
      } else {
        userState.display = group.key
        userState.navigateToGroup(group)
      }
    case .none:
      window.notFound()
    }

    // Why do we need to wait here?
    delay(1) {
      self.positionCheatsheetWindow()
    }
  }

  private func shouldRunGroupSequence(_ event: NSEvent) -> Bool {
    return shouldRunGroupSequenceWithModifiers(event.modifierFlags)
  }

  private func shouldRunGroupSequenceWithModifiers(_ modifierFlags: NSEvent.ModifierFlags) -> Bool {
    let config = Defaults[.modifierKeyConfiguration]

    switch config {
    case .controlGroupOptionSticky:
      return modifierFlags.contains(.control)
    case .optionGroupControlSticky:
      return modifierFlags.contains(.option)
    }
  }

  private func isInStickyMode(_ modifierFlags: NSEvent.ModifierFlags) -> Bool {
    let config = Defaults[.modifierKeyConfiguration]

    switch config {
    case .controlGroupOptionSticky:
      return modifierFlags.contains(.option)
    case .optionGroupControlSticky:
      return modifierFlags.contains(.control)
    }
  }

  internal func charForEvent(_ event: NSEvent) -> String? {
    let forceEnglish = Defaults[.forceEnglishKeyboardLayout]

    // 1. If the user forces English, or if the key is non-printable,
    //    fall back to the hard-coded map.
    if forceEnglish {
      return englishGlyph(for: event)
    }

    // 2. For special keys like Enter, always use the mapped glyph
    if let entry = KeyMaps.entry(for: event.keyCode) {
      // For Enter, Space, Tab, arrows, etc. - use the glyph representation
      if event.keyCode == KeyHelpers.enter.rawValue || event.keyCode == KeyHelpers.space.rawValue
        || event.keyCode == KeyHelpers.tab.rawValue
        || event.keyCode == KeyHelpers.leftArrow.rawValue
        || event.keyCode == KeyHelpers.rightArrow.rawValue
        || event.keyCode == KeyHelpers.upArrow.rawValue
        || event.keyCode == KeyHelpers.downArrow.rawValue
      {
        return entry.glyph
      }
    }

    // 3. Use the system-translated character for regular keys.
    if let printable = event.charactersIgnoringModifiers,
      !printable.isEmpty,
      printable.unicodeScalars.first?.isASCII ?? false
    {
      return printable  // already contains correct case
    }

    // 4. For arrows, ␣, ⌫ … use map as last resort.
    return englishGlyph(for: event)
  }

  private func englishGlyph(for event: NSEvent) -> String? {
    guard let entry = KeyMaps.entry(for: event.keyCode) else {
      return event.charactersIgnoringModifiers
    }
    if entry.glyph.first?.isLetter == true && !entry.isReserved {
      return event.modifierFlags.contains(.shift)
        ? entry.glyph.uppercased()
        : entry.glyph
    }
    return entry.glyph
  }

  private func positionCheatsheetWindow() {
    guard let mainWindow = window, let cheatsheet = cheatsheetWindow else {
      return
    }

    cheatsheet.setFrameOrigin(
      mainWindow.cheatsheetOrigin(cheatsheetSize: cheatsheet.frame.size))
  }

  private func showCheatsheet() {
    if !window.hasCheatsheet {
      return
    }
    positionCheatsheetWindow()
    cheatsheetWindow?.orderFront(nil)
  }

  private func scheduleCheatsheet() {
    cheatsheetTimer?.invalidate()

    cheatsheetTimer = Timer.scheduledTimer(
      withTimeInterval: Double(Defaults[.cheatsheetDelayMS]) / 1000.0, repeats: false
    ) { [weak self] _ in
      self?.showCheatsheet()
    }
  }

  private func runGroup(_ group: Group) {
    for groupOrAction in group.actions {
      switch groupOrAction {
      case .group(let group):
        runGroup(group)
      case .action(let action):
        runAction(action)
      }
    }
  }

  private func runAction(_ action: Action) {
    switch action.type {
    case .application:
      NSWorkspace.shared.openApplication(
        at: URL(fileURLWithPath: action.value),
        configuration: NSWorkspace.OpenConfiguration())
    case .url:
      openURL(action)
    case .command:
      runCommand(action)
    case .folder:
      let path: String = (action.value as NSString).expandingTildeInPath
      let folderURL = URL(fileURLWithPath: path)
      
      if let openWithPath = action.openWith {
        // Open folder with specified application
        let appURL = URL(fileURLWithPath: openWithPath)
        NSWorkspace.shared.open(
          [folderURL],
          withApplicationAt: appURL,
          configuration: NSWorkspace.OpenConfiguration()
        )
      } else {
        // Default: open in Finder
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
      }
    case .file:
      let path: String = (action.value as NSString).expandingTildeInPath
      let fileURL = URL(fileURLWithPath: path)
      
      if let openWithPath = action.openWith {
        // Open file with specified application
        let appURL = URL(fileURLWithPath: openWithPath)
        NSWorkspace.shared.open(
          [fileURL],
          withApplicationAt: appURL,
          configuration: NSWorkspace.OpenConfiguration()
        )
      } else {
        // Default: open with default application
        NSWorkspace.shared.open(fileURL)
      }
    case .script:
      runScript(action)
    default:
      print("\(action.type) unknown")
    }

    if window.isVisible {
      window.makeKeyAndOrderFront(nil)
    }
  }
  
  private func runScript(_ action: Action) {
    guard let args = collectArgumentsIfNeeded(for: action) else { return }
    CommandRunner.runScript(path: action.value, arguments: args)
  }
  
  private func runCommand(_ action: Action) {
    guard let args = collectArgumentsIfNeeded(for: action) else { return }
    var command = action.value
    for value in args {
      command += " " + CommandRunner.shellEscape(value)
    }
    CommandRunner.run(command)
  }

  private func moveSelection(by delta: Int) {
    let actions = userState.currentActions
    guard !actions.isEmpty else { return }

    if let current = userState.selectedIndex {
      var newIndex = current + delta
      // Wrap around
      if newIndex < 0 {
        newIndex = actions.count - 1
      } else if newIndex >= actions.count {
        newIndex = 0
      }
      userState.selectedIndex = newIndex
    } else {
      // No selection yet, start at first (down) or last (up)
      userState.selectedIndex = delta > 0 ? 0 : actions.count - 1
    }
  }

  private func executeSelectedItem() {
    guard let item = userState.selectedItem else { return }
    handleItemTapped(item)
  }

  private func handleItemTapped(_ item: ActionOrGroup) {
    switch item {
    case .action(let action):
      hide {
        self.runAction(action)
      }
    case .group(let group):
      userState.display = group.key
      userState.navigateToGroup(group)
      delay(1) {
        self.positionCheatsheetWindow()
      }
    }
  }

  private func enterSelectedGroup() {
    guard let item = userState.selectedItem else { return }

    // Only enter if the selected item is a group
    if case .group(let group) = item {
      userState.display = group.key
      userState.navigateToGroup(group)
      delay(1) {
        self.positionCheatsheetWindow()
      }
    }
  }

  private func goBack() {
    // Go back to parent group if we're in a nested group
    if userState.goBack() {
      delay(1) {
        self.positionCheatsheetWindow()
      }
    }
  }

  private func clear() {
    userState.clear()
  }
  
  /// Returns argument values, or nil if cancelled. Returns [] if no arguments defined.
  private func collectArgumentsIfNeeded(for action: Action) -> [String]? {
    guard let arguments = action.arguments, !arguments.isEmpty else { return [] }
    return ScriptArgumentDialog.collectArguments(for: arguments, scriptName: action.displayName)
  }

  private func openURL(_ action: Action) {
    guard let args = collectArgumentsIfNeeded(for: action) else { return }
    
    // Substitute $1, $2, etc. with argument values (URL encoded)
    var urlString = action.value
    for (index, value) in args.enumerated() {
      let placeholder = "$\(index + 1)"
      let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
      urlString = urlString.replacingOccurrences(of: placeholder, with: encoded)
    }
    
    guard let url = URL(string: urlString) else {
      showAlert(
        title: "Invalid URL", message: "Failed to parse URL: \(urlString)")
      return
    }

    guard let scheme = url.scheme else {
      showAlert(
        title: "Invalid URL",
        message:
          "URL is missing protocol (e.g. https://, raycast://): \(action.value)"
      )
      return
    }

    // If openWith is specified, open URL with that application
    if let openWithPath = action.openWith {
      let appURL = URL(fileURLWithPath: openWithPath)
      NSWorkspace.shared.open(
        [url],
        withApplicationAt: appURL,
        configuration: NSWorkspace.OpenConfiguration()
      )
      return
    }

    // Default behavior
    if scheme == "http" || scheme == "https" {
      NSWorkspace.shared.open(
        url,
        configuration: NSWorkspace.OpenConfiguration())
    } else {
      NSWorkspace.shared.open(
        url,
        configuration: DontActivateConfiguration.shared.configuration)
    }
  }

  private func showAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }
  
  private func deleteSelectedItem() {
    guard let selectedItem = userState.selectedItem,
          let selectedIndex = userState.selectedIndex else {
      return
    }
    
    // Set flag before showing dialog to prevent window hiding during deletion
    isPerformingDeletion = true
    defer { isPerformingDeletion = false }  // Always clear, even if cancelled
    
    // Show confirmation dialog
    let itemName: String
    switch selectedItem {
    case .action(let action):
      itemName = action.displayName
    case .group(let group):
      itemName = group.displayName
    }
    
    let alert = NSAlert()
    alert.messageText = "Delete \"\(itemName)\"?"
    alert.informativeText = "This action cannot be undone."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Delete")
    alert.addButton(withTitle: "Cancel")
    
    NSApp.activate(ignoringOtherApps: true)
    let response = alert.runModal()
    
    if response == .alertFirstButtonReturn {
      // User confirmed deletion
      deleteItem(selectedItem, at: selectedIndex)
      // Flag will be cleared by defer after deleteItem completes
    }
    // If cancelled, defer still clears the flag
  }
  
  private func groupsMatch(_ g1: Group, _ g2: Group) -> Bool {
    // Both must have same key (including both nil)
    guard g1.key == g2.key else { return false }
    
    // Both must have same label (including both nil)
    guard g1.label == g2.label else { return false }
    
    // If both key and label are nil, this is ambiguous - log warning
    if g1.key == nil && g1.label == nil {
      print("⚠️ Warning: Matching groups with nil key and label - may match incorrectly")
    }
    
    return true
  }
  
  private func validateNavigationPath() -> Bool {
    var currentRoot = userConfig.root
    for groupInPath in userState.navigationPath {
      guard let groupIndex = currentRoot.actions.firstIndex(where: {
        if case .group(let g) = $0 {
          return groupsMatch(g, groupInPath)
        }
        return false
      }) else {
        print("⚠️ validateNavigationPath: Group in path not found in config - path may be stale")
        return false
      }
      
      if case .group(let nestedGroup) = currentRoot.actions[groupIndex] {
        currentRoot = nestedGroup
      } else {
        return false
      }
    }
    return true
  }
  
  private func deleteItem(_ item: ActionOrGroup, at index: Int) {
    let config = userConfig
    let path = userState.navigationPath
    
    print("🗑️ deleteItem: Deleting item at index \(index), path length: \(path.count)")
    
    if path.isEmpty {
      // Delete from root
      var updatedRoot = config.root
      if index >= 0 && index < updatedRoot.actions.count {
        updatedRoot.actions.remove(at: index)
        config.root = updatedRoot
        userState.selectedIndex = nil
        config.saveConfig()
        print("✅ deleteItem: Successfully deleted from root")
      } else {
        print("❌ deleteItem: Index \(index) out of bounds for root (count: \(updatedRoot.actions.count))")
        showAlert(title: "Deletion Failed", message: "Could not delete item: index out of bounds")
      }
    } else {
      // Validate navigation path before attempting deletion
      if !validateNavigationPath() {
        print("⚠️ deleteItem: Navigation path is stale, clearing and retrying from root")
        userState.navigationPath = []
        // Fallback: try to delete from root if path is invalid
        var updatedRoot = config.root
        if index >= 0 && index < updatedRoot.actions.count {
          updatedRoot.actions.remove(at: index)
          config.root = updatedRoot
          userState.selectedIndex = nil
          config.saveConfig()
          print("✅ deleteItem: Successfully deleted from root after path validation failed")
        } else {
          print("❌ deleteItem: Failed to delete after path validation")
          showAlert(title: "Deletion Failed", message: "Could not delete item: navigation path is invalid.")
        }
        return
      }
      
      // Delete from nested group
      var updatedRoot = config.root
      if deleteItemAtPath(path: path, index: index, root: &updatedRoot) {
        config.root = updatedRoot
        userState.selectedIndex = nil
        config.saveConfig()
        print("✅ deleteItem: Successfully deleted from nested group")
      } else {
        print("❌ deleteItem: Failed to delete from nested group")
        showAlert(title: "Deletion Failed", message: "Could not delete item from nested group. Check console for details.")
      }
    }
  }
  
  private func deleteItemAtPath(path: [Group], index: Int, root: inout Group) -> Bool {
    guard !path.isEmpty else {
      print("❌ deleteItemAtPath: path is empty")
      return false
    }
    
    func navigateAndDelete(path: [Group], root: inout Group) -> Bool {
      if path.isEmpty {
        // We're at the target group - delete the item here
        guard index >= 0 && index < root.actions.count else {
          print("❌ deleteItemAtPath: index \(index) out of bounds (count: \(root.actions.count))")
          return false
        }
        root.actions.remove(at: index)
        print("✅ deleteItemAtPath: Successfully deleted item at index \(index)")
        return true
      }
      
      // Navigate to the nested group
      let targetGroupInPath = path[0]
      guard let groupIndex = root.actions.firstIndex(where: {
        if case .group(let g) = $0 {
          return groupsMatch(g, targetGroupInPath)
        }
        return false
      }) else {
        print("❌ deleteItemAtPath: Could not find group with key=\(targetGroupInPath.key ?? "nil"), label=\(targetGroupInPath.label ?? "nil")")
        return false
      }
      
      if case .group(var nestedGroup) = root.actions[groupIndex] {
        if navigateAndDelete(path: Array(path.dropFirst()), root: &nestedGroup) {
          root.actions[groupIndex] = .group(nestedGroup)
          return true
        }
      }
      
      return false
    }
    
    return navigateAndDelete(path: path, root: &root)
  }
}

class DontActivateConfiguration {
  let configuration = NSWorkspace.OpenConfiguration()

  static var shared = DontActivateConfiguration()

  init() {
    configuration.activates = false
  }
}

extension Screen {
  func getNSScreen() -> NSScreen? {
    switch self {
    case .primary:
      return NSScreen.screens.first
    case .mouse:
      return NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
    case .activeWindow:
      return NSScreen.main
    }
  }
}
