import AppKit
import SwiftUI
import UniformTypeIdentifiers

// Custom NSHostingView that handles drag & drop at AppKit level
class DropEnabledHostingView<Content: View>: NSHostingView<Content> {
  var onFileDrop: (([URL]) -> Void)?
  var onDragStateChange: ((Bool) -> Void)?
  var onDragPositionChange: ((NSPoint) -> Void)?
  private var lastDragUpdateTime: CFTimeInterval = 0
  private let dragUpdateInterval: CFTimeInterval = 1.0 / 30.0
  
  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    print("📦 HostingView draggingEntered")
    
    // Check if we have file URLs
    if sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) {
      print("📦 HostingView: Has file URLs, accepting drag")
      onDragStateChange?(true)
      lastDragUpdateTime = 0
      // Report initial drag position
      let location = convert(sender.draggingLocation, from: nil)
      // Convert Y coordinate: AppKit uses bottom-left origin, but we need to flip for SwiftUI
      let flippedY = bounds.height - location.y
      let swiftUILocation = NSPoint(x: location.x, y: flippedY)
      onDragPositionChange?(swiftUILocation)
      return .copy
    }
    
    print("📦 HostingView: No file URLs, rejecting drag")
    return []
  }
  
  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    let now = CFAbsoluteTimeGetCurrent()
    if now - lastDragUpdateTime < dragUpdateInterval {
      return .copy
    }
    lastDragUpdateTime = now
    // Report drag position updates
    // Convert from window coordinates to view coordinates
    let location = convert(sender.draggingLocation, from: nil)
    // Convert Y coordinate: AppKit uses bottom-left origin, but we need to flip for SwiftUI
    // The view's bounds.height gives us the total height
    let flippedY = bounds.height - location.y
    let swiftUILocation = NSPoint(x: location.x, y: flippedY)
    onDragPositionChange?(swiftUILocation)
    return .copy
  }
  
  override func draggingExited(_ sender: NSDraggingInfo?) {
    print("📦 HostingView draggingExited")
    onDragStateChange?(false)
    // Clear drag position when exiting
    onDragPositionChange?(NSPoint(x: -1, y: -1))
  }
  
  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    print("📦 HostingView performDragOperation")
    onDragStateChange?(false)
    // Clear drag position after drop
    onDragPositionChange?(NSPoint(x: -1, y: -1))
    
    guard let urls = sender.draggingPasteboard.readObjects(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]
    ) as? [URL] else {
      print("❌ HostingView: Failed to get URLs from pasteboard")
      return false
    }
    
    print("✅ HostingView: Got \(urls.count) URL(s), calling callback")
    onFileDrop?(urls)
    return true
  }
  
  required init(rootView: Content) {
    super.init(rootView: rootView)
    registerForDraggedTypes([.fileURL])
    print("📦 HostingView initialized and registered for drag types")
  }
  
  @objc required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

