# Spotlight metadata for “recently used” on macOS

## Core conclusions

- Spotlight metadata is **not** tied to how a file is opened (Finder, Desktop, Dock, Spotlight).
- “Recently used” signals are **best-effort**, not guaranteed.
- **Do not** reconstruct full user behavior history from Spotlight alone.
- Use Spotlight for discovery; use **app-side tracking** for frequency.

## Primary metadata signal

**kMDItemLastUsedDate**

- Definition: date/time a file was last used.
- Updated by LaunchServices when:
  - User double-clicks a file
  - An app asks LaunchServices to open a file
- Applies regardless of open origin (Finder, Desktop, Dock, Spotlight).

Docs:
- https://developer.apple.com/documentation/coreservices/kmditemlastuseddate
- https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/SpotlightQuery/Concepts/MetadataAttributes.html

## Finder Recents behavior

- Finder’s Recents smart folder relies on Spotlight metadata.
- It primarily uses **last used/opened** rather than modification time.

Reference:
- https://discussions.apple.com/thread/255846746

## Reliability limitations

- `kMDItemLastUsedDate` may be **missing** or **stale**.
- Updates depend on:
  - file type
  - application behavior
  - OS internals
- Some apps do not notify LaunchServices correctly.
- Some file types never update “last used.”

References:
- https://forensic4cast.com/2016/10/macos-timestamps-from-extended-attributes-and-spotlight/
- https://gorban.org/2015/10/21/bug-in-os.html

## What Spotlight is good at

Reliable:
- File existence
- File name
- File type / kind
- File extension
- Last modified date
- Content indexing (many formats)

Unreliable:
- True “most frequently used”
- Accurate open counts
- Guaranteed recency ordering

## APIs

High-level (recommended):
- **NSMetadataQuery** (Foundation)
  - predicate + scope + live updates
  - https://developer.apple.com/documentation/foundation/nsmetadataquery

Low-level:
- **MDQuery / MDItem** (CoreServices)
  - https://developer.apple.com/documentation/coreservices/mdquery
  - https://developer.apple.com/documentation/coreservices/mditem

## Metadata keys of interest

- kMDItemLastUsedDate
- kMDItemContentType
- kMDItemFSName
- kMDItemPath
- kMDItemContentModificationDate

Reference list:
- https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/SpotlightQuery/Concepts/MetadataAttributes.html

## Files vs folders vs apps

Files
- Best candidate for `kMDItemLastUsedDate`, still best-effort.

Folders
- Indexed by Spotlight, but “last used” is often noisy.
- Consider ranking by modification date or project scope.

Applications
- Discoverable via Spotlight.
- “Recently used apps” ordering is not reliably available.
- NSWorkspace can list running/installed apps but does not provide MRU.
- https://developer.apple.com/documentation/appkit/nsworkspace

## Sandbox implications (Mac App Store)

- Spotlight can discover paths.
- Discovery ≠ permission to open.
- Opening files/folders requires user-granted access and security-scoped bookmarks.

## Canonical launcher ranking model

1. Pinned items (explicit user intent)
2. Launcher usage history (app-side tracking)
3. Spotlight discovery (files you didn’t know about)
4. Fallback ranking:
   - `kMDItemLastUsedDate` if present
   - else `kMDItemContentModificationDate`

## Mental model

- Spotlight = searchable catalog
- Spotlight ≠ activity log
- “Recent” from Spotlight = approximation
- “Frequent” must come from app telemetry
