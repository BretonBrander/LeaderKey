import AppKit
import ObjectiveC
import SwiftUI
import SymbolPicker

// MARK: - Notification Names

extension Notification.Name {
  static let lkExpandAll = Notification.Name("LKExpandAll")
  static let lkCollapseAll = Notification.Name("LKCollapseAll")
  static let lkSortAZ = Notification.Name("LKSortAZ")
}

// MARK: - Target/Action Closure Helper

class ClosureTarget: NSObject {
  let handler: () -> Void
  init(_ handler: @escaping () -> Void) { self.handler = handler }
  @objc func go() { handler() }
}

extension NSControl {
  func targetClosure(_ action: @escaping () -> Void) {
    let t = ClosureTarget(action)
    self.target = t
    self.action = #selector(ClosureTarget.go)
    objc_setAssociatedObject(
      self, Unmanaged.passUnretained(self).toOpaque(), t, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
  }
}

// MARK: - NSView Layout Helpers

extension NSView {
  func makeFlex() {
    setContentHuggingPriority(.init(10), for: .horizontal)
    setContentCompressionResistancePriority(.init(10), for: .horizontal)
  }

  func makeSoft() {
    setContentHuggingPriority(.defaultLow, for: .horizontal)
    setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
  }

  func makeRigid() {
    setContentHuggingPriority(.defaultHigh, for: .horizontal)
    setContentCompressionResistancePriority(.init(999), for: .horizontal)
  }
}

// MARK: - Symbol Picker Bridge

struct SymbolPickerBridge: View {
  @State var symbol: String?
  var onChange: (String?) -> Void
  var onClose: () -> Void

  init(initial: String?, onChange: @escaping (String?) -> Void, onClose: @escaping () -> Void) {
    _symbol = State(initialValue: initial)
    self.onChange = onChange
    self.onClose = onClose
  }

  var body: some View {
    VStack(spacing: 12) {
      SymbolPicker(
        symbol: Binding(
          get: { symbol },
          set: { newVal in
            symbol = newVal
            onChange(newVal)
          }
        ))
      HStack {
        Spacer()
        Button("Close") { onClose() }
          .keyboardShortcut(.cancelAction)
      }
    }
    .padding()
  }
}

// MARK: - Symbol Picker Sheet Presenter

/// Manages window state for symbol picker sheets
protocol SymbolSheetHost: NSWindowDelegate, AnyObject {
  var symbolWindow: NSWindow? { get set }
  var symbolParent: NSWindow? { get set }
}

func presentSymbolPickerSheet(
  anchor: NSView,
  initial: String?,
  host: SymbolSheetHost,
  onPicked: @escaping (String?) -> Void
) {
  // Close any existing sheet
  if let parent = host.symbolParent, let win = host.symbolWindow {
    parent.endSheet(win)
  }
  host.symbolWindow = nil
  host.symbolParent = nil

  let closeSheet = { [weak host] in
    guard let host = host, let win = host.symbolWindow else { return }
    if let parent = host.symbolParent ?? anchor.window ?? NSApp.keyWindow {
      parent.endSheet(win, returnCode: .cancel)
    } else {
      win.close()
    }
    host.symbolWindow = nil
    host.symbolParent = nil
  }

  let controller = NSHostingController(
    rootView: SymbolPickerBridge(
      initial: initial,
      onChange: { [weak host] value in
        onPicked(value)
        guard let host = host, let win = host.symbolWindow else { return }
        if let parent = host.symbolParent ?? anchor.window ?? NSApp.keyWindow {
          parent.endSheet(win, returnCode: .OK)
        } else {
          win.close()
        }
        host.symbolWindow = nil
        host.symbolParent = nil
      },
      onClose: closeSheet
    ))

  let win = NSWindow(contentViewController: controller)
  win.title = "Choose Symbol"
  win.styleMask.insert(.titled)
  win.styleMask.insert(.closable)
  win.setContentSize(NSSize(width: 560, height: 640))
  win.delegate = host
  host.symbolWindow = win

  let parent = anchor.window ?? NSApp.keyWindow
  host.symbolParent = parent

  if let parent {
    parent.beginSheet(win) { [weak host] _ in
      host?.symbolWindow = nil
      host?.symbolParent = nil
    }
  } else {
    win.center()
    win.makeKeyAndOrderFront(nil)
  }
}

