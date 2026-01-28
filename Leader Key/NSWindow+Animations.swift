import Cocoa

enum FadeDirection {
  case `in`
  case out
}

enum SlideDirection: Equatable {
  case none
  case up(distance: CGFloat)
  case down(distance: CGFloat)
}

extension NSWindow {
  /// Unified fade animation with optional slide and reduce motion support
  /// - Parameters:
  ///   - direction: Fade in or out
  ///   - slide: Optional slide direction and distance (default: .none)
  ///   - duration: Animation duration (nil = auto-select: 0.05s for fade-only, 0.125s with slide)
  ///   - reduceMotion: Whether reduce motion is active (default: false)
  ///   - windowVisible: Whether window is visible for animation gating (default: true)
  ///   - callback: Optional completion handler
  func fade(
    direction: FadeDirection,
    slide: SlideDirection = .none,
    duration: TimeInterval? = nil,
    reduceMotion: Bool = false,
    windowVisible: Bool = true,
    callback: (() -> Void)? = nil
  ) {
    // Auto-select duration based on whether we're sliding
    let effectiveDuration = duration ?? (slide == .none ? 0.05 : 0.125)
    
    // Calculate frames and alpha values
    let (fromAlpha, toAlpha): (CGFloat, CGFloat) = direction == .in ? (0, 1) : (1, 0)
    
    let currentFrame = frame
    let (fromFrame, toFrame): (NSRect, NSRect)
    
    switch slide {
    case .none:
      fromFrame = currentFrame
      toFrame = currentFrame
    case .up(let distance):
      if direction == .in {
        // Fade in while moving up: start below
        fromFrame = NSRect(
          x: currentFrame.minX,
          y: currentFrame.minY - distance,
          width: currentFrame.width,
          height: currentFrame.height
        )
        toFrame = currentFrame
      } else {
        // Fade out while moving up: end above
        fromFrame = currentFrame
        toFrame = NSRect(
          x: currentFrame.minX,
          y: currentFrame.minY + distance,
          width: currentFrame.width,
          height: currentFrame.height
        )
      }
    case .down(let distance):
      if direction == .in {
        // Fade in while moving down: start above
        fromFrame = NSRect(
          x: currentFrame.minX,
          y: currentFrame.minY + distance,
          width: currentFrame.width,
          height: currentFrame.height
        )
        toFrame = currentFrame
      } else {
        // Fade out while moving down: end below
        fromFrame = currentFrame
        toFrame = NSRect(
          x: currentFrame.minX,
          y: currentFrame.minY - distance,
          width: currentFrame.width,
          height: currentFrame.height
        )
      }
    }
    
    // Set initial state
    setFrame(fromFrame, display: true)
    alphaValue = fromAlpha
    
    // Animate through gate
    AnimationGate.performAppKit(
      reduceMotion: reduceMotion,
      windowVisible: windowVisible,
      duration: effectiveDuration,
      animations: { context in
        self.animator().alphaValue = toAlpha
        if slide != .none {
          self.animator().setFrame(toFrame, display: true)
        }
      },
      completion: callback
    )
  }
  
  // MARK: - Deprecated methods (use fade() instead)
  
  @available(*, deprecated, message: "Use fade(direction:slide:reduceMotion:callback:) instead")
  func fadeIn(
    duration: TimeInterval = 0.05, callback: (() -> Void)? = nil
  ) {
    fade(direction: .in, duration: duration, callback: callback)
  }

  @available(*, deprecated, message: "Use fade(direction:slide:reduceMotion:callback:) instead")
  func fadeOut(
    duration: TimeInterval = 0.05, callback: (() -> Void)? = nil
  ) {
    fade(direction: .out, duration: duration, callback: callback)
  }

  @available(*, deprecated, message: "Use fade(direction:slide:reduceMotion:callback:) instead")
  func fadeInAndUp(
    distance: CGFloat = 50, duration: TimeInterval = 0.125,
    callback: (() -> Void)? = nil
  ) {
    fade(direction: .in, slide: .up(distance: distance), duration: duration, callback: callback)
  }

  @available(*, deprecated, message: "Use fade(direction:slide:reduceMotion:callback:) instead")
  func fadeOutAndDown(
    distance: CGFloat = 50, duration: TimeInterval = 0.125,
    callback: (() -> Void)? = nil
  ) {
    fade(direction: .out, slide: .down(distance: distance), duration: duration, callback: callback)
  }

  /// Shake window horizontally for error feedback
  /// - Parameters:
  ///   - reduceMotion: Whether reduce motion is active (default: false)
  ///   - callback: Optional completion handler
  func shake(
    reduceMotion: Bool = false,
    callback: (() -> Void)? = nil
  ) {
    guard !reduceMotion else {
      // Alternative feedback: brief scale pulse for reduce motion users
      let savedFrame = frame
      let insetFrame = savedFrame.insetBy(dx: 2, dy: 2)
      NSAnimationContext.runAnimationGroup({ context in
        context.duration = 0.1
        animator().setFrame(insetFrame, display: true)
      }) {
        NSAnimationContext.runAnimationGroup({ context in
          context.duration = 0.1
          self.animator().setFrame(savedFrame, display: true)
        }, completionHandler: callback)
      }
      return
    }
    
    let numberOfShakes = 3
    let durationOfShake = 0.4
    let vigourOfShake = 0.03
    let frame: CGRect = self.frame
    let shakeAnimation = CAKeyframeAnimation()

    let shakePath = CGMutablePath()
    shakePath.move(to: CGPoint(x: NSMinX(frame), y: NSMinY(frame)))

    for _ in 0...numberOfShakes - 1 {
      shakePath.addLine(
        to: CGPoint(
          x: NSMinX(frame) - frame.size.width * vigourOfShake, y: NSMinY(frame))
      )
      shakePath.addLine(
        to: CGPoint(
          x: NSMinX(frame) + frame.size.width * vigourOfShake, y: NSMinY(frame))
      )
    }

    shakePath.closeSubpath()
    shakeAnimation.path = shakePath
    shakeAnimation.duration = durationOfShake

    let animations = [NSAnimatablePropertyKey("frameOrigin"): shakeAnimation]

    self.animations = animations
    animator().setFrameOrigin(NSPoint(x: frame.minX, y: frame.minY))
    
    // Call completion after shake duration
    if let callback = callback {
      DispatchQueue.main.asyncAfter(deadline: .now() + durationOfShake) {
        callback()
      }
    }
  }
}
