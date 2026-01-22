import AppKit
import Defaults
import QuartzCore
import SwiftUI

enum AnimationGate {
  static let uiVisibilityDidChange = Notification.Name("AnimationGateUIVisibilityDidChange")
  private(set) static var isUIVisible = false

  static var enableAnimations: Bool {
    Defaults[.enableAnimations]
  }

  static var reduceMotionSystem: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  }

  static func isEnabled(reduceMotion: Bool) -> Bool {
    enableAnimations && isUIVisible && !reduceMotion
  }

  static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
    isEnabled(reduceMotion: reduceMotion) ? animation : nil
  }

  static func withAnimation(_ animation: Animation, reduceMotion: Bool, _ body: () -> Void) {
    if isEnabled(reduceMotion: reduceMotion) {
      SwiftUI.withAnimation(animation, body)
    } else {
      body()
    }
  }

  static func stopRepeating(_ body: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, body)
  }

  static func runAppKitAnimation(
    duration: TimeInterval,
    timingFunction: CAMediaTimingFunction? = nil,
    animations: @escaping (_ animated: Bool) -> Void,
    completion: (() -> Void)? = nil
  ) {
    if !enableAnimations || !isUIVisible || reduceMotionSystem {
      animations(false)
      completion?()
      return
    }

    NSAnimationContext.runAnimationGroup { context in
      context.duration = duration
      if let timingFunction {
        context.timingFunction = timingFunction
      }
      animations(true)
    } completionHandler: {
      completion?()
    }
  }

  static func setUIVisible(_ visible: Bool) {
    guard isUIVisible != visible else { return }
    isUIVisible = visible
    NotificationCenter.default.post(
      name: uiVisibilityDidChange,
      object: visible
    )
  }
}

final class RepeatingAnimationController: ObservableObject {
  private(set) var running = false

  func start(reduceMotion: Bool, animation: Animation, _ body: @escaping () -> Void) {
    guard !running, AnimationGate.isEnabled(reduceMotion: reduceMotion) else { return }
    running = true
    AnimationGate.withAnimation(animation, reduceMotion: reduceMotion, body)
  }

  func stop(_ body: @escaping () -> Void) {
    guard running else { return }
    running = false
    AnimationGate.stopRepeating(body)
  }
}

private struct RepeatingAnimationDriver: ViewModifier {
  let isActive: Bool
  let animation: Animation
  let prepare: () -> Void
  let onStart: () -> Void
  let onStop: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Default(.enableAnimations) private var enableAnimations
  @StateObject private var controller = RepeatingAnimationController()
  @State private var isVisible = false
  @State private var isUIVisible = AnimationGate.isUIVisible

  private var shouldRun: Bool {
    isVisible && isActive && isUIVisible && enableAnimations && !reduceMotion
  }

  func body(content: Content) -> some View {
    content
      .onAppear {
        isVisible = true
        update()
      }
      .onDisappear {
        isVisible = false
        controller.stop(onStop)
      }
      .onChange(of: isActive) { _ in
        update()
      }
      .onChange(of: enableAnimations) { _ in
        update()
      }
      .onChange(of: reduceMotion) { _ in
        update()
      }
      .onReceive(NotificationCenter.default.publisher(for: AnimationGate.uiVisibilityDidChange)) {
        notification in
        if let visible = notification.object as? Bool {
          isUIVisible = visible
          update()
        }
      }
  }

  private func update() {
    if shouldRun {
      guard !controller.running else { return }
      AnimationGate.stopRepeating(prepare)
      controller.start(reduceMotion: reduceMotion, animation: animation, onStart)
    } else {
      controller.stop(onStop)
    }
  }
}

extension View {
  func gatedAnimation<Value: Equatable>(
    _ animation: Animation,
    value: Value,
    reduceMotion: Bool
  ) -> some View {
    self.animation(AnimationGate.animation(animation, reduceMotion: reduceMotion), value: value)
  }

  func repeatingAnimation(
    isActive: Bool = true,
    animation: Animation,
    prepare: @escaping () -> Void = {},
    onStart: @escaping () -> Void,
    onStop: @escaping () -> Void
  ) -> some View {
    modifier(
      RepeatingAnimationDriver(
        isActive: isActive,
        animation: animation,
        prepare: prepare,
        onStart: onStart,
        onStop: onStop
      )
    )
  }
}
