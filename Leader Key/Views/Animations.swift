import SwiftUI

// MARK: - Animation Presets

enum AnimationPresets {
  static let staggerDelay: Double = 0.025
  static let selection = Animation.spring(response: 0.3, dampingFraction: 0.75)
  static let hover = Animation.spring(response: 0.2, dampingFraction: 0.8)
  static let rowEntry = Animation.spring(response: 0.28, dampingFraction: 0.78)
}

// MARK: - Navigation Direction

enum NavigationDirection {
  case forward   // Going deeper into subgroup - slide from right
  case backward  // Going back to parent - slide from left
  case neutral   // Initial load - slide from bottom
}

// MARK: - Staggered Entry Animation

struct StaggeredEntry<Content: View>: View {
  let index: Int
  let animationTrigger: UUID
  let direction: NavigationDirection
  let content: Content
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isVisible = false

  init(index: Int, animationTrigger: UUID, direction: NavigationDirection, @ViewBuilder content: () -> Content) {
    self.index = index
    self.animationTrigger = animationTrigger
    self.direction = direction
    self.content = content()
  }

  private var xOffset: CGFloat {
    guard !isVisible else { return 0 }
    switch direction {
    case .forward: return 30    // Slide from right
    case .backward: return -30  // Slide from left
    case .neutral: return 0     // No horizontal offset
    }
  }

  private var yOffset: CGFloat {
    guard !isVisible else { return 0 }
    switch direction {
    case .neutral: return 12    // Slide from bottom
    default: return 0           // No vertical offset for horizontal slides
    }
  }

  private var scaleAnchor: UnitPoint {
    switch direction {
    case .forward, .backward: return .center
    case .neutral: return .top
    }
  }

  private func triggerAnimation(reset: Bool = false) {
    if reset {
      isVisible = false
    }
    let delay = Double(index) * AnimationPresets.staggerDelay
    AnimationGate.perform(AnimationPresets.rowEntry.delay(delay), reduceMotion: reduceMotion) {
      isVisible = true
    }
  }

  var body: some View {
    content
      .opacity(isVisible ? 1 : 0)
      .blur(radius: isVisible ? 0 : 3)
      .offset(x: xOffset, y: yOffset)
      .scaleEffect(isVisible ? 1 : 0.95, anchor: scaleAnchor)
      .onAppear {
        triggerAnimation()
      }
      .onChange(of: animationTrigger) { _ in
        triggerAnimation(reset: true)
      }
  }
}
