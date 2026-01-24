---
name: github-actions-ci
description: Explain and document a GitHub Actions CI workflow that runs on pushes/PRs (formatting, linting, tests). Use when you need to understand, port, or recreate CI checks in another repository.
---

# GitHub Actions CI Workflow

## When to use this
Use this skill when you need to document or reproduce a repository’s CI workflow that runs on push and pull request events. It’s ideal for porting a workflow that performs formatting, linting, and automated tests to another codebase.

## What this skill provides
- A concise explanation of trigger events and job structure.
- Guidance on translating job steps into another repository.
- A checklist of inputs to update (project name, schemes, test plans, tooling).

## Steps
1. Identify workflow triggers (push, pull_request, workflow_dispatch) and branch filters.
2. Enumerate all jobs and steps, including setup, dependencies, and test commands.
3. Capture required tooling (e.g., formatters, language runtimes, package managers).
4. Convert project-specific parameters (project name, scheme, destination, test plan).
5. Document outputs, artifacts, and failure conditions.
6. Provide a “porting checklist” for the target repo.

## Porting checklist
- Update trigger branches and event types.
- Adjust the runner OS (macOS, ubuntu, windows).
- Replace tooling install commands (brew/apt/npm/etc.).
- Update build/test commands and project identifiers.
- Ensure any code signing or environment flags are set for CI.

## Examples
- “Explain our CI workflow that runs on pushes and PRs and how to port it.”
- “Summarize the formatting and test jobs in our GitHub Actions CI.”
- “Help me recreate the CI checks in a new repo.”

See [detailed CI workflow guidance](references/DETAILS.md).
