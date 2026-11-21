#!/bin/bash
# github adapter (openagenticstack default). Stores screenshots on an orphan branch of
# the current repo through the GitHub API, so images stay as private as the repo.
# It never touches the local checkout.
#
# Usage: ./github.sh <file>
# Output: an image URL that renders in that repo's PRs (stdout)
#
# Environment:
#   PR_ASSETS_REPO     owner/name. Default: the repo gh resolves from the cwd.
#   PR_ASSETS_BRANCH   Default: pr-assets. Never merge this branch.
#   PR_ASSETS_PREFIX   Folder inside the branch. Default: <current-branch>/<timestamp>

set -euo pipefail

FILE="${1:-}"
[[ -n "$FILE" && -f "$FILE" ]] || { echo "Usage: $0 <file>" >&2; exit 1; }
command -v gh >/dev/null || { echo "Error: gh CLI not found" >&2; exit 1; }

REPO="${PR_ASSETS_REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
BRANCH="${PR_ASSETS_BRANCH:-pr-assets}"
if [[ -z "${PR_ASSETS_PREFIX:-}" ]]; then
  CUR=$(git branch --show-current 2>/dev/null || echo detached)
  PR_ASSETS_PREFIX="${CUR//\//-}/$(date -u +%Y%m%dT%H%M%SZ)"
  export PR_ASSETS_PREFIX
fi

# Create the orphan branch on first use.
if ! gh api "repos/$REPO/git/ref/heads/$BRANCH" >/dev/null 2>&1; then
  TREE=$(gh api "repos/$REPO/git/trees" \
    -f 'tree[][path]=README.md' -f 'tree[][mode]=100644' -f 'tree[][type]=blob' \
    -f 'tree[][content]=PR screenshots uploaded by openagenticstack. Do not merge.' -q .sha)
  COMMIT=$(gh api "repos/$REPO/git/commits" -f message="Create $BRANCH" -f tree="$TREE" -q .sha)
  gh api "repos/$REPO/git/refs" -f ref="refs/heads/$BRANCH" -f sha="$COMMIT" >/dev/null
fi

DEST="$PR_ASSETS_PREFIX/$(basename "$FILE")"
BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT
printf '{"message":"Add %s","branch":"%s","content":"%s"}' \
  "$DEST" "$BRANCH" "$(base64 < "$FILE" | tr -d '\n')" > "$BODY"
gh api -X PUT "repos/$REPO/contents/$DEST" --input "$BODY" >/dev/null

# blob URL with ?raw=true renders inline for anyone who can read the repo.
echo "https://github.com/$REPO/blob/$BRANCH/$DEST?raw=true"
