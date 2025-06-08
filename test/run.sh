#!/usr/bin/env bash
set -eu -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFO_FILE="$SCRIPT_DIR/INFO.md"
STATUS=0
ARGS=("$@")
FAST_MODE=0

# Extract a section from the markdown file
extract_section() {
  local heading="$1"
  awk -v h="## $heading" '
    $0 ~ h { in_section=1; next }
    /^## /     { in_section=0 }
    in_section && /^- / {
      sub(/^- /, "")
      print
    }
  ' "$INFO_FILE"
}

# Get wasi and slow test names
readarray -t WASI_NAMES < <(extract_section "Mode")
readarray -t SLOW_NAMES < <(extract_section "Slow tests")

# Parse args
FILTER_NAMES=()
for arg in "${ARGS[@]}"; do
  if [ "$arg" == "--fast" ]; then
    FAST_MODE=1
  else
    FILTER_NAMES+=("$arg")
  fi
done

should_run() {
  local name="$1"

  # Skip if slow and --fast was given
  if (( FAST_MODE )); then
    [[ " ${SLOW_NAMES[*]} " == *" $name "* ]] && return 1
  fi

  # If no filters, run all
  if [ "${#FILTER_NAMES[@]}" -eq 0 ]; then
    return 0
  fi

  # If any filter matches
  for arg in "${FILTER_NAMES[@]}"; do
    [[ "$name" == *"$arg"* ]] && return 0
  done

  return 1
}

for f in "$SCRIPT_DIR"/*.test.mo; do
  name=$(basename "$f" .test.mo)

  should_run "$name" || continue

  mode=interpreter
  [[ " ${WASI_NAMES[*]} " == *" $name "* ]] && mode=wasi

  echo mops test "$name" --mode "$mode"
  mops test "$name" --mode "$mode"
  STATUS=$(( STATUS | $? ))
done

exit $STATUS

