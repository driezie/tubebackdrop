#!/usr/bin/env bash
# Write GitHub Release body (markdown) from git history between previous tag and current ref.
# Usage: release-notes-body.sh <current_tag> <output.md>
# Env: GITHUB_REPOSITORY (owner/name) for compare links
set -eo pipefail
CURRENT="${1:?current tag e.g. v1.0.1}"
OUT="${2:?output path}"

git fetch --tags --force 2>/dev/null || true

tags=()
while IFS= read -r line; do
  [ -n "$line" ] && tags+=("$line")
done < <(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=v:refname)

PREV=""
i=0
for t in "${tags[@]}"; do
  if [[ "$t" == "$CURRENT" ]]; then
    if [ "$i" -gt 0 ]; then
      PREV="${tags[$((i - 1))]}"
    fi
    break
  fi
  i=$((i + 1))
done

REPO="${GITHUB_REPOSITORY:-}"
COMPARE=""
if [[ -n "$PREV" && -n "$REPO" ]]; then
  COMPARE="https://github.com/${REPO}/compare/${PREV}...${CURRENT}"
fi

{
  echo "## Changes in \`${CURRENT}\`"
  echo ""
  if [[ -n "$PREV" ]]; then
    if [[ -n "$COMPARE" ]]; then
      echo "Commits since [\`${PREV}\`](${COMPARE}):"
    else
      echo "Commits since \`${PREV}\`:"
    fi
    echo ""
    git log "${PREV}..${CURRENT}" --pretty=format:'- %s (`%h`)' --no-merges || true
    echo ""
    echo ""
    if [[ -n "$COMPARE" ]]; then
      echo "[Full compare](${COMPARE})"
    fi
  else
    echo "- First release for this tag (no earlier \`v*.*.*\` tag found)."
  fi
  echo ""
  echo "---"
  echo ""
  echo "**Download:** \`TubeBackdrop-*.zip\` below (macOS). Sparkle uses your Vercel \`appcast.xml\` after the appcast commit is on the default branch."
} > "$OUT"
