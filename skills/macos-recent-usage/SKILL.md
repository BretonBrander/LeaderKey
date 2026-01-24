---
name: macos-recent-usage
description: Plan and implement macOS recents/frequents for files, folders, and apps using Spotlight metadata, LaunchServices, and app-side telemetry. Use when selecting data sources, shaping Spotlight queries, defining ranking strategies, or documenting limits like kMDItemLastUsedDate.
---

# macOS Recent Usage

## When to use this

- You need a design for “recently used” or “frequently used” items in a macOS app.
- You are deciding between Spotlight metadata, LaunchServices, or app-side tracking.
- You need to explain reliability limitations for recency signals.

## Steps

1. **Clarify the feature goal**
   - Identify whether the UI needs **recents**, **frequents**, or a **combined ranking**.
   - Confirm which item types are in scope (files, folders, apps).
   - Capture sandbox constraints or user-permission requirements.

2. **Choose data sources**
   - Use **Spotlight metadata** as the discovery source for files/folders/apps.
   - Use **app-side telemetry** to track actual usage frequency and recency when precision matters.
   - Prefer **kMDItemLastUsedDate** when available; fall back to **kMDItemContentModificationDate**.

3. **Define ranking strategy**
   - Default ordering: pinned items → app usage history → Spotlight recents → fallback.
   - Combine signals with a weighted score if recency and frequency are both needed.
   - Document any hard exclusions (file types, directories, or app bundles).

4. **Specify the Spotlight query approach**
   - Use **NSMetadataQuery** for most integrations.
   - Use **MDQuery/MDItem** only when low-level control is required.
   - Scope queries carefully (user home, app-specific directories, or custom search scopes).

5. **Document limitations and mitigations**
   - Note that **kMDItemLastUsedDate is best-effort** and can be missing or stale.
   - Explain that Spotlight is a catalog, not an activity log.
   - Provide fallback rules and transparency in UX copy.

## Examples

- “Design a recents list for a macOS launcher that merges app usage with Spotlight results.”
- “What are reliable metadata fields for recently used files on macOS?”
- “Outline a ranking model for recents vs frequents using Spotlight and telemetry.”

## References

- Read [references/spotlight-metadata.md](references/spotlight-metadata.md) for Spotlight signals, APIs, and limitations to cite in specs or implementation notes.

## Output expectations

- Produce a concise technical plan for recents/frequents (data sources, query scopes, ranking).
- Add caveats about reliability and sandbox access requirements.
- Keep the design adaptable to both sandboxed and non-sandboxed builds.
