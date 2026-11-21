#!/bin/bash
# openagenticstack installer.
#
#   ./install.sh                 install the skills to ~/.claude/skills
#   ./install.sh --repo <path>   also add the workflow, PR template and CI to a repo
#   ./install.sh --repo <path> --platform ios
#
# Never overwrites a file in the target repo. AGENTS.md gets the openagenticstack block
# appended (or replaced in place if an older block is there).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
REPO=""
PLATFORM="web"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --platform) PLATFORM="$2"; shift 2 ;;
    -h|--help) sed -n 2,10p "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
[[ "$PLATFORM" == web || "$PLATFORM" == ios ]] || { echo "--platform must be web or ios" >&2; exit 1; }

echo "== Skills -> $SKILLS_DIR"
mkdir -p "$SKILLS_DIR"
for s in "$HERE"/skills/*/; do
  name=$(basename "$s")
  rm -rf "${SKILLS_DIR:?}/$name"
  cp -R "$s" "$SKILLS_DIR/$name"
  echo "   $name"
done
chmod +x "$SKILLS_DIR"/before-and-after/scripts/*.sh "$SKILLS_DIR"/before-and-after/scripts/adapters/*.sh

[[ -z "$REPO" ]] && { echo "Done. Run with --repo <path> to set up a project."; exit 0; }

REPO="$(cd "$REPO" && pwd)"
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null
echo "== Repo $REPO ($PLATFORM)"

copy_if_absent() {  # src dest
  if [[ -e "$2" ]]; then echo "   skip ${2#$REPO/} (exists)"
  else mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "   add  ${2#$REPO/}"; fi
}

# AGENTS.md: append or refresh the openagenticstack block.
AG="$REPO/AGENTS.md"
if [[ -f "$AG" ]] && grep -q 'BEGIN:openagenticstack' "$AG"; then
  awk -v blk="$HERE/AGENTS.md" '
    /BEGIN:openagenticstack/ { while ((getline l < blk) > 0) print l; skip=1; next }
    /END:openagenticstack/   { skip=0; next }
    !skip' "$AG" > "$AG.tmp" && mv "$AG.tmp" "$AG"
  echo "   update AGENTS.md (openagenticstack block)"
else
  { [[ -f "$AG" ]] && printf '\n'; cat "$HERE/AGENTS.md"; } >> "$AG"
  echo "   append AGENTS.md"
fi

# Claude Code reads CLAUDE.md, not AGENTS.md.
CL="$REPO/CLAUDE.md"
if [[ ! -f "$CL" ]]; then echo '@AGENTS.md' > "$CL"; echo "   add  CLAUDE.md"
elif ! grep -q '@AGENTS.md' "$CL"; then printf '\n@AGENTS.md\n' >> "$CL"; echo "   link CLAUDE.md -> AGENTS.md"; fi

copy_if_absent "$HERE/templates/.github/pull_request_template.md" "$REPO/.github/pull_request_template.md"
copy_if_absent "$HERE/templates/.github/workflows/bugpatrol.yml" "$REPO/.github/workflows/bugpatrol.yml"
copy_if_absent "$HERE/templates/.bugpatrol/bugpatrol.$PLATFORM.yml" "$REPO/.bugpatrol/bugpatrol.yml"

GI="$REPO/.gitignore"
for line in '.worktrees/' '.artifacts/' '.bugpatrol/runs/'; do
  grep -qxF "$line" "$GI" 2>/dev/null || { echo "$line" >> "$GI"; echo "   gitignore $line"; }
done

cat <<EOF

Next, in $REPO:
  1. Fill the TODOs in .bugpatrol/bugpatrol.yml and write .bugpatrol/instructions.md
  2. npx bugpatrol doctor$([[ $PLATFORM == web ]] && echo ' && npx bugpatrol init --gate')
  3. Add repo secrets: ANTHROPIC_API_KEY and each name in app.secrets
  4. Fill "Checks in this repo" at the end of AGENTS.md
$([[ $PLATFORM == ios ]] && echo '  5. Delete the gate job in .github/workflows/bugpatrol.yml and point review at a self-hosted Mac')
EOF
