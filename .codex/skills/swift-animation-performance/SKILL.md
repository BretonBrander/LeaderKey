---
name: swift-animation-performance
description: Optimize SwiftUI and AppKit animation performance and lifecycle management; use when adding, refactoring, or reviewing animations, repeating effects, hover/selection states, or animated image playback in Swift projects.
version: 1.0.0
tags: [swift, swiftui, appkit, animation, performance]
---

# Swift Animation Performance

## Purpose
Keep SwiftUI and AppKit animations performant and controllable by centralizing configuration and managing lifecycle.

## When to use
- Add new animations in SwiftUI or AppKit.
- Refactor existing animations for performance or battery life.
- Diagnose idle CPU spikes, repeated wakeups, or animation glitches.
- Implement repeating effects, hover/selection states, or animated image playback.

## Non-goals
- Do not design new animation styles or visual polish.
- Do not optimize unrelated rendering or data pipelines.
- Do not change business logic unrelated to animation behavior.

## Inputs
- Animation entry points and call sites in the codebase.
- App setting or flag that enables or disables animations.
- Reduce Motion behavior requirements.
- Performance symptoms or measurements if available.

## Outputs
- A response with 3 sections: Findings, Recommended changes, Verification.
- Findings: 0 to 5 bullets, each tied to a specific animation site.
- Recommended changes: numbered steps, each actionable.
- Verification: 1 to 3 checks, including an idle CPU check if applicable.

## Constraints (hard rules)
- Route SwiftUI animations through a centralized helper; do not call `withAnimation` or `.animation` directly.
- Return `nil` for disabled animations to avoid transaction setup.
- Give repeating animations explicit start and stop; always stop in `onDisappear`.
- Guard against duplicate starts for repeating animations.
- Prefer finite animations; replace continuous glows with short, triggered effects when possible.
- Animate GPU-friendly properties (`opacity`, `scale`, `offset`, `transform`) instead of recomputing complex view content.
- For animated image playback, avoid per-frame SwiftUI state updates; prefer view or layer playback that runs independently.
- Respect Reduce Motion; provide a non-animated alternative.

## Workflow
1. Inventory animation usage; search for `withAnimation`, `.animation`, `.repeatForever`, `NSAnimationContext`, and `animator()`.
2. Create or locate a centralized animation gate and preset definitions.
3. Route all animation calls through the gate and remove direct calls.
4. Add lifecycle control to repeating animations and prevent duplicate starts.
5. Replace expensive animated properties with `opacity` or transforms.
6. Validate behavior with animations enabled and disabled; record idle CPU.

## Edge cases
- Views reused in `TabView`, `NavigationStack`, or hidden containers.
- Multiple `onAppear` triggers for the same view instance.
- Animations started by async events or timers.
- Animated image views that update SwiftUI state per frame.

## Failure modes
- Repeating animations continue off-screen.
- Animation starts accumulate on every state change.
- Idle CPU remains high when animations are disabled.
- Animated images drive constant view re-rendering.

## Success criteria
- No repeating animation runs without a stop path.
- Centralized animation gate is used for all SwiftUI animations.
- Reduce Motion produces a stable, non-animated UI state.
- Idle CPU is stable and low for the current workload.

## Supporting files
- [EXAMPLES.md](EXAMPLES.md)
- [CHECKLIST.md](CHECKLIST.md)
