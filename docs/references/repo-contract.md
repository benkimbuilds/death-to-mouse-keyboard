# Repo Contract

Use this page for repo-level commands, file map notes, and runtime contracts.

## Repo Map
- `src/main.swift`: CLI parsing, config loading and validation, frontmost-app profile resolution, action execution, controller polling, and config hot reload.
- `config/mappings.json`: source of truth for app profiles, `alwaysOn` controls, per-profile mappings, and safety defaults.
- `scripts/run-bridge.sh`: local `swift run` wrapper.
- `scripts/check-fast.sh`: fast repo validation for merge markers and Swift package manifest parsing.
- `scripts/install-launchd-bridge.sh`: project-local fallback installer for the bridge LaunchAgent.
- `scripts/verify-launchd-bridge.sh`: project-local fallback verifier for launchd wiring, staged runtime path, and signing identifier.
- `scripts/uninstall-launchd-bridge.sh`: project-local fallback cleanup for bridge LaunchAgents.
- `docs/architecture/`: subsystem shape, boundaries, and runtime flow.
- `docs/references/`: durable commands, config contracts, and operational lookup notes.

## Validation
- Run `./scripts/check-fast.sh` for repo-native fast validation on every change.
- Run `swift build` when `Package.swift`, `src/`, or runtime-facing scripts change.
- Do not claim launchd or runtime changes are healthy without both:
  - `launchctl print gui/$(id -u)/com.stadia-controller-bridge`
  - a live controller button press check against the changed behavior
- After install or reinstall work, prefer `~/GitHub/scripts/setup/stadia/verify-launchd-stadia-controller-bridge.sh`.
- If the shared machine-level wrapper is unavailable, use `./scripts/verify-launchd-bridge.sh`.

## Runtime And Install Contracts
- This repo owns bridge code and `config/mappings.json`.
- Canonical machine-level install and reconcile entrypoints live in `~/GitHub/scripts/setup/stadia/`.
- Keep the launchd label stable as `com.stadia-controller-bridge`.
- Keep the staged runtime target stable as `~/Library/Application Support/stadia-controller-bridge/StadiaControllerBridge.app`.
- Keep the signing or bundle identifier stable as `com.stadia-controller-bridge`.
- Do not introduce per-machine launchd labels or staged runtime paths unless explicitly requested.
- `config/mappings.json` hot-reloads while the bridge process is running.
- Changes that add a new runtime action type, CLI behavior, or config schema require reinstalling the staged launchd app so launchd stops running the old binary.

## Mapping Contract
- Use explicit `appProfiles` matching only.
- `alwaysOn` is an explicit cross-app control list, not a fallback profile.
- If the frontmost bundle ID is unmapped, only `alwaysOn` controls should fire.
