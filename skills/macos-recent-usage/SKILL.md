---
name: macos-recent-usage
description: "Design and implement macOS recently-used or frequently-used suggestions for files, folders, and apps using Spotlight metadata, LaunchServices, and app-side usage tracking. Use when planning data sources, querying Spotlight (NSMetadataQuery/MDQuery), handling reliability limits of kMDItemLastUsedDate, or outlining a launcher-style ranking model for recents/frequents."
---

# macOS Recent Usage

## Overview

Use this skill to plan and document how to surface “recently used” and “frequently used” files, folders, and apps in a macOS app, with Spotlight as discovery and app-side tracking as the reliable usage signal.

## Workflow

### 1) Clarify the feature goal

- Identify whether the UI needs **recents**, **frequents**, or a **combined ranking**.
- Confirm which item types are in scope (files, folders, apps) and whether the UX must mirror Finder Recents.
- Capture any sandbox constraints or user-permission requirements.

### 2) Choose data sources

- Use **Spotlight metadata** as the discovery source for files/folders/apps.
- Use **app-side telemetry** to track actual usage frequency and recency when precision matters.
- Prefer **kMDItemLastUsedDate** when available; fall back to **kMDItemContentModificationDate**.

### 3) Define ranking strategy

- Default ordering: pinned items → app usage history → Spotlight recents → fallback.
- Combine signals with a weighted score if recency and frequency are both needed.
- Document any hard exclusions (e.g., file types, directories, or app bundles).

### 4) Specify the Spotlight query approach

- Use **NSMetadataQuery** for most integrations.
- Use **MDQuery/MDItem** only when low-level control is required.
- Scope queries carefully (user home, app-specific directories, or custom search scopes).

### 5) Document limitations and mitigations

- Note that **kMDItemLastUsedDate is best-effort** and can be missing or stale.
- Explain that Spotlight is a catalog, not an activity log.
- Provide fallback rules and transparency in UX copy.

## Reference material

- Read [references/spotlight-metadata.md](references/spotlight-metadata.md) for the Spotlight signals, APIs, and limitations to cite in specs or implementation notes.

## Output expectations

- Produce a concise technical plan for recents/frequents (data sources, query scopes, ranking).
- Add caveats about reliability and sandbox access requirements.
- Keep the design adaptable to both sandboxed and non-sandboxed builds.
