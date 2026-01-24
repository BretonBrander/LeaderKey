# CI Workflow Documentation Guide

## Purpose
This reference expands on how to interpret a GitHub Actions CI workflow so it can be reproduced in another repository with minimal friction.

## Key concepts to capture
- **Triggers**: Events that start the workflow (push, pull_request, workflow_dispatch) and branch filters.
- **Jobs**: Distinct units that run on a specific runner (macOS, ubuntu, windows).
- **Steps**: Ordered commands and actions within a job (checkout, dependency install, formatting, tests).
- **Environment**: Variables, secrets, permissions, and code-signing flags needed for CI reliability.
- **Artifacts**: Logs, test reports, build artifacts, or caches produced by the workflow.

## Suggested documentation format
1. **Trigger summary**: event types and branch targets.
2. **Job breakdown**: job name, runner, and step list.
3. **Tooling requirements**: formatters, test frameworks, package managers.
4. **Porting notes**: parameters that must be updated (project name, scheme, test plan, destination).
5. **Failure handling**: common failure modes or environment requirements.

## Example checklist items
- Update branch filters to match the target repo’s default branch.
- Replace `xcodebuild` or language-specific commands with equivalents.
- Confirm the runner OS supports required tooling.
- Ensure code signing is disabled when not needed in CI.

## Common pitfalls
- Missing or incompatible toolchain versions on CI runners.
- Repository-specific paths hard-coded in scripts.
- Hidden assumptions about environment variables or secrets.
