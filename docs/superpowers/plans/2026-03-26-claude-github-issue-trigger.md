# Claude GitHub Issue Trigger — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a GitHub Actions workflow that triggers Claude Code to implement a feature and open a PR when a repo collaborator comments `@claude` on an issue.

**Architecture:** A single workflow file responds to `issue_comment` events, guards with a collaborator + `@claude` check, then delegates to the official `anthropics/claude-code-action` which handles branch creation, code implementation, and PR opening automatically.

**Tech Stack:** GitHub Actions, `anthropics/claude-code-action@beta`, `ANTHROPIC_API_KEY` secret

---

### Task 1: Create the Claude issue workflow

**Files:**
- Create: `.github/workflows/claude-issue.yml`

- [ ] **Step 1: Create the workflow file**

```yaml
name: Claude Issue Handler

on:
  issue_comment:
    types: [created, edited]

permissions:
  contents: write
  pull-requests: write
  issues: read

jobs:
  claude:
    name: Claude Feature Implementation
    if: |
      contains(github.event.comment.body, '@claude') &&
      (
        github.event.comment.author_association == 'OWNER' ||
        github.event.comment.author_association == 'MEMBER' ||
        github.event.comment.author_association == 'COLLABORATOR'
      )
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Claude Code Action
        uses: anthropics/claude-code-action@beta
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
```

Save this as `.github/workflows/claude-issue.yml`.

- [ ] **Step 2: Validate YAML syntax**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/claude-issue.yml'))" && echo "YAML valid"
```
Expected: `YAML valid`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/claude-issue.yml
git commit -m "feat: trigger Claude Code on @claude issue comments"
```

---

### Task 2: Add the ANTHROPIC_API_KEY secret

**Files:** None (GitHub repo settings)

- [ ] **Step 1: Add the secret in GitHub**

Go to your repository on GitHub:
`Settings → Secrets and variables → Actions → New repository secret`

- Name: `ANTHROPIC_API_KEY`
- Value: your Anthropic API key from https://console.anthropic.com/settings/keys

- [ ] **Step 2: Verify the secret appears in the list**

The secret should appear in the "Repository secrets" list as `ANTHROPIC_API_KEY`. The value will be hidden — that's expected.

---

### Task 3: Smoke test the workflow

**Files:** None

- [ ] **Step 1: Push the branch and open a test issue**

Push your branch to GitHub:
```bash
git push origin newfeat
```

Merge to `master` (or open a PR and merge it) so the workflow is active on the default branch.

- [ ] **Step 2: Create a test issue**

On GitHub, open a new issue with a simple feature request, e.g.:

> Title: Test Claude trigger
> Body: Add a `hello_world/0` function to `lib/loyalty.ex` that returns `"hello world"`.

- [ ] **Step 3: Trigger Claude**

Comment on the issue:
```
@claude please implement this
```

- [ ] **Step 4: Verify the workflow runs**

Go to `Actions` tab in GitHub. You should see "Claude Issue Handler" running. After ~1-2 minutes, Claude should have:
- Created a branch `claude/issue-{number}-...`
- Opened a PR against `master`
- Left a comment on the issue linking to the PR

- [ ] **Step 5: Review and close the test PR**

Review the opened PR. Close it without merging (it was just a smoke test).
