import Cocoa

extension NSWindow {
  func fadeIn(
    duration: TimeInterval = 0.05, callback: (() -> Void)? = nil
  ) {
    alphaValue = 0

    AnimationGate.runAppKitAnimation(
      duration: duration,
      animations: { animated in
        if animated {
          self.animator().alphaValue = 1
        } else {
          self.alphaValue = 1
        }
      },
      completion: {
        callback?()
      }
    )
  }

  func fadeOut(
    duration: TimeInterval = 0.05, callback: (() -> Void)? = nil
  ) {
    alphaValue = 1

    AnimationGate.runAppKitAnimation(
      duration: duration,
      animations: { animated in
        if animated {
          self.animator().alphaValue = 0
        } else {
          self.alphaValue = 0
        }
      },
      completion: {
        callback?()
      }
    )
  }

  func fadeInAndUp(
    distance: CGFloat = 50, duration: TimeInterval = 0.125,
    callback: (() -> Void)? = nil
  ) {
    let toFrame = frame
    let fromFrame = NSRect(
      x: toFrame.minX, y: toFrame.minY - distance, width: toFrame.width,
      height: toFrame.height)

    setFrame(fromFrame, display: true)
    alphaValue = 0

    AnimationGate.runAppKitAnimation(
      duration: duration,
      animations: { animated in
        if animated {
          self.animator().alphaValue = 1
          self.animator().setFrame(toFrame, display: true)
        } else {
          self.alphaValue = 1
          self.setFrame(toFrame, display: true)
        }
      },
      completion: {
        callback?()
      }
    )
  }

  func fadeOutAndDown(
    distance: CGFloat = 50, duration: TimeInterval = 0.125,
    callback: (() -> Void)? = nil
  ) {
    let fromFrame = frame
    let toFrame = NSRect(
      x: fromFrame.minX, y: fromFrame.minY - distance, width: fromFrame.width,
      height: fromFrame.height)

    setFrame(fromFrame, display: true)
    alphaValue = 1

    AnimationGate.runAppKitAnimation(
      duration: duration,
      animations: { animated in
        if animated {
          self.animator().alphaValue = 0
          self.animator().setFrame(toFrame, display: true)
        } else {
          self.alphaValue = 0
          self.setFrame(toFrame, display: true)
        }
      },
      completion: {
        callback?()
      }
    )
  }

  func shake() {
    if !AnimationGate.enableAnimations || !AnimationGate.isUIVisible
      || AnimationGate.reduceMotionSystem
    {
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
  }
}
