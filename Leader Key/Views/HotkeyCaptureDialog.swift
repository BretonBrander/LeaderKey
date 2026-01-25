import SwiftUI
import AppKit
import Defaults

/// Helper view to read window's effective appearance
struct WindowAppearanceReader: NSViewRepresentable {
  @Binding var isDarkMode: Bool
  
  func makeNSView(context: Context) -> AppearanceReaderView {
    let view = AppearanceReaderView()
    view.onAppearanceChange = { [weak view] isDark in
      DispatchQueue.main.async {
        isDarkMode = isDark
      }
    }
    return view
  }
  
  func updateNSView(_ nsView: NSView, context: Context) {
    guard let view = nsView as? AppearanceReaderView else { return }
    
    // Always use NSApp.effectiveAppearance as the source of truth
    // Window appearance can be unreliable for programmatically created panels
    let effectiveAppearance = NSApp.effectiveAppearance
    let appIsDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    if isDarkMode != appIsDark {
      DispatchQueue.main.async {
        isDarkMode = appIsDark
      }
    }
  }
  
  class AppearanceReaderView: NSView {
    var onAppearanceChange: ((Bool) -> Void)?
    
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      checkAppearance()
    }
    
    override func viewDidMoveToSuperview() {
      super.viewDidMoveToSuperview()
      checkAppearance()
    }
    
    private func checkAppearance() {
      // Always use NSApp.effectiveAppearance as the source of truth for system appearance
      // Window appearance can be unreliable for programmatically created panels
      let effectiveAppearance = NSApp.effectiveAppearance
      let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      onAppearanceChange?(isDark)
    }
  }
}

/// Shared hotkey capture dialog for drag and drop operations
struct HotkeyCaptureDialog: View {
  let fileName: String
  @Binding var isPresented: Bool
  @Binding var capturedKey: String?
  @State private var isListening = false
  @State private var currentKey: String = ""
  @State private var isDarkMode: Bool = false  // Default to light mode, reader will update
  @Environment(\.colorScheme) private var colorScheme
  
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
  
  var body: some View {
    VStack(spacing: 20) {
      // Hidden view to read window appearance
      WindowAppearanceReader(isDarkMode: $isDarkMode)
        .frame(width: 0, height: 0)
        .hidden()
      
        // Title
        Text("Set Hotkey")
          .font(.system(.title2, design: .rounded))
          .fontWeight(.semibold)
          .foregroundStyle(.red)
        
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
        // Force appearance check on appear - use NSApp as source of truth
        let effectiveAppearance = NSApp.effectiveAppearance
        isDarkMode = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      }
  }
  
  private func cancel() {
    isListening = false
    capturedKey = nil
    isPresented = false
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
  
  func makeNSView(context: Context) -> NSView {
    let view = DialogKeyListenerNSView()
    view.isListening = $isListening
    view.text = $text
    view.oldValue = $oldValue
    view.onKeyChanged = onKeyChanged
    view.onEnterPressed = onEnterPressed
    return view
  }
  
  func updateNSView(_ nsView: NSView, context: Context) {
    if let view = nsView as? DialogKeyListenerNSView {
      view.isListening = $isListening
      view.text = $text
      view.oldValue = $oldValue
      view.onKeyChanged = onKeyChanged
      view.onEnterPressed = onEnterPressed
      
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
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
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

