# Swift Animation Performance - Checklist

All items must pass.

---

## Structure
- [ ] `SKILL.md` exists with valid YAML frontmatter.
- [ ] Skill name is lowercase and hyphenated.
- [ ] `EXAMPLES.md` and `CHECKLIST.md` exist and are linked from `SKILL.md`.

## Scope
- [ ] Skill covers only animation performance and lifecycle control.
- [ ] Non-goals are explicit and enforced.

## SKILL.md quality
- [ ] Purpose is one sentence.
- [ ] "When to use" lists clear triggers.
- [ ] Workflow is numbered.
- [ ] Constraints are explicit.
- [ ] No code examples appear in `SKILL.md`.

## Implementation checks
- [ ] All SwiftUI animation calls route through the animation gate.
- [ ] Disabled animations return `nil` from the gate.
- [ ] Every repeating animation has start and stop paths.
- [ ] Repeating animations stop on `onDisappear`.
- [ ] Animated image playback avoids per-frame SwiftUI state updates.
- [ ] Reduce Motion has a stable, non-animated alternative.

## Outputs
- [ ] Findings are tied to specific animation sites.
- [ ] Recommended changes are actionable and ordered.
- [ ] Verification includes an idle CPU check when relevant.
