# Ghostty Mapping Rationale (Controller)

## Goal
Reduce cognitive load while using dictation + controller together by making button roles easy to remember.

## Layout Decisions
- `L1` (`leftShoulder`): split-focus cycle only (within current tab, `goto_split:next` / `Cmd+]`).
- `R1` (`rightShoulder`): tab cycle only.
- `Options`: close focused split only (`close_surface` / `Cmd+W`), not whole tab.
- `X`: toggle split zoom (temporary maximize/restore for focused split).
- `D-pad Up/Down`: model picker up/down.
- `D-pad Left`: send slash (`/`).
- `D-pad Right`: `Cmd+Shift+G`.
- `Y`: reverse navigation (`Shift+Tab`).

## Why This Layout
- Shoulder buttons become role-based instead of direction-based:
  - one shoulder for tabs, one shoulder for splits.
- `X` is a safe high-value action (reversible, no close/delete side effects).
- Up/down movement uses the literal directional input (D-pad), improving legibility.
- Left/right D-pad keep punctuation/navigation helpers on one cluster.

## Notes
- Mapping changes hot-reload from `config/mappings.json`; restart is not required for config-only changes.
- If Ghostty keybindings change, update descriptions and keycodes together in `config/mappings.json`.
