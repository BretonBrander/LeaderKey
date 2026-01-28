import SwiftUI
import AppKit

enum AnimationGate {
  /// System-wide reduce motion accessibility setting
  static var systemReduceMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  }
  
  static func resolved(_ animation: Animation?, reduceMotion: Bool, isEnabled: Bool = true) -> Animation? {
    guard isEnabled, !reduceMotion else { return nil }
    return animation
  }

  static func isEnabled(_ animation: Animation?, reduceMotion: Bool, isEnabled: Bool = true) -> Bool {
    resolved(animation, reduceMotion: reduceMotion, isEnabled: isEnabled) != nil
  }

  static func perform(
    _ animation: Animation?,
    reduceMotion: Bool,
    isEnabled: Bool = true,
    _ updates: () -> Void
  ) {
    guard let animation = resolved(animation, reduceMotion: reduceMotion, isEnabled: isEnabled) else {
      updates()
      return
    }
    withAnimation(animation, updates)
  }
  
  /// Execute AppKit animation with reduce motion and window visibility checks
  /// - Parameters:
  ///   - enabled: Whether animation is enabled (default: true)
  ///   - reduceMotion: Whether reduce motion is active
  ///   - windowVisible: Whether the window is visible (default: true)
  ///   - duration: Animation duration
  ///   - animations: Animation closure receiving NSAnimationContext
  ///   - completion: Optional completion handler
  static func performAppKit(
    enabled: Bool = true,
    reduceMotion: Bool,
    windowVisible: Bool = true,
    duration: TimeInterval,
    animations: @escaping (NSAnimationContext) -> Void,
    completion: (() -> Void)? = nil
  ) {
    // If gated, execute immediately without animation
    guard enabled, !reduceMotion, windowVisible else {
      // Directly apply final state
      animations(NSAnimationContext.current)
      completion?()
      return
    }
    
    // Run with animation
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = duration
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animations(context)
      },
      completionHandler: completion
    )
  }
}

extension Notification.Name {
  static let leaderKeyStopAnimations = Notification.Name("LeaderKeyStopAnimations")
}

private struct LeaderKeyAnimationsEnabledKey: EnvironmentKey {
  static let defaultValue = true
}

extension EnvironmentValues {
  var leaderKeyAnimationsEnabled: Bool {
    get { self[LeaderKeyAnimationsEnabledKey.self] }
    set { self[LeaderKeyAnimationsEnabledKey.self] = newValue }
  }
}

struct AnimationEnabledProvider<Content: View>: View {
  @EnvironmentObject var userState: UserState
  let content: Content

  var body: some View {
    content.environment(\.leaderKeyAnimationsEnabled, userState.isWindowVisible)
  }
}

private struct AnimationGateModifier<Value: Equatable>: ViewModifier {
  let animation: Animation?
  let value: Value
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.leaderKeyAnimationsEnabled) private var animationsEnabled

  func body(content: Content) -> some View {
    content.animation(
      AnimationGate.resolved(animation, reduceMotion: reduceMotion, isEnabled: animationsEnabled),
      value: value
    )
  }
}

private struct RepeatForeverModifier: ViewModifier {
  let animation: Animation
  let isEnabled: Bool
  let onStart: () -> Void
  let onAnimate: () -> Void
  let onStop: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.leaderKeyAnimationsEnabled) private var animationsEnabled
  @State private var isRunning = false
  @State private var resetToken = UUID()

  func body(content: Content) -> some View {
    content
      .id(resetToken)
      .onAppear {
        updateRunningState(isEnabled && animationsEnabled)
      }
      .onChange(of: isEnabled) { newValue in
        updateRunningState(newValue && animationsEnabled)
      }
      .onChange(of: animationsEnabled) { newValue in
        updateRunningState(isEnabled && newValue)
      }
      .onDisappear {
        stop()
      }
  }

  private func updateRunningState(_ shouldRun: Bool) {
    if shouldRun {
      start()
    } else {
      stop()
    }
  }

  private func start() {
    guard !isRunning else { return }
    guard AnimationGate.isEnabled(
      animation,
      reduceMotion: reduceMotion,
      isEnabled: isEnabled && animationsEnabled
    ) else {
      onStop()
      isRunning = false
      return
    }
    isRunning = true
    onStart()
    AnimationGate.perform(animation, reduceMotion: reduceMotion, isEnabled: isEnabled && animationsEnabled) {
      onAnimate()
    }
  }

  private func stop() {
    guard isRunning else {
      onStop()
      return
    }
    isRunning = false
    AnimationGate.perform(nil, reduceMotion: reduceMotion) {
      onStop()
    }
    resetToken = UUID()
  }
}

extension View {
  func leaderKeyAnimation<Value: Equatable>(_ animation: Animation?, value: Value) -> some View {
    modifier(AnimationGateModifier(animation: animation, value: value))
  }

  func leaderKeyRepeatForever(
    _ animation: Animation,
    isEnabled: Bool = true,
    onStart: @escaping () -> Void,
    onAnimate: @escaping () -> Void,
    onStop: @escaping () -> Void
  ) -> some View {
    modifier(
      RepeatForeverModifier(
        animation: animation,
        isEnabled: isEnabled,
        onStart: onStart,
        onAnimate: onAnimate,
        onStop: onStop
      )
    )
  }
}
