---
name: github-actions-appcast
description: Explain and document a GitHub Actions workflow that publishes appcast or release feeds (Sparkle-style) on push/release events, including how to port the release automation to another repository.
---

# GitHub Actions Appcast Workflow

## When to use this
Use this skill when you need to document or recreate a GitHub Actions workflow that builds and publishes an appcast (or similar release feed) for app updates. This is common for macOS apps using Sparkle.

## What this skill provides
- A clear explanation of release triggers and publishing steps.
- Guidance on required secrets, permissions, and hosting targets.
- A porting checklist for adapting to another repository.

## Steps
1. Identify workflow triggers (push, release, manual dispatch).
2. Determine whether the workflow is reusable (`uses:`) or defined inline.
3. List required permissions (e.g., `pages: write`, `id-token: write`).
4. Capture required secrets (signing keys, notarization credentials, deployment tokens).
5. Document build artifacts (zip, dmg) and feed outputs (appcast.xml).
6. Note hosting target (GitHub Pages, S3, custom server) and upload mechanism.
7. Provide a porting checklist for the target repo.

## Porting checklist
- Update trigger events and branch names.
- Confirm code signing/notarization requirements for releases.
- Replace feed URL and public keys in the app’s configuration.
- Configure hosting (Pages/S3) and permissions.
- Update artifact naming conventions and release notes flow.

## Examples
- “Document our appcast publishing workflow and how to port it.”
- “Explain the release automation that builds the update feed.”
- “How do we recreate the Sparkle appcast GitHub Actions setup?”

See [detailed appcast workflow guidance](references/DETAILS.md).
