# Ghostty Integration

Ghostty is the main target app for this bridge. The important design choice is that the bridge now prefers Ghostty's own semantics whenever Ghostty has a first-class way to express the behavior. That keeps controller mappings aligned with what Ghostty means by tabs, splits, and focused surfaces.

```mermaid
flowchart TD
    Button[Controller Button or Stick]
    Bridge[Swift Bridge]
    Keystroke[macOS Keystroke Injection]
    GhosttyAction[Ghostty Native Action]
    AppleScript[Ghostty AppleScript]
    CodexShell[Codex Shell / codex_jump]
    Ghostty[Ghostty Terminal UI]

    Button --> Bridge
    Bridge --> Keystroke
    Bridge --> GhosttyAction
    Bridge --> AppleScript
    AppleScript --> CodexShell
    Keystroke --> Ghostty
    GhosttyAction --> Ghostty
    AppleScript --> Ghostty
```

## Current Strategy

- Use `ghosttyAction` when Ghostty already has a first-class terminal action.
- Use Ghostty AppleScript when a controller action needs richer tab startup behavior.
- Keep plain keystrokes only for actions that are really just terminal input, not Ghostty structure.

## What Uses What Today

- Ghostty native actions:
  - `Options` -> `close_surface`
  - right thumbstick click -> `new_split:right`
  - `L1` -> `goto_split:next`
  - `R1` -> `next_tab`
- Ghostty AppleScript:
  - `Share` -> open a new tab with custom startup config and immediately run `codex_jump`
- Plain terminal input:
  - `A` -> `Enter`
  - `B` -> `Escape`
  - `Y` -> current-terminal jump picker
  - right stick up -> `/model`
  - right stick left/right -> `/` and `$`

## Why AppleScript Is Acceptable Here

Ghostty `1.3.x` exposes a preview AppleScript API on macOS. This repo intentionally builds on top of that API for the new-tab flow because Ghostty's first-class actions are not enough for "open a new tab, disable normal autostart in that tab, and immediately run the repo picker." That is a real tab-construction problem, not just a shortcut problem.

The tradeoff is acceptable here because:

- the behavior works in live use
- it is narrow in scope
- the bridge keeps simple actions on Ghostty-native actions instead of moving everything to AppleScript

## Operational Note

- Config-only Ghostty mapping changes can hot-reload.
- Any change that adds a new runtime action type or config shape requires reinstalling the staged launchd app:
  - `~/GitHub/scripts/setup/stadia/install-launchd-stadia-controller-bridge.sh --mode live`

## Related Docs

- `docs/architecture/bridge-overview.md`
- `docs/references/setup.md`
- `docs/references/mappings-schema.md`
- `docs/references/ghostty-mapping-rationale.md`
