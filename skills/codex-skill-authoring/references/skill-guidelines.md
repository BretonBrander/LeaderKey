# Codex Skill Guidelines

## What a Codex skill is

A Codex skill is a folder with a required `SKILL.md` (Markdown + YAML frontmatter). Codex loads only the `name` and `description` on startup and loads the full file only when the skill is invoked.

## Discovery & invocation

- **Discovery paths:** repo (`.codex/skills`), user (`~/.codex/skills`), admin (`/etc/codex/skills`), and bundled system skills.
- **Invocation:**
  - **Explicit:** user mentions the skill directly (e.g., `$skill-name`).
  - **Implicit:** Codex picks the skill based on the description.

## Required SKILL.md format

Minimal valid skill:

```
---
name: my-skill
description: What this skill does and when to use it.
---

# My Skill

## When to use this
...
```

### Frontmatter constraints

- `name` is required: lowercase letters/numbers/hyphens, max 64 chars, and should match the parent folder name.
- `description` is required: max 1024 chars, should describe what the skill does and when to use it.

### Optional frontmatter fields

`license`, `compatibility`, `metadata`, and `allowed-tools` (experimental) may be used.

## Skill folder layout

```
my-skill/
  SKILL.md
  scripts/
  references/
  assets/
```

- Keep `SKILL.md` small and link to details in `references/`.
- Describe exactly when and how to run any `scripts/`.

## Best practices for trigger reliability

1. Write a strong, specific description (primary signal for implicit invocation).
2. Keep skills small and narrowly scoped to avoid overlap.
3. Include example prompts that should trigger the skill.

## Troubleshooting

If a skill does not show up:

- Verify the filename is exactly `SKILL.md`.
- Verify it lives under a supported skills path.
- Restart Codex after changes.
