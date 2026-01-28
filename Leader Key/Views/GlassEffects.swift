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
  let material: NSVisualEffectView.Material
  let useSimpleBackground: Bool
  @Environment(\.leaderKeyAnimationsEnabled) private var animationsEnabled
  private let breatheOpacity: Double = 0.7
  private let breatheScale: CGFloat = 1.0

  // Observe custom color settings for reactivity
  @Default(.useCustomColors) private var useCustomColor
  @Default(.customBackgroundColor) private var backgroundColorData

  /// Background tint color when custom colors are enabled
  private var backgroundTint: Color? {
    guard useCustomColor,
          let nsColor = NSColor.fromArchivedData(backgroundColorData),
          nsColor.alphaComponent > 0 else {
      return nil
    }
    return Color(nsColor)
  }

  init(
    cornerRadius: CGFloat = GlassEffects.cornerRadius,
    material: NSVisualEffectView.Material = .hudWindow,
    useSimpleBackground: Bool = false
  ) {
    self.cornerRadius = cornerRadius
    self.material = material
    self.useSimpleBackground = useSimpleBackground
  }

  var body: some View {
    ZStack {
      if useSimpleBackground {
        GlassEffects.rect(cornerRadius)
          .fill((backgroundTint ?? Color.black).opacity(0.18))
      } else {
        // Base layer - AppKit blur (independent from tint)
        VisualEffectView(
          material: animationsEnabled ? material : .underWindowBackground,
          blendingMode: .behindWindow,
          state: animationsEnabled ? .active : .inactive
        )
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
                .init(color: .clear, location: 0.35)
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
                .init(color: .black.opacity(0.08), location: 1)
              ],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 1.5
          )
          .blur(radius: 1.5)
          .padding(1)

        // Breathing edge glow (static)
        GlassEffects.rect(cornerRadius)
          .stroke(
            LinearGradient(
              stops: [
                .init(color: .white.opacity(breatheOpacity), location: 0),
                .init(color: .white.opacity(breatheOpacity * 0.5), location: 0.2),
                .init(color: .white.opacity(breatheOpacity * 0.2), location: 0.5),
                .init(color: .white.opacity(breatheOpacity * 0.3), location: 0.8),
                .init(color: .white.opacity(breatheOpacity * 0.4), location: 1)
              ],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 1.5
          )
          .scaleEffect(breatheScale)
      }
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
