# Appcast Workflow Documentation Guide

## Purpose
This reference expands on how to document and port a GitHub Actions workflow that generates and publishes an appcast (or release feed) for application updates.

## Key concepts to capture
- **Triggers**: Push events, release events, manual dispatch.
- **Reusable workflows**: `uses: owner/repo/.github/workflows/workflow.yml@ref` and how secrets/permissions are inherited.
- **Artifacts**: Update binaries (zip/dmg), signature files, and the appcast feed XML.
- **Hosting**: GitHub Pages, S3 buckets, or custom servers used to host the appcast feed.
- **Security**: Signing keys, public key distribution, and any notarization steps.

## Suggested documentation format
1. **Trigger summary**: which events publish updates.
2. **Workflow structure**: reusable vs. inline and the invoked path.
3. **Permissions**: required GitHub Actions permissions.
4. **Secrets and credentials**: list required secrets and their roles.
5. **Build and publish steps**: how the feed and artifacts are generated.
6. **Porting notes**: changes required in another repo (URLs, keys, artifact names).

## Example checklist items
- Set the app’s feed URL and public key to match the new host.
- Ensure signing and notarization credentials are configured.
- Confirm Pages/S3 permissions and deployment steps.
- Update release note workflows if a manual step is required.

## Common pitfalls
- Publishing to a feed URL that doesn’t match the app’s configured feed.
- Missing permissions for Pages or storage backends.
- Inconsistent artifact naming between the workflow and appcast feed.
