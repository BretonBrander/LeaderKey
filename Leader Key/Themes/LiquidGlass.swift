import SwiftUI
import AppKit
import Defaults

enum LiquidGlass {
  static let cornerRadius: CGFloat = 20
  static let iconSize = NSSize(width: 24, height: 24)

  /// Notification posted when the LiquidGlass window becomes visible
  static let windowDidShowNotification = Notification.Name("LiquidGlassWindowDidShow")

  /// Returns accent color only if custom color is enabled, otherwise white
  static var highlightColor: Color {
    Defaults[.useCustomColors] ? currentAccentColor() : .white
  }

  class Window: MainWindow {
    override var hasCheatsheet: Bool { return false }

    required init(controller: Controller) {
      super.init(controller: controller, contentRect: NSRect(x: 0, y: 0, width: 0, height: 0))

      backgroundColor = .clear
      isOpaque = false
      hasShadow = false

      let view = CheatsheetView()
        .environmentObject(self.controller.userState)
        .environmentObject(self.controller.userConfig)
      
      let hostingView = DropEnabledHostingView(rootView: view)
      
      // Set up drag state callback
      hostingView.onDragStateChange = { [weak self] isDragging in
        DispatchQueue.main.async {
          self?.controller.userState.isDraggingFile = isDragging
        }
      }
      
      // Set up drop callback
      hostingView.onFileDrop = { [weak self] urls in
        print("🎯 LiquidGlass received \(urls.count) dropped file(s)")
        self?.handleFileDrop(urls: urls)
      }
      
      contentView = hostingView
    }

    override func show(on screen: NSScreen, after: (() -> Void)? = nil) {
      let center = screen.center()
      let newOriginX = center.x - frame.width / 2
      let newOriginY = center.y - frame.height / 2 + frame.height / 8
      self.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))

      makeKeyAndOrderFront(nil)

      fadeInAndUp {
        after?()
      }

      // Notify view to trigger animations immediately - StaggeredEntry handles its own onAppear
      NotificationCenter.default.post(name: LiquidGlass.windowDidShowNotification, object: nil)
    }

    override func hide(after: (() -> Void)? = nil) {
      fadeOutAndDown {
        self.close()
        after?()
      }
    }

    override func notFound() {
      shake()
    }
  }

  // MARK: - Indent Spacer

  struct IndentSpacer: View {
    let level: Int

    var body: some View {
      if level > 0 {
        Text(String(repeating: "  ", count: level))
      }
    }
  }

  // MARK: - Key Badge

  struct KeyBadge: View {
    let key: String
    var isHighlighted: Bool = false
    @State private var hasAppeared = false

    private var glowOpacity: Double {
      isHighlighted ? 0.4 : 0.15
    }

    private var borderOpacity: Double {
      isHighlighted ? 0.5 : 0.3
    }

    var body: some View {
      Text(KeyMaps.glyph(for: key) ?? key)
        .font(.system(.body, design: .rounded))
        .multilineTextAlignment(.center)
        .fontWeight(.bold)
        .padding(.vertical, 4)
        .frame(width: 26)
        .background(
          ZStack {
            // Glow effect when highlighted - use accent color only when highlighted
            if isHighlighted {
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(highlightColor.opacity(0.15))
                .blur(radius: 4)
                .scaleEffect(1.3)
            }

            // Use accent color only when highlighted, otherwise white
            let badgeColor: Color = isHighlighted ? highlightColor : .white
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(badgeColor.opacity(glowOpacity))
              .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .stroke(
                    LinearGradient(
                      colors: [badgeColor.opacity(borderOpacity), badgeColor.opacity(borderOpacity * 0.4)],
                      startPoint: .top,
                      endPoint: .bottom
                    ),
                    lineWidth: isHighlighted ? 1 : 0.5
                  )
              )
          }
        )
        .scaleEffect(hasAppeared ? (isHighlighted ? 1.08 : 1.0) : 0.8)
        .opacity(hasAppeared ? 1 : 0)
        .animation(AnimationPresets.selection, value: isHighlighted)
        .onAppear {
          withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            hasAppeared = true
          }
        }
    }
  }

  // MARK: - Pulse Glow

  struct PulseGlow: View {
    let isActive: Bool
    @State private var pulseOpacity: Double = 0.06
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(highlightColor.opacity(pulseOpacity))
        .blur(radius: 10)
        .scaleEffect(pulseScale)
        .opacity(isActive ? 1 : 0)
        .onChange(of: isActive) { active in
          if active { startPulse() }
        }
        .onAppear { if isActive { startPulse() } }
    }

    private func startPulse() {
      pulseOpacity = 0.06
      pulseScale = 1.0
      withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
        pulseOpacity = 0.15
        pulseScale = 1.08
      }
    }
  }

  // MARK: - Selection Highlight

  struct SelectionHighlight: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool

    init(isSelected: Bool, isHovered: Bool = false) {
      self.isSelected = isSelected
      self.isHovered = isHovered
    }

    private var scale: CGFloat {
      isSelected ? 1.015 : (isHovered ? 1.005 : 1.0)
    }

    func body(content: Content) -> some View {
      content
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
          ZStack {
            PulseGlow(isActive: isSelected)

            // Glass base
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(highlightColor.opacity(isSelected ? 0.15 : (isHovered ? 0.06 : 0)))

            // Top specular highlight
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(
                LinearGradient(
                  stops: [
                    .init(color: highlightColor.opacity(isSelected ? 0.4 : (isHovered ? 0.15 : 0)), location: 0),
                    .init(color: highlightColor.opacity(isSelected ? 0.15 : (isHovered ? 0.05 : 0)), location: 0.25),
                    .init(color: .clear, location: 0.5)
                  ],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )

            // Edge glow
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .stroke(
                LinearGradient(
                  stops: [
                    .init(color: highlightColor.opacity(isSelected ? 0.7 : (isHovered ? 0.3 : 0)), location: 0),
                    .init(color: highlightColor.opacity(isSelected ? 0.3 : (isHovered ? 0.12 : 0)), location: 0.3),
                    .init(color: highlightColor.opacity(isSelected ? 0.2 : (isHovered ? 0.08 : 0)), location: 0.7),
                    .init(color: highlightColor.opacity(isSelected ? 0.3 : (isHovered ? 0.12 : 0)), location: 1)
                  ],
                  startPoint: .top,
                  endPoint: .bottom
                ),
                lineWidth: isSelected ? 1.5 : 1
              )
          }
        )
        .scaleEffect(scale)
        .animation(AnimationPresets.selection, value: isSelected)
        .animation(AnimationPresets.hover, value: isHovered)
        .padding(.horizontal, -8)
        .padding(.vertical, -4)
    }
  }

  // MARK: - Interactive Row Base

  struct InteractiveRow<Content: View>: View {
    let isSelected: Bool
    let onTap: (() -> Void)?
    let onHover: ((Bool) -> Void)?
    @ViewBuilder let content: (_ isHovered: Bool) -> Content

    @State private var isHovered = false

    var body: some View {
      content(isHovered)
        .modifier(SelectionHighlight(isSelected: isSelected, isHovered: isHovered))
        .contentShape(Rectangle())
        .onHover { hovering in
          isHovered = hovering
          onHover?(hovering)
        }
        .onTapGesture { onTap?() }
    }
  }

  // MARK: - Action Row

  struct ActionRow: View {
    let action: Action
    let indent: Int
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    var onHover: ((Bool) -> Void)? = nil
    @Default(.showDetailsInCheatsheet) var showDetails
    @Default(.showAppIconsInCheatsheet) var showIcons

    var body: some View {
      InteractiveRow(isSelected: isSelected, onTap: onTap, onHover: onHover) { isHovered in
        HStack {
          HStack {
            IndentSpacer(level: indent)
            KeyBadge(key: action.key ?? "●", isHighlighted: isSelected)

            if showIcons {
              actionIcon(item: .action(action), iconSize: LiquidGlass.iconSize)
                .opacity(isSelected ? 1 : 0.85)
                .animation(AnimationPresets.selection, value: isSelected)
            }

            Text(action.displayName)
              .lineLimit(1)
              .truncationMode(.middle)
          }
          Spacer()
          if showDetails {
            Text(action.value)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
              .opacity(isHovered || isSelected ? 0.9 : 0.6)
              .animation(AnimationPresets.hover, value: isHovered)
          }
        }
      }
    }
  }

  // MARK: - Group Row

  struct GroupRow: View {
    @Default(.expandGroupsInCheatsheet) var expand
    @Default(.showDetailsInCheatsheet) var showDetails
    @Default(.showAppIconsInCheatsheet) var showIcons

    let group: Group
    let indent: Int
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    var onHover: ((Bool) -> Void)? = nil

    var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        InteractiveRow(isSelected: isSelected, onTap: onTap, onHover: onHover) { isHovered in
          HStack {
            IndentSpacer(level: indent)
            KeyBadge(key: group.key ?? "", isHighlighted: isSelected)

            if showIcons {
              actionIcon(item: .group(group), iconSize: LiquidGlass.iconSize)
                .opacity(isSelected ? 1 : 0.85)
                .animation(AnimationPresets.selection, value: isSelected)
            }

            Image(systemName: "chevron.right")
              .foregroundStyle(.secondary)
              .scaleEffect(isSelected ? 1.15 : 1.0)
              .offset(x: isSelected ? 2 : 0)
              .animation(AnimationPresets.selection, value: isSelected)

            Text(group.displayName)

            Spacer()
            if showDetails {
              Text("\(group.actions.count) item(s)")
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .opacity(isHovered || isSelected ? 0.9 : 0.6)
                .animation(AnimationPresets.hover, value: isHovered)
            }
          }
        }

        if expand {
          ForEach(Array(group.actions.enumerated()), id: \.offset) { _, item in
            switch item {
            case .action(let action):
              ActionRow(action: action, indent: indent + 1)
            case .group(let nestedGroup):
              GroupRow(group: nestedGroup, indent: indent + 1)
            }
          }
        }
      }
    }
  }

  // MARK: - Drop Zone Row

  struct DropZoneRow: View {
    var body: some View {
      HStack(spacing: 10) {
        Image(systemName: "arrow.down.doc.fill")
          .foregroundStyle(highlightColor)
          .font(.system(size: 16, weight: .semibold))
        
        Text("Drop file here to add")
          .font(.system(.body, design: .rounded))
          .fontWeight(.medium)
          .foregroundStyle(highlightColor.opacity(0.9))
        
        Spacer()
      }
      .padding(.vertical, 10)
      .padding(.horizontal, 12)
      .background(
        ZStack {
          // Glass base with accent tint
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(highlightColor.opacity(0.15))
          
          // Top specular highlight
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
              LinearGradient(
                stops: [
                  .init(color: highlightColor.opacity(0.4), location: 0),
                  .init(color: highlightColor.opacity(0.15), location: 0.25),
                  .init(color: .clear, location: 0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
              )
            )
          
          // Edge glow
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(
              LinearGradient(
                stops: [
                  .init(color: highlightColor.opacity(0.7), location: 0),
                  .init(color: highlightColor.opacity(0.3), location: 0.3),
                  .init(color: highlightColor.opacity(0.2), location: 0.7),
                  .init(color: highlightColor.opacity(0.3), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
              ),
              lineWidth: 1.5
            )
        }
      )
    }
  }

  // MARK: - Main Cheatsheet View

  struct CheatsheetView: View {
    @EnvironmentObject var userState: UserState
    @State private var contentHeight: CGFloat = 0
    @State private var headerVisible = false
    @State private var animationTrigger = UUID()
    @State private var navigationDirection: NavigationDirection = .neutral
    @State private var previousPathCount: Int = 0

    private var maxHeight: CGFloat {
      NSScreen.main?.visibleFrame.height.advanced(by: -40) ?? 640
    }

    private static var preferredWidth: CGFloat {
      guard let screen = NSScreen.main else { return 580 }
      let screenHalf = screen.visibleFrame.width / 2
      let desiredWidth: CGFloat = 580
      let margin: CGFloat = 20
      return min(desiredWidth, screenHalf - margin)
    }

    private var actions: [ActionOrGroup] {
      userState.currentGroup?.actions ?? userState.userConfig.root.actions
    }

    /// Unique key for the current navigation state to force view recreation
    private var navigationKey: String {
      userState.navigationPath.map { $0.key ?? "root" }.joined(separator: "/")
    }

    var body: some View {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: 4) {
            header
            actionRows
            
            // Show drop zone when dragging
            if userState.isDraggingFile {
              DropZoneRow()
                .padding(.top, 8)
            }
          }
          .padding()
          .coordinateSpace(name: "scrollContent")
          .overlay(
            GeometryReader { geo in
              Color.clear.preference(
                key: HeightPreferenceKey.self,
                value: geo.size.height
              )
            }
          )
        }
        .onChange(of: userState.selectedIndex) { newIndex in
          if let index = newIndex {
            withAnimation(AnimationPresets.selection) {
              proxy.scrollTo(index, anchor: .center)
            }
          }
        }
      }
      .frame(width: Self.preferredWidth)
      .frame(height: min(contentHeight, maxHeight))
      .background {
        GlossyGlassBackground(cornerRadius: LiquidGlass.cornerRadius)
      }
      .onPreferenceChange(HeightPreferenceKey.self) { height in
        contentHeight = height
      }
      .onReceive(NotificationCenter.default.publisher(for: LiquidGlass.windowDidShowNotification)) { _ in
        triggerEntryAnimation(direction: .neutral)
      }
      .onDisappear {
        headerVisible = false
      }
      .onChange(of: navigationKey) { _ in
        let newPathCount = userState.navigationPath.count
        let direction: NavigationDirection
        if newPathCount > previousPathCount {
          direction = .forward
        } else if newPathCount < previousPathCount {
          direction = .backward
        } else {
          direction = .neutral
        }
        previousPathCount = newPathCount
        triggerEntryAnimation(direction: direction)
      }
    }

    private func triggerEntryAnimation(direction: NavigationDirection) {
      // Update direction for rows
      navigationDirection = direction
      // Reset header visibility to trigger slide animation
      headerVisible = false
      // Generate new trigger to animate rows
      animationTrigger = UUID()
      // Animate header in immediately with spring animation
      withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
        headerVisible = true
      }
    }

    @ViewBuilder
    private var header: some View {
      if let group = userState.currentGroup {
        HStack(spacing: 8) {
          actionIcon(item: .group(group), iconSize: NSSize(width: 20, height: 20))
          Text(group.displayName)
            .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)

        GlassDivider()
          .padding(.bottom, 8)
      }
    }
    
    @ViewBuilder
    private var actionRows: some View {
      ForEach(actions.indices, id: \.self) { index in
        actionRow(at: index)
      }
    }
    
    @ViewBuilder
    private func actionRow(at index: Int) -> some View {
      let item = actions[index]
      let isSelected = userState.selectedIndex == index
      StaggeredEntry(index: index, animationTrigger: animationTrigger, direction: navigationDirection) {
        switch item {
        case .action(let action):
          ActionRow(
            action: action,
            indent: 0,
            isSelected: isSelected,
            onTap: { userState.onItemTapped?(.action(action)) },
            onHover: { hovering in if hovering { userState.selectedIndex = index } }
          )
        case .group(let group):
          GroupRow(
            group: group,
            indent: 0,
            isSelected: isSelected,
            onTap: { userState.onItemTapped?(.group(group)) },
            onHover: { hovering in if hovering { userState.selectedIndex = index } }
          )
        }
      }
      .id("\(navigationKey)-\(index)")
    }
  }
}

struct LiquidGlass_Previews: PreviewProvider {
  static var previews: some View {
    LiquidGlass.CheatsheetView()
      .environmentObject(UserState(userConfig: UserConfig()))
  }
}
