import Cocoa

/// Presents a modal dialog to collect argument values for script execution
class ScriptArgumentDialog {
  
  /// Shows a dialog to collect argument values
  /// - Parameters:
  ///   - arguments: The script arguments to collect values for
  ///   - scriptName: The name of the script (for display in the dialog)
  /// - Returns: Array of argument values in order, or nil if cancelled
  static func collectArguments(for arguments: [ScriptArgument], scriptName: String) -> [String]? {
    guard !arguments.isEmpty else { return [] }
    
    let alert = NSAlert()
    alert.messageText = scriptName
    alert.informativeText = ""
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Run")
    alert.addButton(withTitle: "Cancel")
    
    // Calculate height based on number of arguments (label + field + spacing per arg)
    // Plus space for hint text at top
    let rowHeight: CGFloat = 50
    let hintHeight: CGFloat = 20
    let totalHeight = CGFloat(arguments.count) * rowHeight + hintHeight + 10
    let width: CGFloat = 300
    
    // Create container with explicit frame
    let containerView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: totalHeight))
    
    // Add hint text at the top
    let hintLabel = NSTextField(labelWithString: "These values will be passed to your command:")
    hintLabel.font = NSFont.systemFont(ofSize: 11)
    hintLabel.textColor = .secondaryLabelColor
    hintLabel.frame = NSRect(x: 0, y: totalHeight - hintHeight, width: width, height: hintHeight)
    
    containerView.addSubview(hintLabel)
    
    var textFields: [NSTextField] = []
    var yOffset = totalHeight - hintHeight - rowHeight
    
    for argument in arguments {
      // Create label above the text field
      let label = NSTextField(labelWithString: argument.name + ":")
      label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
      label.frame = NSRect(x: 0, y: yOffset + 26, width: width, height: 18)
      containerView.addSubview(label)
      
      // Create text field with default value pre-filled
      let textField = NSTextField(frame: NSRect(x: 0, y: yOffset, width: width, height: 24))
      textField.stringValue = argument.defaultValue ?? ""
      textField.placeholderString = argument.defaultValue ?? ""
      textField.font = NSFont.systemFont(ofSize: 13)
      containerView.addSubview(textField)
      textFields.append(textField)
      
      yOffset -= rowHeight
    }
    
    alert.accessoryView = containerView
    
    // Make sure the alert window is frontmost and focused
    NSApp.activate(ignoringOtherApps: true)
    alert.window.level = .floating
    
    // Layout the alert so the accessory view is properly attached
    alert.layout()
    
    // Set the first responder and select text
    if let firstField = textFields.first {
      alert.window.initialFirstResponder = firstField
      alert.window.makeFirstResponder(firstField)
    }
    
    // Run the dialog
    let response = alert.runModal()
    
    if response == .alertFirstButtonReturn {
      return textFields.map { $0.stringValue }
    }
    
    return nil  // Cancelled
  }
}

