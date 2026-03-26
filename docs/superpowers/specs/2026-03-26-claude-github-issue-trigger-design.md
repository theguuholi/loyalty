# Claude GitHub Issue Trigger — Design Spec

**Date:** 2026-03-26
**Status:** Approved

## Overview

When a repository collaborator comments `@claude` on a GitHub issue, a GitHub Actions workflow triggers Claude Code to read the issue, implement the described feature on a new branch, and open a pull request against `master` for review.

## Trigger

- **Event:** `issue_comment` (created or edited)
- **Conditions (both must be true):**
  1. Comment body contains `@claude`
  2. Commenter's `author_association` is `OWNER`, `MEMBER`, or `COLLABORATOR`
- If either condition fails, the workflow exits early with no action.

## What Claude Does

1. Receives the issue title, issue body, and triggering comment as context
2. Creates a branch named `claude/issue-{number}-{slug}` (e.g. `claude/issue-42-add-loyalty-rewards`)
3. Implements the feature described in the issue
4. Runs `mix precommit` to validate formatting, linting, security, types, and tests
5. Opens a PR against `master` referencing the issue with a summary of changes

Claude never merges. The PR goes through the normal review process.

## Implementation

**New file:** `.github/workflows/claude-issue.yml`
**Action used:** `anthropics/claude-code-action` (official Anthropic action)

### Required Permissions (workflow-level)
- `contents: write` — create branches and commits
- `pull-requests: write` — open PRs
- `issues: read` — read issue content

### Required Secret
- `ANTHROPIC_API_KEY` — set in `Settings → Secrets and variables → Actions`

## Out of Scope

- Triggering on issue creation (only comments trigger)
- Auto-merge of Claude's PRs
- Access for non-collaborators
