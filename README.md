# Stadia macOS Controller Bridge

## What This Does (Simple)
- Reads compatible game controller input on macOS.
- Runs a local bridge service.
- Converts mapped button presses into keystrokes, Ghostty native actions, or other configured actions.
- Sends those actions to Ghostty.

## Useful Command
```bash
swift run stadia-controller-bridge --config config/mappings.json --diagnose-controller
```

## Simple Flow (Mermaid)
```mermaid
flowchart TD
  C[Stadia Controller] --> B[Stadia Controller Bridge]
  B --> K[Keystroke Actions]
  K --> G[Ghostty]
```

## Profile-Aware Flow (Mermaid)
```mermaid
flowchart TD
    C[Stadia Controller]
    M[macOS GameController]
    B[Bridge Service com.stadia-controller-bridge]
    R[Profile Resolver by Frontmost App]
    G[Ghostty Profile Mappings]
    A[Keystroke Actions]
    H[Ghostty]
    S[Skip No Active Profile]

    C --> M --> B --> R
    R -->|Ghostty| G --> A --> H
    R -->|Other app| S
```
