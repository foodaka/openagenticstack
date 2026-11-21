---
name: patrol
description: Run Bugpatrol as the test step for every change that touches runtime behavior, before and after opening a PR. Use when proving a fix or feature works, when a PR needs a test report, when CI's Bugpatrol check fails, or when setting Bugpatrol up in a repo. Covers web, iOS, Android, API, and CLI apps.
---

# Patrol

Bugpatrol ([agent-labs-dev/bugpatrol](https://github.com/agent-labs-dev/bugpatrol), Apache-2.0) is the test runner for openagenticstack. It has two halves, and they do different jobs:

- **The gate** (`bugpatrol run`, web only) replays frozen routines and compares them with pinned baselines. No model, same result on the same commit. It is the only thing that fails a merge.
- **The agents** (`explore`, `judge`, `review`) drive the app like a tester, file findings, and comment on PRs. They never block a merge.

Keep the project's own unit tests (`npm test`, `jest`, `xcodebuild test`). Bugpatrol tests the running app on top of them, it does not replace them.

The upstream `bugpatrol` skill (`npx skills add agent-labs-dev/bugpatrol`) has the full setup guide. Load it when doing first-time setup or anything this file doesn't cover.

## Prerequisites

- Node 22+, `git` with an `origin` remote, authenticated `gh`.
- Web: `PLAYWRIGHT_SKIP_BROWSER_GC=1 npx -y -p bugpatrol@latest playwright install chromium`
- iOS: Xcode, a booted simulator, and [Maestro](https://maestro.mobile.dev). Android: SDK, a running emulator, and Maestro.
- A model. Locally the agents use the `claude` CLI already on PATH. CI needs `ANTHROPIC_API_KEY` (or `OPENROUTER_API_KEY` / `AI_GATEWAY_API_KEY`) as a repo secret.

Run `npx bugpatrol doctor` (add `--gate` for the gate) and fix what it reports before anything else.

## First-time setup in a repo

1. `npx bugpatrol init --yes`. Then compare `.bugpatrol/bugpatrol.yml` with the openagenticstack template for the platform (`templates/.bugpatrol/` in the openagenticstack repo) and fill each TODO.
2. Write `.bugpatrol/instructions.md`: how to sign in with test credentials, which screens matter, and a never-do list (real payments, sending real email or WhatsApp, deleting shared data).
3. Put test credentials in env vars and list their names under `app.secrets`. Never use production credentials. For apps that hit Stripe, put checkout routes in `app.connect.deny`.
4. Web only: `npx bugpatrol init --gate`, fix the TODOs, then `npx bugpatrol run --no-models` twice. The first run captures baselines, the second must come back clean. Commit the baselines.
5. `npx bugpatrol explore --steps 60` once to build the app map. Commit `.bugpatrol/appmap.json` and `.bugpatrol/routines/`. `.bugpatrol/runs/` stays gitignored.
6. Copy `templates/.github/workflows/bugpatrol.yml` into `.github/workflows/` and add the model key secret.

## During a task

Before the fix, reproduce the bug: `npx bugpatrol explore --goal "<the bug, in one sentence>" --steps 40`, then `npx bugpatrol judge`. Note the issue id. This is the "before" evidence.

After the fix:

```bash
npx bugpatrol retest --issue <id>              # bug fixes: proves the issue is gone
npx bugpatrol explore --goal "<what changed>" --steps 40 && npx bugpatrol judge   # features
npx bugpatrol run --no-models                  # web: the gate must exit 0
```

Gate exit codes: 0 clean, 1 regression (blocks), 2 config error, 3 app model not approved, 4 incomplete. Treat 4 as "not tested", never as a pass. If a visual change is intended, update the baseline in the same PR and say so in the PR body.

## After opening the PR

CI runs `bugpatrol review` on the PR. It posts one comment (edited on each push) with a verdict per finding: Introduced, Already on the base branch, Could not compare, or Not a bug. To run it yourself first: `npx bugpatrol review <pr> --dry-run` writes the report locally without posting.

- Fix every **Introduced** finding, or explain in the PR why it isn't a bug.
- Note **Already on the base branch** findings in the PR body as follow-ups. Don't fix them in this PR.
- Turn on `agents.review.claims: true` so the review also tests what the PR body claims. That pairs well with the before/after table.

## Reporting

In the PR body under `## Tests`, list each command you ran and its result (exit code, issue ids, gate status). Link the Bugpatrol PR comment. Say what wasn't covered, for example "iOS not run, no simulator on CI".

## Don't

- Don't run `npx bugpatrol` with no arguments in CI. It's a long-running patrol. Use `review`, `run`, or `patrol --once`.
- Don't turn on `agents.fixer` or `agents.github` without asking. They write code and open PRs.
- Don't run review on fork PRs (`--allow-fork`). Review runs PR code with the app's secrets.
- Don't point it at a production backend unless `app.readOnly` is set.
