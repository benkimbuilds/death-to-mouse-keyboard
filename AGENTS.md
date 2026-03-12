# Stadia macOS Controller Repo Guidance

## Goal
Build a local bridge that maps Stadia controller inputs to macOS actions and app-specific shortcuts (starting with Ghostty).

## Workflow
- Keep implementation pragmatic and testable on macOS.
- Prefer native Apple frameworks first when feasible.
- Keep mappings configurable (do not hardcode behavior in multiple places).
- Keep machine-level install/reconcile entrypoints in `~/GitHub/scripts/setup/` (project repo keeps bridge code/config as source of truth).
- Use explicit app profile mapping only; do not add global fallback profile behavior unless explicitly requested.
- Run `scripts/check-fast.sh` before handoff to catch conflict markers and package parse issues.

## Documentation
- Use `docs/AGENTS.md` as the docs routing entrypoint.
- Keep architecture notes in `docs/architecture/`.
- Keep stable lookup/config details in `docs/references/`.
- Track active work in `docs/projects/stadia-macos-controller/tasks.md`.

## Correctness Guardrails
- Do not claim bridge changes are correct without validation evidence (`launchctl print gui/$(id -u)/com.stadia-controller-bridge` plus a live button press check).
- Prefer running `~/GitHub/scripts/setup/stadia/verify-launchd-stadia-controller-bridge.sh` after install/reinstall before declaring launchd wiring healthy.
- Use canonical machine-level launchd entrypoints from `~/GitHub/scripts/setup/` to avoid setup drift across machines.
- Keep launchd service identity consistent (`com.stadia-controller-bridge`) across machines; do not introduce per-machine labels unless explicitly requested.
- Keep staged runtime target consistent: `~/Library/Application Support/stadia-controller-bridge/StadiaControllerBridge.app`.
- Treat `config/mappings.json` hot reload as config-only. If a change adds a new runtime action type or config schema, reinstall the staged launchd app so launchd stops running the old binary.
