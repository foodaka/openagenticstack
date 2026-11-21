---
name: before-and-after
description: Captures before/after screenshots of web pages, elements, or iOS simulator screens and adds a PR-ready comparison table. Use on every PR that changes anything a user can see, and when the user says "before and after", "screenshot comparison", "visual diff", "PR screenshots", or "compare old and new". Accepts two URLs (file://, http://, https://) or two image paths.
allowed-tools:
  - Bash(npx @vercel/before-and-after *)
  - Bash(before-and-after *)
  - Bash(which before-and-after)
  - Bash(npm install -g @vercel/before-and-after agent-browser)
  - Bash(*/upload-and-copy.sh *)
  - Bash(xcrun simctl io booted screenshot *)
  - Bash(curl -s -o /dev/null -w *)
  - Bash(gh pr view *)
  - Bash(gh pr edit *)
  - Bash(gh repo view *)
  - Bash(which gh)
---

# Before-and-after

Vendored from [vercel-labs/before-and-after](https://github.com/vercel-labs/before-and-after) (PolyForm Shield 1.0.0, see LICENSE). openagenticstack changes three things: uploads go to a private branch of the repo by default, iOS simulator captures are supported, and evidence lives under `.artifacts/`.

> **Package:** `@vercel/before-and-after`. Never install `before-and-after` (wrong package).

## Rules

Don't:
- Switch branches or stash another task's changes. Build the baseline in its own worktree.
- Use `--full` unless the user asks for a full-page capture.
- Use the CLI's own `--markdown` upload. It posts to 0x0.st, which is public. Use `scripts/upload-and-copy.sh` instead.

Do:
- Write captures to `.artifacts/before-after/` in the worktree (gitignored).
- Capture desktop and `--mobile` for any responsive web change.
- Match viewport, signed-in state, seed data, and scroll position between the two shots. A pair that differs for unrelated reasons is not evidence.
- Reuse before shots taken earlier in the task.
- If the before state is still unclear after checking the task context, ask for it once.

## Pick the baseline

| Project type | Before | After |
|---|---|---|
| Vercel app with a PR preview | production URL (or the `main` preview) | the PR's preview URL |
| Local web app | `origin/main` built in a second worktree on another port | your worktree's dev server |
| iOS (Swift or React Native) | `origin/main` build in the simulator | your build in the same simulator |

Confirm that a dev-server port answers your worktree's process before trusting it. Several projects on this machine shift ports to avoid each other.

## Web capture

```bash
mkdir -p .artifacts/before-after
before-and-after "<before-url>" "<after-url>" -o .artifacts/before-after
before-and-after "<before-url>" "<after-url>" --mobile -o .artifacts/before-after
before-and-after url1 url2 ".hero-section" -o .artifacts/before-after     # one element
before-and-after url1 url2 ".old-card" ".new-card" -o .artifacts/before-after
```

| Flag | What it does |
|------|-------------|
| `-m, --mobile` | 375x812 viewport |
| `-t, --tablet` | 768x1024 viewport |
| `--size <WxH>` | Custom viewport |
| `-f, --full` | Full scrollable page |
| `-s, --selector` | CSS selector to capture |
| `-o, --output` | Output folder |

In containers where Chrome fails with "No usable sandbox", set `AGENT_BROWSER_ARGS="--no-sandbox"`.

### Protected Vercel previews

A 401 or 403 from a `.vercel.app` URL means Deployment Protection is on. If the project has a Protection Bypass for Automation secret in `VERCEL_AUTOMATION_BYPASS_SECRET`, append `?x-vercel-protection-bypass=$VERCEL_AUTOMATION_BYPASS_SECRET&x-vercel-set-bypass-cookie=true` to the URL. Never paste the secret into the PR body. Otherwise ask the user for the secret or capture against local servers.

## iOS capture

Use the same simulator and device type for both shots. Set the status bar so the clock and battery don't show up as a diff:

```bash
xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100
# install and launch the origin/main build, navigate to the screen
xcrun simctl io booted screenshot .artifacts/before-after/before.png
# install and launch your build, navigate to the same screen
xcrun simctl io booted screenshot .artifacts/before-after/after.png
```

If the iOS Simulator tool is available in the session, its `screenshot` action works too. Save the PNGs to the same paths.

## Upload and add to the PR

```bash
<skill-dir>/scripts/upload-and-copy.sh .artifacts/before-after/before.png .artifacts/before-after/after.png --markdown
```

Resolve `<skill-dir>` relative to this skill's folder, not the project. The default adapter, `github`, commits the images to the orphan `pr-assets` branch through the GitHub API and prints URLs that render for anyone who can read the repo. It needs an authenticated `gh` with push access. Other adapters: `IMAGE_ADAPTER=blob BLOB_UPLOAD_URL=...` for your own endpoint, `IMAGE_ADAPTER=0x0st` only for public, non-sensitive screens.

Run the script once per pair. For several pairs (desktop and mobile, or several screens), add a row label above each table.

Then put the tables in the PR body under `## Before and after`:

```bash
gh pr view --json number,body
# write the existing body plus the tables to a temp file
gh pr edit <number> --body-file /path/to/pr-body.md
```

No `gh`: print the markdown and tell the user to paste it.

## Errors

| Error | Fix |
|-------|-----|
| `command not found` | `npm install -g @vercel/before-and-after agent-browser` |
| `could not determine executable` | Use `npx @vercel/before-and-after` (full name) |
| 401/403 on .vercel.app | See "Protected Vercel previews" |
| Element not found | Check the selector exists on both pages |
| `gh api` 404 in the github adapter | `gh` can't see the repo. Run `gh repo view` and check auth |
