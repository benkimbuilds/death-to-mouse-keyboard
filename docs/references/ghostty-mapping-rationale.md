# Ghostty Mapping Rationale (Controller)

## Goal
Reduce cognitive load while using dictation + controller together by making button roles easy to remember.

## Layout Decisions
- `L1` (`leftShoulder`): split-focus cycle only (within current tab, `goto_split:next` / `Cmd+]`).
- `R1` (`rightShoulder`): tab cycle only.
- `Options`: close focused split only (`close_surface` / `Cmd+W`), not whole tab.
- `L2` (`leftTrigger`): hold `Command` as a modifier chord.
- `X`: send `Tab`, primarily as the `L2` companion for app switching (`Cmd+Tab`).
- Left thumbstick click: intentionally unassigned for now because click-plus-scroll on the same stick felt noisy in practice.
- D-pad `Up/Down/Left/Right`: global arrow-key navigation via `alwaysOn`.
- `Y`: `Cmd+Shift+G`.

## Why This Layout
- Shoulder buttons become role-based instead of direction-based:
  - one shoulder for tabs, one shoulder for splits.
- `X` becomes a lightweight companion key instead of a destructive or layout-changing action.
- `L2` + `X` is a low-risk modifier experiment because it uses a held modifier with a discrete button, not an analog stick.
- Left thumbstick click is intentionally left unused until there is a cleaner role for it.
- The D-pad is reserved for consistent global navigation across apps.
- The right stick is currently reserved until there is a reliable, low-risk use for it on macOS.

## Notes
- `L2`, `X`, `R2`, D-pad arrows, and left-stick vertical scroll are configured in the top-level `alwaysOn` section.
- Mapping changes hot-reload from `config/mappings.json`; restart is not required for config-only changes.
- If Ghostty keybindings change, update descriptions and keycodes together in `config/mappings.json`.
