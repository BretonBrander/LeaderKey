---
name: codex-skill-authoring
description: Write or repair Codex skills (SKILL.md) so they follow the Agent Skills spec, have strong trigger descriptions, and use references/scripts/assets appropriately. Use when asked to create a new skill, refactor an existing skill, or diagnose why a skill is not being discovered.
---

# Codex Skill Authoring

## When to use this

- You need to create a new Codex skill folder and SKILL.md.
- You need to fix a skill that is in the wrong format or not being discovered.
- You want to improve trigger reliability (name/description, examples, scope).

## Steps

1. **Confirm skill location and name**
   - Ensure the folder lives under a supported skills path (repo `.codex/skills`, user `~/.codex/skills`, etc.).
   - Ensure the folder name matches the `name` field (lowercase, hyphenated, max 64 chars).

2. **Write compliant frontmatter**
   - Include `name` and `description` (required).
   - Keep the description specific about what the skill does and when to use it.

3. **Structure SKILL.md for progressive disclosure**
   - Keep the core doc short and action-oriented (When to use, Steps, Examples).
   - Move details into `references/` and link to them from SKILL.md.

4. **Add example prompts**
   - Include 3–5 example prompts that should trigger the skill.
   - Avoid overlapping intent with other skills.

5. **Optional helpers**
   - If needed, add deterministic scripts in `scripts/` and describe how to run them.
   - Use `assets/` for templates or schemas to keep SKILL.md lean.

## Examples

- “Create a Codex skill for onboarding a new repo.”
- “Fix this SKILL.md so it follows the Agent Skills spec.”
- “Why isn’t my skill being discovered by Codex?”

## References

- See [references/skill-guidelines.md](references/skill-guidelines.md) for required format, discovery rules, and best practices.

## Output checklist

- [ ] Skill folder name matches `name` in frontmatter.
- [ ] `description` clearly states what + when to use.
- [ ] SKILL.md has When to use, Steps, Examples.
- [ ] Supporting docs are in `references/` or `assets/` as needed.
