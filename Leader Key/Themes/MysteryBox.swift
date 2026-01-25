import SwiftUI
import UniformTypeIdentifiers
import AppKit

enum MysteryBox {
  static let size: CGFloat = 200

  class Window: MainWindow {
    required init(controller: Controller) {
      super.init(
        controller: controller,
        contentRect: NSRect(x: 0, y: 0, width: MysteryBox.size, height: MysteryBox.size))

      let view = MainView()
        .environmentObject(self.controller.userState)
        .environmentObject(self.controller.userConfig)
      
      // Use custom DropEnabledHostingView instead of regular NSHostingView
      let hostingView = DropEnabledHostingView(rootView: view)
      
      // Set up drag state callback
      hostingView.onDragStateChange = { [weak self] isDragging in
        DispatchQueue.main.async {
          self?.controller.userState.isDraggingFile = isDragging
        }
      }
      
      // Set up drop callback
      hostingView.onFileDrop = { [weak self] urls in
        print("🎯 MysteryBox received \(urls.count) dropped file(s)")
        self?.handleFileDrop(urls: urls)
      }
      
      contentView = hostingView
    }

    override func show(on screen: NSScreen, after: (() -> Void)? = nil) {
      let center = screen.center()
      let newOriginX = center.x - MysteryBox.size / 2
      let newOriginY = center.y + MysteryBox.size / 8
      self.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))

      makeKeyAndOrderFront(nil)

      fadeInAndUp {
        after?()
      }
    }

    override func hide(after: (() -> Void)? = nil) {
      fadeOutAndDown {
        super.hide(after: after)
      }
    }

    override func notFound() {
      shake()
    }

    override func cheatsheetOrigin(cheatsheetSize: NSSize) -> NSPoint {
      return NSPoint(
        x: frame.maxX + 20,
        y: frame.midY - cheatsheetSize.height / 2
      )
    }
  }

  struct MainView: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var userConfig: UserConfig

    var body: some View {
      ZStack {
        let keyText = userState.currentGroup?.key ?? userState.display ?? "●"
        let glyphText = KeyMaps.glyph(for: keyText) ?? keyText
        let text = Text(glyphText)
          .fontDesign(.rounded)
          .fontWeight(.semibold)
          .font(.system(size: 28, weight: .semibold, design: .rounded))

        if userState.isShowingRefreshState {
          text.pulsate()
        } else {
          text
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .background(
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
      )
      .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
    }
  }
}

struct MysteryBox_MainView_Previews: PreviewProvider {
  static var previews: some View {
    let userConfig = UserConfig()
    return MysteryBox.MainView()
      .environmentObject(UserState(userConfig: userConfig))
      .environmentObject(userConfig)
      .frame(width: MysteryBox.size, height: MysteryBox.size, alignment: .center)
  }
}
