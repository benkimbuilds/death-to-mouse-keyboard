# Stadia macOS Controller

## Goal
Build a reliable local macOS controller bridge that maps Stadia button presses to actions, with automatic profile switching by frontmost app and a strong Phase 1 profile for Ghostty.

## Why / Impact
Using the Stadia controller as a shortcut pad reduces keyboard context switching and supports a dictation-first workflow where button taps trigger common editing, terminal, and voice-assist actions.
Primary beneficiary is day-to-day development in Ghostty; secondary value is reusable per-app profiles for later expansion.
If implemented poorly, global hotkeys could fire in the wrong app and disrupt active work.

## Context
The Stadia controller is detected on this macOS machine via USB (`18d1:9400`) and appears in Apple GameController APIs as an extended gamepad profile.
This repo now contains a working Swift bridge (`src/main.swift`), launchd installers, and live mappings in `config/mappings.json`.
The desired behavior is profile-based: when the frontmost app changes, action mappings should switch automatically.
Phase 1 uses explicit profile mapping only (`ghostty` now; more app profiles later). If an app is not mapped, no action should fire.
The user often dictates commands/prompts, so button mappings should prioritize quick tap/hold actions that complement voice input.
Ghostty global startup behavior (Codex first, then fallback shell) is intentionally machine-level and lives in `~/GitHub/scripts/setup/codex/ghostty-codex-then-shell.sh` on both machines.

## Decisions
Use Swift + Apple `GameController` for controller input capture.
Use Apple AppKit/Accessibility APIs for frontmost-app awareness and action execution so behavior remains native on macOS.
Implement a single source-of-truth config layer for profile mappings (not hardcoded in multiple places).
Start with one concrete profile: `ghostty` (no global fallback profile).
Support edge-trigger (press once), hold-repeat (optional), and debounce controls per mapping.
Keep Ghostty global behavior and machine bootstrap logic in `~/GitHub/scripts`; keep controller profile/mapping logic in this repo.

## Open Questions
- None currently.

## Tasks
- [x] Scaffold Swift CLI app in `src/` with controller connection/disconnection logging and per-button event logging.
- [x] Add input event normalization layer (`button`, `state`, `timestamp`, `repeat`) so mapping logic is controller-model agnostic.
- [x] Build profile resolver that tracks frontmost app bundle identifier and selects active mapped profile (`ghostty`).
- [x] Implement mapping engine with per-action debounce, edge-trigger semantics, and optional hold behavior.
- [x] Implement action executors for: keyboard shortcuts, shell commands, optional AppleScript commands, and Ghostty native action dispatch.
- [x] Add config loader with schema validation for profile mappings in `config/mappings.json`.
- [x] Add config file watcher for hot-reload updates without restarting the bridge.
- [x] Define initial Ghostty profile for high-frequency actions (tab navigation, split/nav, command palette, etc.).
- [x] Add global safety controls: dry-run mode, per-profile enable/disable, and emergency toggle/hotkey.
- [x] Add startup/run scripts and setup notes for required permissions (Accessibility/Input Monitoring if required).
- [x] Validate end-to-end: focus Ghostty, press mapped buttons, verify expected action fires only once per press.
- [x] Validate behavior when frontmost app has no profile (bridge skips actions, no unexpected global action).
- [x] Install and validate `launchd` service on both machines using repo-local installer.
- [x] Add canonical machine-ops wrappers in `~/GitHub/scripts/setup/` so launchd install/uninstall is consolidated for both machines.
- [x] Grant Accessibility permission on second machine for staged bridge executable path (`~/Library/Application Support/stadia-controller-bridge/StadiaControllerBridge.app/Contents/MacOS/stadia-controller-bridge`).
- [x] Resolve MacBook `leftThumbstickButton` stale runtime mapping and verify it emits `keyCode=2` (split down) in live logs.
- [x] Standardize launchd label + signing identifier + staged runtime path across both machines to avoid per-machine identity drift.
- [x] Add a one-command launchd verifier script and document canonical machine-level verify usage.
- [x] Move machine-level Stadia wrappers to nested `~/GitHub/scripts/setup/stadia/` as the single canonical path (no compatibility aliases).
- [x] Simplify Ghostty control layout: `L1` tabs, `R1` split cycle, D-pad Up/Down for model picker, reserve D-pad Left/Right.
- [x] Map `X` to Ghostty split zoom toggle (maximize/restore focused split) for quick reversible focus.
- [x] Map `D-pad Left` to slash (`/`) for quick slash command entry.
- [x] Add profile-scoped analog stick controls (vertical scrolling and right-stick pointer) with deadzone/rate limiting.
- [x] Add configurable horizontal right-stick actions so the stick can be reassigned without code changes.
- [x] Add an explicit `alwaysOn` control set for selected buttons/analog behaviors that should bypass app matching without reintroducing a full fallback profile.
- [x] Differentiate Ghostty new-tab and split behavior so `share` opens the repo picker in a fresh tab while split actions keep inheriting the active directory.
- [ ] Capture Phase 2 backlog for Codex-specific profile behavior after Ghostty flow is stable.
- [x] Review `AGENTS.md` and update if new repeatable implementation patterns were introduced (stable cross-machine service identity/path now documented).
- [ ] Archive project notes to `docs/projects/archive/stadia-macos-controller/` when the user confirms completion.

## Validation / Test Plan
Run bridge locally with Stadia controller connected.
Open Ghostty and verify mapped button behavior for core flows (navigation, tab movement, command triggers).
Move focus to a non-profiled app and verify no Ghostty-specific action leaks.
Verify debounce prevents accidental double-fire during quick taps.
Verify emergency toggle immediately suppresses all mapped actions.
Run in dry-run mode first to inspect resolved profile + action logs before enabling real key/command execution.

## Progress Log
- 2026-02-26: [DONE] Created repository skeleton and initial project task tracker.
- 2026-02-26: [DONE] Added frontmost-app profile-switching architecture to the plan.
- 2026-02-26: [DONE] Re-scoped Phase 1 to Ghostty-only per user direction; Codex deferred to Phase 2.
- 2026-02-26: [DONE] Implemented first runnable Swift CLI bridge (`Package.swift`, `src/main.swift`) with controller events, profile resolution, debounce, and action execution.
- 2026-02-26: [DONE] Added starter mappings and safety defaults in `config/mappings.json` (Ghostty profile, dry-run on, emergency toggle button).
- 2026-02-26: [DONE] Added run/setup docs and script (`scripts/run-bridge.sh`, `docs/architecture/bridge-overview.md`, `docs/references/mappings-schema.md`, `docs/references/setup.md`).
- 2026-02-26: [DONE] Added robust input polling and background monitoring (`GCController.shouldMonitorBackgroundEvents=true`) to fix missing button events.
- 2026-02-26: [DONE] Added optional `codex` profile defaults (`com.openai.codex`) including `A` hold-space behavior (`holdKeystroke`) and `B` enter.
- 2026-02-26: [DONE] Implemented config hot-reload on `config/mappings.json` via file modification watch timer.
- 2026-02-26: [DONE] Added launchd automation scripts and deployment notes (`scripts/install-launchd-stadia-controller-bridge.sh`, `scripts/uninstall-launchd-stadia-controller-bridge.sh`, `docs/references/deployment.md`).
- 2026-02-26: [DONE] Installed local LaunchAgent `com.$USER.stadia-controller-bridge` and verified `launchctl` state is `running`.
- 2026-02-26: [DONE] Installed second-machine LaunchAgent over SSH (`com.adi.stadia-controller-bridge`) and verified `launchctl` state is `running`.
- 2026-02-26: [DONE] Moved Ghostty Codex startup behavior to global machine-ops repo (`~/GitHub/scripts/setup/codex/ghostty-codex-then-shell.sh`) and pointed Ghostty config on both machines to the global script path.
- 2026-02-26: [DONE] Updated `leftThumbstickButton` mapping in config to `Cmd+Shift+D` (`keyCode=2`) and synced config file on both machines.
- 2026-02-26: [DONE] Reinstalled LaunchAgent in live mode, reconnected controller, and restored stable input handling.
- 2026-02-26: [DONE] User confirmed controller bridge is working again across mapped buttons.
- 2026-02-26: [DONE] Consolidated machine-level bridge commands into `~/GitHub/scripts/setup/` wrappers and updated scheduler/health-check integration.
- 2026-02-26: [DONE] Hardened installer signing flow: auto-sign now falls back to ad-hoc on failure; machine scheduler reconciliation uses ad-hoc to avoid cross-machine cert mismatch.
- 2026-02-26: [DONE] Removed `default` profile fallback behavior from runtime/config; non-profiled apps now explicitly no-op (`[SKIP] no active app profile`).
- 2026-02-26: [DONE] Updated installer to reuse staged binary when source is unchanged (skip rebuild/re-sign) to reduce repeated Accessibility trust churn.
- 2026-02-26: [DONE] Completed staged runtime migration from loose binary to app bundle (`~/Library/Application Support/stadia-controller-bridge/StadiaControllerBridge.app`) and signed bundle target.
- 2026-02-26: [DONE] Standardized defaults across both machines: launchd label `com.stadia-controller-bridge` and signing identifier `com.stadia-controller-bridge`.
- 2026-02-26: [DONE] Updated setup/deployment docs and repo guardrails with the stable cross-machine naming/path policy.
- 2026-02-26: [DONE] Added `scripts/verify-launchd-stadia-controller-bridge.sh` and documented wrapper usage via `~/GitHub/scripts/setup/stadia/verify-launchd-stadia-controller-bridge.sh`.
- 2026-02-26: [DONE] Reorganized machine-ops Stadia wrappers under `~/GitHub/scripts/setup/stadia/` as the only supported path to keep `setup/` root clean.
- 2026-02-26: [DONE] Re-verified launchd wiring on both MacBook and Mac mini (`scripts/verify-launchd-stadia-controller-bridge.sh`: PASS on both machines).
- 2026-02-26: [DONE] Updated Ghostty mappings per user preference: shoulders now split role by context (`L1` tabs, `R1` splits), D-pad Up/Down now handles model picker, and `X/Y` plus D-pad Left/Right are reserved.
- 2026-02-26: [DONE] Mapped `X` to Ghostty split zoom toggle (`toggle_split_zoom` via `Cmd+Shift+Enter`) and documented rationale.
- 2026-02-28: [DONE] Updated Ghostty mapping: swapped `L1/R1` roles and mapped `D-pad Right` to `Cmd+Shift+G`.
- 2026-02-28: [DONE] Documented known limitation: `home` (Assistant) may not emit in macOS `GameController` even when `menu`/`options`/`share` emit; treat as unavailable unless runtime logs confirm `button=home`.
- 2026-02-28: [DONE] Added profile-level analog stick controls with deadzone/speed/rate controls; active Ghostty default now uses `leftStickVerticalScroll` for scrolling and `rightStickPointer` for cursor movement.
- 2026-03-03: [DONE] Corrected `dpadLeft` mapping to send slash (`keyCode=44`) and updated Ghostty layout rationale.
- 2026-03-11: [DONE] Added configurable horizontal analog actions for the right stick; attempted default workspace switching via `Control` + left/right arrow was disabled after live validation showed macOS ignored synthetic Space-switch key events on this machine.
- 2026-03-11: [DONE] Remapped `L2` to held `Command` and `X` to `Tab` as a lower-risk `Cmd+Tab` experiment using a discrete button chord instead of the right stick.
- 2026-03-11: [DONE] Added a top-level `alwaysOn` config section so `L2`, `X`, `R2`, and left-stick vertical scroll can remain active across apps while the rest of the layout stays explicitly app-scoped.
- 2026-03-11: [DONE] Moved the D-pad to explicit always-on arrow-key navigation and removed the Ghostty-specific D-pad overrides for model picker and punctuation.
- 2026-03-11: [DONE] Added native `mouseClick` action support, tested left thumbstick click as an always-on left mouse click, then removed that mapping after live use showed click-plus-scroll on the same stick felt noisy.
- 2026-03-11: [DONE] Reassigned Ghostty right-stick horizontal tilt from the failed macOS Spaces experiment to punctuation shortcuts: `Left` sends `/`, `Right` sends `$`.
- 2026-03-12: [DONE] Switched Ghostty `share` from plain `Cmd+T` injection to Ghostty `1.3.0` AppleScript `new tab` with a custom surface configuration so new tabs launch `codex_jump` immediately, while split actions keep their inherited working directory behavior.
- 2026-03-12: [DONE] Added a dedicated `ghosttyAction` action type and migrated the obvious Ghostty-first controls (`Options`, right thumbstick click, `L1`, `R1`) away from macOS keystroke injection to Ghostty native actions.
- 2026-03-12: [DONE] Added discrete right-stick vertical actions and moved `/model` from the `menu` button to right-stick up so the Codex-specific prompt lives on the analog stick instead of a dedicated face/menu control.
- 2026-03-12: [DONE] Refreshed architecture docs to explain the Ghostty boundary more clearly and documented the intentional AppleScript dependency plus the reinstall requirement for runtime/schema changes.

## Next 3 Actions
1. Capture Phase 2 backlog for Codex-specific profile behavior now that Ghostty flow is stable.
2. Archive project notes to `docs/projects/archive/stadia-macos-controller/` once user confirms project completion.
3. Keep troubleshooting notes in `docs/references/setup.md` and `docs/references/deployment.md` current when recovery steps change.
