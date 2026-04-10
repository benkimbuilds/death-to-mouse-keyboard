#!/usr/bin/env bash
set -euo pipefail

LABEL="com.stadia-controller-bridge"
LEGACY_LABEL="com.${USER}.stadia-controller-bridge"
DOMAIN="gui/$(id -u)"
RUNTIME_DIR="${HOME}/Library/Application Support/stadia-controller-bridge"
APP_BUNDLE_NAME="StadiaControllerBridge.app"
APP_EXECUTABLE_NAME="stadia-controller-bridge"
EXPECTED_SIGNING_IDENTIFIER="com.stadia-controller-bridge"
TAIL_LINES=120

OUT_LOG="${HOME}/Library/Logs/stadia-controller-bridge.launchd.out.log"
ERR_LOG="${HOME}/Library/Logs/stadia-controller-bridge.launchd.err.log"
EXPECTED_APP_BUNDLE="${RUNTIME_DIR}/${APP_BUNDLE_NAME}"
EXPECTED_PROGRAM="${EXPECTED_APP_BUNDLE}/Contents/MacOS/${APP_EXECUTABLE_NAME}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Verify launchd/service wiring for the Stadia controller bridge.

Options:
  --label <label>           LaunchAgent label (default: com.stadia-controller-bridge)
  --runtime-dir <path>      Runtime dir root (default: ~/Library/Application Support/stadia-controller-bridge)
  --tail-lines <n>          Log lines to scan for warnings (default: 120)
  -h, --help                Show help
USAGE
}

is_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)
      LABEL="${2:-}"
      shift 2
      ;;
    --runtime-dir)
      RUNTIME_DIR="${2:-}"
      shift 2
      ;;
    --tail-lines)
      TAIL_LINES="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! is_int "$TAIL_LINES"; then
  echo "Invalid --tail-lines: $TAIL_LINES" >&2
  exit 2
fi

EXPECTED_APP_BUNDLE="${RUNTIME_DIR}/${APP_BUNDLE_NAME}"
EXPECTED_PROGRAM="${EXPECTED_APP_BUNDLE}/Contents/MacOS/${APP_EXECUTABLE_NAME}"

fail_count=0

fail() {
  echo "FAIL: $*"
  fail_count=$((fail_count + 1))
}

note() {
  echo "OK: $*"
}

warn() {
  echo "WARN: $*"
}

echo "Verifying label: ${LABEL}"
echo "Expected program: ${EXPECTED_PROGRAM}"

if ! launch_output="$(launchctl print "${DOMAIN}/${LABEL}" 2>/dev/null)"; then
  fail "LaunchAgent is not loaded: ${DOMAIN}/${LABEL}"
else
  state_line="$(printf '%s\n' "$launch_output" | awk '/^[[:space:]]*state = / {print; exit}')"
  program_line="$(printf '%s\n' "$launch_output" | awk '/^[[:space:]]*program = / {print; exit}')"

  if [[ "$state_line" != *"state = running"* ]]; then
    fail "LaunchAgent state is not running (${state_line:-missing})"
  else
    note "LaunchAgent state is running"
  fi

  if [[ "$program_line" != *"${EXPECTED_PROGRAM}"* ]]; then
    fail "Program path mismatch (${program_line:-missing})"
  else
    note "Program path matches staged app executable"
  fi
fi

if launchctl print "${DOMAIN}/${LEGACY_LABEL}" >/dev/null 2>&1; then
  fail "Legacy per-user label is still loaded: ${LEGACY_LABEL}"
else
  note "Legacy per-user label is not loaded"
fi

if [[ ! -x "$EXPECTED_PROGRAM" ]]; then
  fail "Expected executable missing/not executable: ${EXPECTED_PROGRAM}"
else
  note "Expected executable exists"
fi

if [[ -d "$EXPECTED_APP_BUNDLE" ]]; then
  codesign_out="$(
    /usr/bin/codesign -dv --verbose=2 "$EXPECTED_APP_BUNDLE" 2>&1 || true
  )"
  identifier_line="$(printf '%s\n' "$codesign_out" | awk -F= '/^Identifier=/{print $2; exit}')"
  if [[ "$identifier_line" != "$EXPECTED_SIGNING_IDENTIFIER" ]]; then
    fail "Code-sign identifier mismatch (${identifier_line:-missing})"
  else
    note "Code-sign identifier matches ${EXPECTED_SIGNING_IDENTIFIER}"
  fi
else
  fail "Expected app bundle missing: ${EXPECTED_APP_BUNDLE}"
fi

log_chunk=""
if [[ -f "$OUT_LOG" ]]; then
  log_chunk+="$(tail -n "$TAIL_LINES" "$OUT_LOG" 2>/dev/null || true)\n"
fi
if [[ -f "$ERR_LOG" ]]; then
  log_chunk+="$(tail -n "$TAIL_LINES" "$ERR_LOG" 2>/dev/null || true)\n"
fi
if printf '%b' "$log_chunk" | grep -Eiq "accessibility permission is not granted|accessibility permission is required|keystroke injection|axisprocesstrusted"; then
  warn "Recent logs include Accessibility-related errors; if buttons fail, re-check Privacy & Security > Accessibility"
else
  note "No recent Accessibility errors found in logs"
fi

if (( fail_count > 0 )); then
  echo "RESULT: FAIL (${fail_count} checks)"
  exit 1
fi

echo "RESULT: PASS"
