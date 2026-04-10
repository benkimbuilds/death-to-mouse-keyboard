#!/usr/bin/env bash
set -euo pipefail

LABEL="com.stadia-controller-bridge"
LEGACY_LABEL="com.${USER}.stadia-controller-bridge"

declare -a LABELS_TO_REMOVE=()
if [[ "${1:-}" == "--label" ]]; then
  LABEL="${2:-}"
  LABELS_TO_REMOVE=("$LABEL")
else
  LABELS_TO_REMOVE=("$LABEL")
  if [[ "$LEGACY_LABEL" != "$LABEL" ]]; then
    LABELS_TO_REMOVE+=("$LEGACY_LABEL")
  fi
fi

DOMAIN="gui/$(id -u)"
for entry in "${LABELS_TO_REMOVE[@]}"; do
  PLIST_PATH="${HOME}/Library/LaunchAgents/${entry}.plist"
  launchctl bootout "$DOMAIN" "$PLIST_PATH" >/dev/null 2>&1 || true
  launchctl bootout "$DOMAIN/$entry" >/dev/null 2>&1 || true
  rm -f "$PLIST_PATH"
  echo "Unloaded and removed ${entry} (${PLIST_PATH})"
done
