import SwiftUI

struct VisualEffectView: NSViewRepresentable {
  var material: NSVisualEffectView.Material
  var blendingMode: NSVisualEffectView.BlendingMode

  func makeNSView(context _: Context) -> NSVisualEffectView {
    let visualEffectView = NSVisualEffectView()
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
    visualEffectView.state = .active
    visualEffectView.wantsLayer = true
    visualEffectView.layer?.cornerRadius = 15
    // Ensure it respects the window's appearance
    visualEffectView.appearance = NSApp.effectiveAppearance
    return visualEffectView
  }

  func updateNSView(_ visualEffectView: NSVisualEffectView, context _: Context) {
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
    // Update appearance when view updates
    if let window = visualEffectView.window {
      visualEffectView.appearance = window.effectiveAppearance
    } else {
      visualEffectView.appearance = NSApp.effectiveAppearance
    }
  }
}
