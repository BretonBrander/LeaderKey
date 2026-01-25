import Cocoa
import QuartzCore
import SwiftUI
import Combine
import Defaults

// MARK: - Hotkey Capture Dialog

/// Shared hotkey capture dialog for drag and drop operations
struct HotkeyCaptureDialog: View {
  let fileName: String
  @Binding var isPresented: Bool
  @Binding var capturedKey: String?
  let onCancel: (() -> Void)?
  @State private var isListening = false
  @State private var currentKey: String = ""
  @Environment(\.colorScheme) private var colorScheme
  
  private var isDarkMode: Bool {
    colorScheme == .dark
  }
  
  private func keyButtonFillColor(listening: Bool) -> Color {
    isDarkMode
      ? (listening ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
      : (listening ? Color.black.opacity(0.15) : Color.black.opacity(0.08))
  }
  
  private func keyButtonStrokeColor(listening: Bool) -> Color {
    isDarkMode
      ? (listening ? Color.white.opacity(0.6) : Color.white.opacity(0.3))
      : (listening ? Color.black.opacity(0.4) : Color.black.opacity(0.2))
  }
  
  private var buttonFillColor: Color {
    isDarkMode
      ? Color.white.opacity(0.1)
      : Color.black.opacity(0.08)
  }
  
  private var buttonFillColorActive: Color {
    isDarkMode
      ? Color.white.opacity(0.15)
      : Color.black.opacity(0.12)
  }
  
  private var buttonStrokeColor: Color {
    isDarkMode
      ? Color.white.opacity(0.2)
      : Color.black.opacity(0.15)
  }
  
  private var buttonStrokeColorActive: Color {
    isDarkMode
      ? Color.white.opacity(0.4)
      : Color.black.opacity(0.3)
  }
  
  var body: some View {
    VStack(spacing: 20) {
        // Title
        Text("Set Hotkey")
          .font(.system(.title2, design: .rounded))
          .fontWeight(.semibold)
          .foregroundStyle(.primary)
        
        // File name
        Text(fileName)
          .font(.system(.body, design: .rounded))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
          .padding(.horizontal)
        
        // Key capture area
        HStack(spacing: 12) {
          Text("Shortcut key:")
            .font(.system(.body, design: .rounded))
            .foregroundStyle(.secondary)
          
          // Key button
          Button(action: {
            isListening = true
            currentKey = ""
          }) {
            ZStack {
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(keyButtonFillColor(listening: isListening))
                .overlay(
                  RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                      keyButtonStrokeColor(listening: isListening),
                      lineWidth: isListening ? 2 : 1.5
                    )
                )
              
              if currentKey.isEmpty {
                Text("?")
                  .font(.system(.title3, design: .rounded))
                  .fontWeight(.semibold)
                  .foregroundStyle(.secondary)
              } else {
                Text(KeyMaps.glyph(for: currentKey) ?? currentKey)
                  .font(.system(.title2, design: .rounded))
                  .fontWeight(.bold)
                  .foregroundStyle(.primary)
              }
            }
            .frame(width: 60, height: 50)
          }
          .buttonStyle(PlainButtonStyle())
          .background(
            DialogKeyListenerView(
              isListening: $isListening,
              text: $currentKey,
              oldValue: .constant(""),
              onKeyChanged: { _, newValue in
                if let newValue = newValue, !newValue.isEmpty {
                  currentKey = newValue
                  isListening = false
                }
              },
              onEnterPressed: {
                if !currentKey.isEmpty {
                  confirm()
                }
              },
              onEscapePressed: {
                cancel()
              }
            )
          )
        }
        
        // Buttons
        HStack(spacing: 12) {
          Button(action: cancel) {
            Text("Cancel")
              .font(.system(.body, design: .rounded))
              .fontWeight(.medium)
              .foregroundStyle(.secondary)
              .frame(width: 100, height: 36)
              .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .fill(buttonFillColor)
                  .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                      .stroke(buttonStrokeColor, lineWidth: 1)
                  )
              )
          }
          .buttonStyle(PlainButtonStyle())
          
          Button(action: confirm) {
            Text("Add")
              .font(.system(.body, design: .rounded))
              .fontWeight(.semibold)
              .foregroundStyle(.primary)
              .frame(width: 100, height: 36)
              .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .fill(buttonFillColorActive)
                  .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                      .stroke(buttonStrokeColorActive, lineWidth: 1.5)
                  )
              )
          }
          .buttonStyle(PlainButtonStyle())
          .disabled(currentKey.isEmpty)
          .opacity(currentKey.isEmpty ? 0.5 : 1.0)
        }
      }
      .padding(24)
      .frame(width: 320)
      .background(GlossyGlassBackground(cornerRadius: 20))
      .onAppear {
      isListening = true
    }
  }
  
  private func cancel() {
    isListening = false
    capturedKey = nil
    isPresented = false
    onCancel?()
  }
  
  private func confirm() {
    isListening = false
    capturedKey = currentKey.isEmpty ? nil : currentKey
    isPresented = false
  }
}

/// Custom key listener for the dialog that handles Enter key
struct DialogKeyListenerView: NSViewRepresentable {
  @Binding var isListening: Bool
  @Binding var text: String
  @Binding var oldValue: String
  var onKeyChanged: KeyChangedFn?
  let onEnterPressed: () -> Void
  let onEscapePressed: () -> Void
  
  func makeNSView(context: Context) -> NSView {
    let view = DialogKeyListenerNSView()
    view.isListening = $isListening
    view.text = $text
    view.oldValue = $oldValue
    view.onKeyChanged = onKeyChanged
    view.onEnterPressed = onEnterPressed
    view.onEscapePressed = onEscapePressed
    return view
  }
  
  func updateNSView(_ nsView: NSView, context: Context) {
    if let view = nsView as? DialogKeyListenerNSView {
      view.isListening = $isListening
      view.text = $text
      view.oldValue = $oldValue
      view.onKeyChanged = onKeyChanged
      view.onEnterPressed = onEnterPressed
      view.onEscapePressed = onEscapePressed
      
      if isListening {
        DispatchQueue.main.async {
          view.window?.makeFirstResponder(view)
        }
      }
    }
  }
  
  class DialogKeyListenerNSView: NSView {
    var isListening: Binding<Bool>?
    var text: Binding<String>?
    var oldValue: Binding<String>?
    var onKeyChanged: KeyChangedFn?
    var onEnterPressed: (() -> Void)?
    var onEscapePressed: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
      // Handle Escape key to cancel
      if event.keyCode == KeyHelpers.escape.rawValue {
        onEscapePressed?()
        return
      }
      
      // Handle Enter key separately
      if event.keyCode == KeyHelpers.enter.rawValue {
        // Trigger if we have a captured key (regardless of listening state)
        if let text = text, !text.wrappedValue.isEmpty {
          // Stop listening if we were listening
          if let isListening = isListening, isListening.wrappedValue {
            isListening.wrappedValue = false
          }
          onEnterPressed?()
        }
        return
      }
      
      // Handle other keys normally
      guard let isListening = isListening, let text = text, isListening.wrappedValue else {
        super.keyDown(with: event)
        return
      }

      let handled = KeyCapture.handle(
        event: event,
        onSet: { value in text.wrappedValue = value ?? "" },
        onCancel: { if let oldValue = self.oldValue { text.wrappedValue = oldValue.wrappedValue } },
        onClear: { text.wrappedValue = "" }
      )

      if handled {
        DispatchQueue.main.async {
          isListening.wrappedValue = false
          self.onKeyChanged?(self.oldValue?.wrappedValue, self.text?.wrappedValue)
        }
      } else {
        super.keyDown(with: event)
      }
    }

    override func resignFirstResponder() -> Bool {
      if let isListening = isListening, isListening.wrappedValue {
        DispatchQueue.main.async {
          isListening.wrappedValue = false
          self.onKeyChanged?(self.oldValue?.wrappedValue, self.text?.wrappedValue)
        }
      }
      return super.resignFirstResponder()
    }
  }
}

class PanelWindow: NSPanel {
  init(contentRect: NSRect) {
    super.init(
      contentRect: contentRect,
      styleMask: [.nonactivatingPanel, .fullSizeContentView],
      backing: .buffered, defer: false
    )

    isFloatingPanel = true
    isReleasedWhenClosed = false
    animationBehavior = .none
    backgroundColor = .clear
    isOpaque = false
    hasShadow = true
    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
  }
}

/// Custom panel class for dialog that can become key window
class DialogWindow: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
  
  init(contentRect: NSRect) {
    super.init(
      contentRect: contentRect,
      styleMask: [.nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    
    self.isFloatingPanel = true
    self.isReleasedWhenClosed = false
    self.animationBehavior = .none
    self.backgroundColor = .clear
    self.isOpaque = false
    self.hasShadow = true
    self.level = .floating
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    self.appearance = NSApp.effectiveAppearance
  }
}

class MainWindow: PanelWindow, NSWindowDelegate {
  override var acceptsFirstResponder: Bool { return true }
  override var canBecomeKey: Bool { return true }
  override var canBecomeMain: Bool { return true }

  var hasCheatsheet: Bool { return true }
  var controller: Controller
  var shouldHideImmediately = false  // Flag for immediate hide (e.g., Escape key)

  required init(controller: Controller) {
    // Here to provide general interface
    // Themes should call super.init(controller:, contentRect:) to get a frame as well
    self.controller = controller
    super.init(contentRect: NSRect())
  }

  init(controller: Controller, contentRect: NSRect) {
    self.controller = controller
    super.init(contentRect: contentRect)
    delegate = self
  }

  func windowDidResignKey(_ notification: Notification) {
    // Don't hide if a modal dialog is active (like deletion confirmation)
    // Modal dialogs cause the window to resign key, but we shouldn't hide during them
    if NSApp.modalWindow != nil {
      return
    }
    
    // Don't hide if deletion is in progress (prevents race condition with save)
    if controller.isPerformingDeletion {
      return
    }
    
    // Check if we need to hide immediately (e.g., Escape key pressed)
    if shouldHideImmediately {
      shouldHideImmediately = false
      controller.hide()
      return
    }
    
    // Simple hide - let controller decide
    controller.hide()
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if event.modifierFlags.contains(.command) {
      controller.keyDown(with: event)
      return true
    }
    return false
  }

  override func keyDown(with event: NSEvent) {
    controller.keyDown(with: event)
  }

  func show(on screen: NSScreen, after: (() -> Void)?) {
    makeKeyAndOrderFront(nil)
    after?()
  }

  func hide(after: (() -> Void)?) {
    close()
    after?()
  }

  func notFound() {
  }

  func cheatsheetOrigin(cheatsheetSize: NSSize) -> NSPoint {
    return NSPoint(x: 0, y: 0)
  }
  
  // MARK: - Drop Context
  private var dropNavigationPath: [Group]? = nil

  // MARK: - Shared Drop Handler Helpers
  
  /// Handles file drop for any theme, adding actions to the appropriate location
  /// Shows hotkey capture dialog for each file
  func handleFileDrop(urls: [URL]) {
    guard !urls.isEmpty else { return }
    // Capture navigation path at drop time
    dropNavigationPath = controller.userState.navigationPath
    processFilesWithHotkeyDialog(urls: urls, index: 0)
  }
  
  private func processFilesWithHotkeyDialog(urls: [URL], index: Int) {
    guard index < urls.count else {
      // All files processed
      controller.userState.selectedIndex = nil
      dropNavigationPath = nil
      return
    }
    let url = urls[index]
    let fileName = url.deletingPathExtension().lastPathComponent
    showHotkeyDialog(
        fileName: fileName,
        completion: { [weak self] capturedKey in
            guard let self = self else { return }
            var action = Action.createFrom(url: url)
            if let hotkey = capturedKey, !hotkey.isEmpty {
                action.key = hotkey
            }
            // Use captured path for this drop session
            self.addAction(action, navigationPath: self.dropNavigationPath)
            self.processFilesWithHotkeyDialog(urls: urls, index: index + 1)
        },
        onCancel: { [weak self] in
            guard let self = self else { return }
            controller.userState.selectedIndex = nil
            dropNavigationPath = nil
        }
    )
  }
  
  private func showHotkeyDialog(fileName: String, completion: @escaping (String?) -> Void, onCancel: @escaping () -> Void) {
    let dialogSize = NSSize(width: 400, height: 350)
    let dialogWindow = DialogWindow(contentRect: NSRect(origin: .zero, size: dialogSize))
    
    var capturedKey: String? = nil
    var isPresented = true
    var wasCancelled = false
    
    let dialogView = HotkeyCaptureDialog(
      fileName: fileName,
      isPresented: Binding(
        get: { isPresented },
        set: { newValue in
          isPresented = newValue
          if !newValue {
            DispatchQueue.main.async {
              dialogWindow.close()
              if wasCancelled {
                onCancel()
              } else {
                completion(capturedKey)
              }
            }
          }
        }
      ),
      capturedKey: Binding(
        get: { capturedKey },
        set: { newValue in
          capturedKey = newValue
        }
      ),
      onCancel: {
        wasCancelled = true
        isPresented = false
      }
    )
    
    let hostingController = NSHostingController(rootView: dialogView)
    hostingController.view.frame = NSRect(origin: .zero, size: dialogSize)
    hostingController.view.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
    
    // Ensure hosting view has no background
    if let layer = hostingController.view.layer {
      layer.backgroundColor = CGColor.clear
    }
    hostingController.view.wantsLayer = true
    hostingController.view.layer?.backgroundColor = CGColor.clear
    
    dialogWindow.contentViewController = hostingController
    dialogWindow.contentView?.wantsLayer = true
    dialogWindow.contentView?.layer?.backgroundColor = CGColor.clear
    dialogWindow.setContentSize(dialogSize)
    
    // Center the dialog on screen
    if let screen = NSScreen.main {
      let screenRect = screen.visibleFrame
      let x = screenRect.midX - dialogSize.width / 2
      let y = screenRect.midY - dialogSize.height / 2
      dialogWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    // Show the dialog
    NSApp.activate(ignoringOtherApps: true)
    dialogWindow.makeKeyAndOrderFront(nil as Any?)
    
    // Ensure keyboard focus goes to the dialog
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      // Make the hosting view accept first responder - it will delegate to DialogKeyListenerView
      let hostingView = hostingController.view
      // Traverse to find a view that accepts first responder
      self.makeKeyListenerFirstResponder(in: hostingView, window: dialogWindow)
    }
  }
  
  private func makeKeyListenerFirstResponder(in view: NSView, window: NSWindow) {
    // Check if this view accepts first responder and has the right characteristics
    if view.acceptsFirstResponder {
      // Check if it's likely the key listener view by checking for acceptsFirstResponder
      window.makeFirstResponder(view)
    }
    // Traverse view hierarchy to find views that accept first responder
    for subview in view.subviews {
      if subview.acceptsFirstResponder {
        window.makeFirstResponder(subview)
        return
      }
      makeKeyListenerFirstResponder(in: subview, window: window)
    }
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
    var currentRoot = controller.userConfig.root
    for groupInPath in controller.userState.navigationPath {
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
  
  private func addAction(_ action: Action, navigationPath: [Group]? = nil) {
    let config = controller.userConfig
    let path = navigationPath ?? controller.userState.navigationPath
    let currentGroup = path.last
    print("🎯 addAction: path.count=\(path.count), currentGroup=\(currentGroup?.displayName ?? "nil"), selectedItem=\(controller.userState.selectedItem != nil)")
    if let selectedItem = controller.userState.selectedItem {
        switch selectedItem {
        case .group(let group):
            var updatedRoot = config.root
            if addActionToGroup(action, group: group, in: &updatedRoot) {
                config.root = updatedRoot
                config.saveConfig()
            } else {
                var newRoot = config.root
                newRoot.actions.append(.action(action))
                config.root = newRoot
                config.saveConfig()
            }
        case .action(let selectedAction):
            var updatedRoot = config.root
            if addActionAfterAction(selectedAction, newAction: action, root: &updatedRoot) {
                config.root = updatedRoot
                config.saveConfig()
            } else {
                var newRoot = config.root
                newRoot.actions.append(.action(action))
                config.root = newRoot
                config.saveConfig()
            }
        }
    } else {
        if let currentGroup = currentGroup {
            print("📁 addAction: Adding to current group: \(currentGroup.displayName)")
            var updatedRoot = config.root
            if addActionToGroup(action, group: currentGroup, in: &updatedRoot) {
                config.root = updatedRoot
                config.saveConfig()
                print("✅ addAction: Successfully added to current group")
                return
            } else {
                print("❌ addAction: Failed to add to current group, falling back to root")
            }
        }
        print("📁 addAction: Adding to root (no current group or add failed)")
        var newRoot = config.root
        newRoot.actions.append(.action(action))
        config.root = newRoot
        config.saveConfig()
    }
  }
  
  private func addActionToGroup(_ action: Action, group: Group, in root: inout Group) -> Bool {
    print("🔍 addActionToGroup: Looking for group key=\(group.key ?? "nil"), label=\(group.label ?? "nil")")
    
    func findAndUpdateGroup(target: Group, root: inout Group, depth: Int = 0) -> Bool {
      let indent = String(repeating: "  ", count: depth)
      print("\(indent)🔍 Searching at depth \(depth), checking \(root.actions.count) items")
      
      for (index, item) in root.actions.enumerated() {
        if case .group(let g) = item {
          print("\(indent)  Checking group[\(index)]: key=\(g.key ?? "nil"), label=\(g.label ?? "nil")")
          if groupsMatch(g, target) {
            var updatedGroup = g
            updatedGroup.actions.append(.action(action))
            root.actions[index] = .group(updatedGroup)
            print("\(indent)✅ addActionToGroup: Successfully added action to group at depth \(depth)")
            return true
          } else {
            if case .group(var nestedGroup) = root.actions[index] {
              if findAndUpdateGroup(target: target, root: &nestedGroup, depth: depth + 1) {
                root.actions[index] = .group(nestedGroup)
                return true
              }
            }
          }
        }
      }
      print("\(indent)❌ addActionToGroup: Could not find target group at depth \(depth)")
      return false
    }
    
    return findAndUpdateGroup(target: group, root: &root)
  }
  
  private func addActionToGroupAtPath(path: [Group], action: Action, root: inout Group) -> Bool {
    guard !path.isEmpty else {
      print("❌ addActionToGroupAtPath: path is empty")
      return false
    }
    
    func navigateAndUpdate(path: [Group], root: inout Group) -> Bool {
      if path.isEmpty {
        // We're at the target group - add the action here
        root.actions.append(.action(action))
        print("✅ addActionToGroupAtPath: Successfully added action to nested group")
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
        print("❌ addActionToGroupAtPath: Could not find group with key=\(targetGroupInPath.key ?? "nil"), label=\(targetGroupInPath.label ?? "nil")")
        return false
      }
      
      if case .group(var nestedGroup) = root.actions[groupIndex] {
        if navigateAndUpdate(path: Array(path.dropFirst()), root: &nestedGroup) {
          root.actions[groupIndex] = .group(nestedGroup)
          return true
        }
      }
      
      return false
    }
    
    return navigateAndUpdate(path: path, root: &root)
  }
  
  private func addActionAfterAction(_ targetAction: Action, newAction: Action, root: inout Group) -> Bool {
    let path = controller.userState.navigationPath
    
    func updateActionInGroup(path: [Group], root: inout Group) -> Bool {
      if path.isEmpty {
        if let actionIndex = root.actions.firstIndex(where: {
          if case .action(let a) = $0 {
            return a.key == targetAction.key && a.value == targetAction.value
          }
          return false
        }) {
          root.actions.insert(.action(newAction), at: actionIndex + 1)
          return true
        }
        return false
      }
      
      let targetGroupInPath = path[0]
      guard let groupIndex = root.actions.firstIndex(where: {
        if case .group(let g) = $0 {
          return groupsMatch(g, targetGroupInPath)
        }
        return false
      }) else { return false }
      
      if case .group(var nestedGroup) = root.actions[groupIndex] {
        if updateActionInGroup(path: Array(path.dropFirst()), root: &nestedGroup) {
          root.actions[groupIndex] = .group(nestedGroup)
          return true
        }
      }
      
      return false
    }
    
    return updateActionInGroup(path: path, root: &root)
  }
  
}
