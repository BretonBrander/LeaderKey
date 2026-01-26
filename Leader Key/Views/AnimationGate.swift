import SwiftUI

enum AnimationGate {
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

  func body(content: Content) -> some View {
    content
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
