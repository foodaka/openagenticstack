# openagenticstack

Our agent workflow for Claude Code (and Codex or Cursor, which read `AGENTS.md`). Every PR shows before and after screenshots, every change is tested with [Bugpatrol](https://github.com/agent-labs-dev/bugpatrol), and every piece of text a person reads goes through unslop first.

It sits next to gstack, not on top of it. gstack's `/review`, `/ship`, `/qa` and `/cso` still work. openagenticstack adds the PR rules and the three skills below.

## What's in it

| Path | What it does |
|---|---|
| `AGENTS.md` | The workflow: isolate, capture before, build, prove, ship. Plus multi-agent rules. |
| `skills/before-and-after` | Before/after screenshots for web (via `@vercel/before-and-after`) and the iOS simulator. Uploads to a private `pr-assets` branch in the repo, not a public host. |
| `skills/patrol` | When and how to run Bugpatrol: reproduce, retest, gate, and PR review. |
| `skills/unslop` | Cuts AI tells from commit messages, PR bodies, docs and comments. |
| `templates/.github/workflows/bugpatrol.yml` | CI: the Bugpatrol gate (blocks on regressions) and the Bugpatrol PR review (comments). |
| `templates/.github/pull_request_template.md` | PR body with required "Before and after" and "Tests" sections. |
| `templates/.bugpatrol/` | Starter Bugpatrol configs for a Next.js + Supabase app and an iOS app. |
| `install.sh` | Installs the skills and sets up a repo. |

## Install

```bash
npm i -g @vercel/before-and-after agent-browser
./install.sh                                  # skills -> ~/.claude/skills
./install.sh --repo ~/Code/my-web-app       # plus workflow, template, CI, config
./install.sh --repo ~/Code/my-ios-app --platform ios
```

The installer never overwrites a file in the repo. It appends a marked block to `AGENTS.md` (and replaces that block on later runs), links `CLAUDE.md` to it, and adds `.worktrees/`, `.artifacts/` and `.bugpatrol/runs/` to `.gitignore`. It prints the remaining setup steps.

Also install the upstream Bugpatrol skill for first-time setup help:

```bash
npx skills add agent-labs-dev/bugpatrol
```

## Requirements

- Node 22+ and an authenticated `gh` with push access (for screenshot uploads and Bugpatrol's PR comments).
- Web: Chromium for Playwright (`PLAYWRIGHT_SKIP_BROWSER_GC=1 npx -y -p bugpatrol@latest playwright install chromium`).
- iOS: Xcode, a booted simulator and [Maestro](https://maestro.mobile.dev). Bugpatrol's iOS review in CI needs a self-hosted Mac.
- An `ANTHROPIC_API_KEY` repo secret for CI. Locally, Bugpatrol can use the `claude` CLI instead.

## Sources and licenses

| Part | Upstream | License |
|---|---|---|
| `before-and-after` | [vercel-labs/before-and-after](https://github.com/vercel-labs/before-and-after). Changed: github upload adapter as default, iOS capture, `.artifacts/` output. | PolyForm Shield 1.0.0 (in folder) |
| `unslop` | [cursor/plugins (pstack)](https://github.com/cursor/plugins/tree/main/pstack/skills/unslop). Unchanged. | MIT (in folder) |
| `AGENTS.md`, `patrol`, templates, `install.sh` | written here | yours to pick |

PolyForm Shield bars using `before-and-after` to build a product that competes with it. Using it in your own repos is fine.
