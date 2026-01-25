# Leader Key Smart Recents/Frequents Plan

## Goal
Add a minimal “smart” section at the bottom of the launcher that surfaces recent or frequently used items (apps, files, folders) using macOS metadata and Leader Key telemetry. The UI should be subtle: a thin divider and a small label (optional) that does not distract from the user’s configured actions.

## Scope
- **Items:** Apps, files, folders (initially prioritize apps + files; folders as a fallback).
- **Entry count:** 1–3 items (tunable).
- **Theme coverage:** Ideally all themes; if costly, start with one theme and reuse shared rendering.

## UX / UI
- **Layout:** Existing list → thin divider → small label (“Suggested”) → 1–3 items.
- **Typography:** Smaller label, lighter color; items use existing list style.
- **Interaction:** Same selection + activation behavior as configured entries.
- **Promote action:** Provide a small affordance (e.g., plus button) to elevate a suggested item into the user’s configured launcher list.

## Data sources (from macOS Recents skill)
1. **Spotlight metadata (discovery)**
   - Use `NSMetadataQuery` scoped to user domains.
   - Prefer `kMDItemLastUsedDate`; fallback to `kMDItemContentModificationDate`.
2. **App-side telemetry (precision)**
   - Track what the user launches via Leader Key (recency + frequency).
   - Store lightweight usage counts and last-used timestamps.

## Ranking strategy
1. **Pinned/configured items** (existing list)
2. **Launcher usage history** (app-side telemetry)
3. **Spotlight recents** (best-effort)
4. **Fallback ranking**
   - Use `kMDItemLastUsedDate` if available; otherwise modification date

## Spotlight query outline
- Use `NSMetadataQuery`.
- Predicate:
  - `kMDItemContentType` in common file types + folders + apps.
  - `kMDItemLastUsedDate` exists where possible.
- Scope:
  - User home directory.
  - Optional app-specific directories (Documents, Desktop).
- Limit results to a small set; filter out duplicates and items already in user config.

## Data model additions
- **Usage history model**
  - `lastUsedDate: Date`
  - `launchCount: Int`
  - `itemType: app|file|folder`
  - `pathOrBundleID: String`
- Store in user config or separate cache (e.g., in Application Support).
- **User preference**
  - `suggestedSectionEnabled: Bool` to allow users to disable the smart section.

## Implementation plan
1. **Telemetry**
   - Log launches in the action handler.
2. **Spotlight query**
   - Add a query service for recents.
3. **Merge + rank**
   - Combine telemetry and Spotlight results.
4. **UI integration**
   - Add divider + “Suggested” label + suggested list in the launcher.
   - Add “promote to launcher” action for suggested items.
5. **Theme support**
   - Add a shared rendering path or per-theme minimal support.

## Constraints and caveats
- `kMDItemLastUsedDate` is best-effort; may be missing or stale.
- Spotlight is a catalog, not a true activity log.
- If sandboxed, file access needs user permission/security-scoped bookmarks.

## Open questions
- Which item types are most valuable for v1 (apps vs files vs folders)?
- Should the promote action be a plus button, context menu, or keyboard shortcut?

## References
- macOS recents/frequents skill: `skills/macos-recent-usage/SKILL.md` (and `skills/macos-recent-usage/references/spotlight-metadata.md`) for Spotlight metadata signals and limitations.
