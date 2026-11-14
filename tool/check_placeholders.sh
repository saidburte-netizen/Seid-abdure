#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
status=0

scan() {
  local pattern="$1"
  local label="$2"
  local matches
  matches="$(grep -RInE "$pattern" lib --include='*.dart' || true)"
  if [[ -n "$matches" ]]; then
    printf '%s\n%s\n' "Static check failed: $label" "$matches" >&2
    status=1
  fi
}

scan 'TODO|FIXME|coming soon|not implemented' 'unfinished markers are not allowed in lib/'
scan 'on(Pressed|Tap|Changed|Selected|Submitted|LongPress)[[:space:]]*:[[:space:]]*\([^)]*\)[[:space:]]*\{[[:space:]]*\}' 'empty interactive handlers are not allowed'

if [[ "$status" -ne 0 ]]; then
  exit "$status"
fi
echo "Static placeholder check passed."
