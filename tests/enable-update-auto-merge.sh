#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# All GitHub calls are mocked; tests never access or merge a real pull request.
cat > "$workdir/gh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$GH_MOCK_LOG"
case "$1" in
  api)
    if [[ "$GH_MOCK_SCENARIO" == api-error ]]; then
      echo "API request failed" >&2
      exit 17
    fi
    case "$GH_MOCK_SCENARIO" in
      disabled) echo false ;;
      invalid) echo null ;;
      *) echo true ;;
    esac
    ;;
  pr)
    if [[ "$GH_MOCK_SCENARIO" == merge-error ]]; then
      echo "Merge request failed" >&2
      exit 23
    fi
    ;;
  *) exit 99 ;;
esac
MOCK
chmod +x "$workdir/gh"

export PATH="$workdir:$PATH"
export GITHUB_REPOSITORY="example/repository"
export PR_URL="https://github.com/example/repository/pull/42"
export GH_MOCK_LOG="$workdir/gh.log"

for scenario in disabled enabled api-error merge-error invalid; do
  export GH_MOCK_SCENARIO="$scenario"
  : > "$GH_MOCK_LOG"
  status=0
  bash "$repo_root/scripts/enable-update-auto-merge" > "$workdir/output" 2>&1 || status=$?

  expected_status=0
  expected_calls="api repos/$GITHUB_REPOSITORY --jq .allow_auto_merge"
  case "$scenario" in
    enabled|merge-error)
      expected_calls+=$'\n'"pr merge --auto --squash $PR_URL"
      if [[ "$scenario" == merge-error ]]; then expected_status=23; fi
      ;;
    api-error) expected_status=17 ;;
    invalid) expected_status=1 ;;
  esac

  if [[ "$status" != "$expected_status" || "$(cat "$GH_MOCK_LOG")" != "$expected_calls" ]]; then
    echo "FAIL: $scenario (exit $status, expected $expected_status)" >&2
    cat "$GH_MOCK_LOG" "$workdir/output" >&2
    exit 1
  fi
  if [[ "$scenario" == disabled && "$(cat "$workdir/output")" != *"::warning::Auto-merge is disabled"* ]]; then
    echo "FAIL: disabled auto-merge must emit a warning" >&2
    exit 1
  fi
  echo "PASS: $scenario"
done
