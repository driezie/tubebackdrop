#!/usr/bin/env bash
# Trigger GitHub Actions "Deploy release" (bump App/project.yml, tag v*, Release macOS).
# Requires: gh CLI, auth with repo + workflow scope, default branch pushed.
set -eo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WATCH=1
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-watch) WATCH=0; shift ;;
    -h|--help) HELP=1; shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]}"

REPO="${DEPLOY_REPO:-}"
if [[ -z "$REPO" ]]; then
  ORIGIN_URL=$(git remote get-url origin 2>/dev/null || true)
  REPO=$(echo "$ORIGIN_URL" | sed -E 's#.*github\.com[:/]([^/]+)/([^/.]+)(\.git)?$#\1/\2#')
fi
if [[ -z "$REPO" || "$REPO" == "$ORIGIN_URL" ]]; then
  echo "Could not parse owner/repo from git remote origin." >&2
  echo "Set DEPLOY_REPO=owner/repo or fix origin URL." >&2
  exit 1
fi

usage() {
  echo "Usage: $0 [--no-watch] patch|minor|major" >&2
  echo "       $0 [--no-watch] set X.Y.Z     # exact MARKETING_VERSION" >&2
  echo "Env: DEPLOY_REPO=owner/repo to override auto-detected repo." >&2
  echo "     NO_WATCH=1 same as --no-watch" >&2
  exit "${1:-1}"
}

[[ -n "${HELP:-}" ]] && usage 0

if [[ "${NO_WATCH:-}" == 1 ]]; then
  WATCH=0
fi

cmd="${1:-patch}"
trigger() {
  if [[ "$cmd" == set ]]; then
    [[ -n "${2:-}" ]] || usage
    gh workflow run deploy-release.yml --repo "$REPO" -f bump=patch -f exact_version="$2"
    echo "Triggered Deploy release: exact version $2 → $REPO"
  else
    case "$cmd" in
      patch|minor|major)
        gh workflow run deploy-release.yml --repo "$REPO" -f bump="$cmd"
        echo "Triggered Deploy release: bump $cmd → $REPO"
        ;;
      *) usage ;;
    esac
  fi
}

wait_for_run_id() {
  local i run_id
  echo "" >&2
  echo -n "Waiting for workflow run to appear" >&2
  for i in $(seq 1 45); do
    run_id=$(gh run list --workflow=deploy-release.yml --repo "$REPO" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)
    if [[ -n "$run_id" && "$run_id" != "null" ]]; then
      echo "" >&2
      echo "Run ID: $run_id" >&2
      printf '%s\n' "$run_id"
      return 0
    fi
    echo -n "." >&2
    sleep 1
  done
  echo "" >&2
  return 1
}

watch_macos_followup() {
  local i line mac_id mac_status
  echo "" >&2
  echo -n "Waiting for Release macOS (after tag push)" >&2
  for i in $(seq 1 90); do
    line=$(gh run list --workflow=release-macos.yml --repo "$REPO" --limit 1 --json databaseId,status --jq '.[0] | "\(.databaseId) \(.status)"' 2>/dev/null || true)
    mac_id="${line%% *}"
    mac_status="${line#* }"
    if [[ -n "$mac_id" && "$mac_id" != "null" && ( "$mac_status" == "queued" || "$mac_status" == "in_progress" || "$mac_status" == "waiting" ) ]]; then
      echo "" >&2
      echo "Watching Release macOS run $mac_id ($mac_status)…" >&2
      gh run watch "$mac_id" --repo "$REPO" --exit-status
      return $?
    fi
    echo -n "." >&2
    sleep 2
  done
  echo "" >&2
  echo "Release macOS did not start in time; check https://github.com/$REPO/actions" >&2
  return 0
}

trigger

if [[ "$WATCH" != 1 ]]; then
  echo ""
  echo "Watch: gh run list --workflow=deploy-release.yml --repo $REPO -L 3"
  exit 0
fi

if ! RUN_ID=$(wait_for_run_id); then
  echo "Could not find a run. Open https://github.com/$REPO/actions" >&2
  exit 1
fi

echo "" >&2
echo "Watching Deploy release (live logs; Ctrl+C stops watching, run continues on GitHub)…" >&2
gh run watch "$RUN_ID" --repo "$REPO" --exit-status

echo ""
watch_macos_followup || true

echo "" >&2
echo "Done. https://github.com/$REPO/actions" >&2
