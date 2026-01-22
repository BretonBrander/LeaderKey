# Swift Animation Performance - Examples

Examples only. Rules and constraints live in `SKILL.md`.

---

## Example 1: Centralized gate with hover state

**Input**  
Refactor a hover animation to avoid direct `withAnimation`.

**Output**
```swift
enum AnimationGate {
    static var enabled: Bool { /* read app setting */ }

    static func animation(_ animation: Animation) -> Animation? {
        enabled ? animation : nil
    }

    static func withAnimation(_ animation: Animation, _ body: () -> Void) {
        if enabled {
            SwiftUI.withAnimation(animation, body)
        } else {
            body()
        }
    }
}

.onHover { hovering in
    AnimationGate.withAnimation(.easeInOut(duration: 0.2)) {
        isHovered = hovering
    }
}
```

---

## Example 2: Repeating animation lifecycle control

**Input**  
Add a repeating pulse that stops when the view disappears.

**Output**
```swift
final class RepeatingAnimationController: ObservableObject {
    private(set) var running = false

    func start(duration: Double, _ body: @escaping () -> Void) {
        guard !running, AnimationGate.enabled else { return }
        running = true
        AnimationGate.withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            body()
        }
    }

    func stop(_ body: @escaping () -> Void) {
        guard running else { return }
        running = false
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }
}

struct PulsingView: View {
    @StateObject private var controller = RepeatingAnimationController()
    @State private var opacity = 0.3
    @State private var scale = 1.0

    var body: some View {
        Circle()
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                controller.start(duration: 2.5) {
                    opacity = 0.7
                    scale = 1.03
                }
            }
            .onDisappear {
                controller.stop {
                    opacity = 0.3
                    scale = 1.0
                }
            }
    }
}
```

---

## Example 3: AppKit animation gating

**Input**  
Guard AppKit animations behind the same enablement flag.

**Output**
```swift
if AnimationGate.enabled {
    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.2
        view.animator().alphaValue = 1.0
    }
} else {
    view.alphaValue = 1.0
}
```

---

## Example 4: Animated image playback without per-frame state

**Input**  
Play a GIF without driving per-frame updates through SwiftUI state.

**Output**
```swift
struct AnimatedImageView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.image = image
        view.animates = true
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = image
        nsView.animates = true
    }
}
```
