import Defaults
import SwiftUI

// MARK: - Glass Effects Utilities

enum GlassEffects {
  /// Standard glass corner radius
  static let cornerRadius: CGFloat = 20

  /// Reusable rounded rectangle with continuous corners
  static func rect(_ radius: CGFloat = cornerRadius) -> RoundedRectangle {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
  }
}

// MARK: - Glossy Glass Background

struct GlossyGlassBackground: View {
  let cornerRadius: CGFloat
  @State private var shimmerOffset: CGFloat = -0.3
  @State private var breatheScale: CGFloat = 1.0
  @State private var breatheOpacity: Double = 0.7
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  // Observe custom color settings for reactivity
  @Default(.useCustomColors) private var useCustomColor
  @Default(.customBackgroundColor) private var backgroundColorData

  /// Background tint color when custom colors are enabled
  private var backgroundTint: Color? {
    guard useCustomColor,
      let nsColor = NSColor.fromArchivedData(backgroundColorData),
      nsColor.alphaComponent > 0
    else {
      return nil
    }
    return Color(nsColor)
  }

  init(cornerRadius: CGFloat = GlassEffects.cornerRadius) {
    self.cornerRadius = cornerRadius
  }

  private var breatheGradient: LinearGradient {
    LinearGradient(
      stops: [
        .init(color: .white.opacity(1.0), location: 0),
        .init(color: .white.opacity(0.5), location: 0.2),
        .init(color: .white.opacity(0.2), location: 0.5),
        .init(color: .white.opacity(0.3), location: 0.8),
        .init(color: .white.opacity(0.4), location: 1),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  var body: some View {
    ZStack {
      // Base layer - AppKit blur (independent from tint)
      VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        .clipShape(GlassEffects.rect(cornerRadius))

      // Tint overlay - adjustable independently from blur
      GlassEffects.rect(cornerRadius)
        .fill(Color.black.opacity(0.08))

      // Custom background color tint (when enabled)
      if let bgColor = backgroundTint {
        GlassEffects.rect(cornerRadius)
          .fill(bgColor.opacity(0.2))
      }

      // Strong specular highlight at top (light hitting glass surface)
      GlassEffects.rect(cornerRadius)
        .fill(
          LinearGradient(
            stops: [
              .init(color: .white.opacity(0.25), location: 0),
              .init(color: .white.opacity(0.2), location: 0.08),
              .init(color: .white.opacity(0.05), location: 0.2),
              .init(color: .clear, location: 0.35),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )

      // Subtle inner shadow for depth
      GlassEffects.rect(cornerRadius)
        .stroke(
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: .black.opacity(0.05), location: 0.6),
              .init(color: .black.opacity(0.08), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 1.5
        )
        .blur(radius: 1.5)
        .padding(1)

      // Breathing edge glow (animated opacity)
      GlassEffects.rect(cornerRadius)
        .stroke(
          breatheGradient,
          lineWidth: 1.5
        )
        .opacity(breatheOpacity)
        .scaleEffect(breatheScale)

      // Fast shimmer sweep on appear
      GlassEffects.rect(cornerRadius)
        .fill(
          LinearGradient(
            stops: [
              .init(color: .clear, location: max(0, shimmerOffset)),
              .init(color: .white.opacity(0.2), location: min(1, max(0, shimmerOffset + 0.03))),
              .init(color: .white.opacity(0.12), location: min(1, max(0, shimmerOffset + 0.08))),
              .init(color: .clear, location: min(1, shimmerOffset + 0.12)),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    }
    .onAppear {
      // Quick initial shimmer
      AnimationGate.withAnimation(.easeOut(duration: 0.6), reduceMotion: reduceMotion) {
        shimmerOffset = 1.2
      }

      pulseBreathingOnce()
    }
  }

  private func pulseBreathingOnce() {
    breatheOpacity = 0.7
    breatheScale = 1.0
    guard AnimationGate.isEnabled(reduceMotion: reduceMotion) else { return }
    AnimationGate.withAnimation(
      .easeInOut(duration: 2.5).repeatCount(1, autoreverses: true),
      reduceMotion: reduceMotion
    ) {
      breatheOpacity = 0.5
      breatheScale = 1.002
    }
  }
}

// MARK: - Glass Divider

struct GlassDivider: View {
  /// Color used for the divider - accent when enabled, otherwise white
  private var dividerColor: Color {
    Defaults[.useCustomColors] ? currentAccentColor() : .white
  }

  var body: some View {
    Rectangle()
      .fill(
        LinearGradient(
          colors: [.clear, dividerColor.opacity(0.4), .clear],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(height: 1)
  }
}

// MARK: - Height Preference Key

struct HeightPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}
