# Local Setup (Phase 1)

## Prerequisites
- macOS with Xcode CLI tools installed.
- A compatible controller connected through macOS `GameController` (USB or wireless).

## Run in Dry-Run Mode (default)
```bash
swift run stadia-controller-bridge --config config/mappings.json
```

or:

```bash
./scripts/run-bridge.sh
```

## Controller Diagnostics
Use this when connecting a new controller such as a PS5 DualSense and you want to see what macOS
is actually exposing through `GameController`:

```bash
swift run stadia-controller-bridge --config config/mappings.json --diagnose-controller
```

What this prints:
- controller vendor/category on connect
- the bridge button names available for mapping
- raw `physicalInputProfile` element names from macOS
- analog telemetry for stick and trigger movement once values move past a useful threshold

PlayStation layout note:
- `a` = Cross
- `b` = Circle
- `x` = Square
- `y` = Triangle

Use the diagnostic output to confirm whether `options`, `share`, `home`, and thumbstick clicks are
present on your connection mode before editing mappings.

## Run in Live Mode
```bash
swift run stadia-controller-bridge --config config/mappings.json --no-dry-run
```

If Accessibility permission has not appeared yet, run once with prompt enabled:

```bash
swift run stadia-controller-bridge --config config/mappings.json --no-dry-run --prompt-accessibility
```

## Accessibility Permission (required for keystroke actions)
1. Open `System Settings` > `Privacy & Security` > `Accessibility`.
2. Allow this staged app executable:
   - `~/Library/Application Support/stadia-controller-bridge/StadiaControllerBridge.app/Contents/MacOS/stadia-controller-bridge`
3. Keep one stable install identity (`--sign-identity auto` default, with fallback to ad-hoc).

## Stable Names (Both Machines)
- LaunchAgent label default: `com.stadia-controller-bridge`
- Bundle identifier/signing identifier default: `com.stadia-controller-bridge`
- Staged app bundle path: `~/Library/Application Support/stadia-controller-bridge/StadiaControllerBridge.app`

## Signing Modes (Installer)
- `--sign-identity auto` (default): prefer Apple cert if available, fallback to ad-hoc.
- `--sign-identity adhoc`: always ad-hoc sign (`-`), no Apple cert dependency.
- `--sign-identity "Apple Development: ..."`: pin one explicit cert for maximum consistency.
- `--sign-identity none`: skip signing (not recommended).

## Current Starter Mapping
- App profile: `com.mitchellh.ghostty` -> `ghostty`
- Always-on controls:
  - `R2` (`rightTrigger`): hold `F12` (`holdKeystroke`)
  - `L2` (`leftTrigger`): hold `Command`
  - `X`: send `Tab` (`L2` + `X` behaves like `Cmd+Tab`)
  - Left stick `Y`: vertical scroll (analog; deadzone/rate-limited)
    - when Ghostty is frontmost, scroll is sent to Ghostty's focused terminal directly so it follows tab/split focus instead of mouse cursor position
  - D-pad `Up/Down/Left/Right`: send arrow keys
- Ghostty defaults:
  - Right stick up: open `/model` popup
  - Right stick horizontal tilt: `Left` sends `/`, `Right` sends `$`
  - `Options`: close focused split surface via Ghostty native action
  - `Share`: open a new tab and immediately launch the Codex repo picker through the shared helper script (`Ghostty` AppleScript; requires Ghostty `1.3.0+`)
  - Left thumbstick click: open a right split and immediately launch the Codex repo picker through the shared helper script
  - Right thumbstick click: split right via Ghostty native action and inherit the current directory
  - `L1` (`leftShoulder`): cycle split focus in current tab via Ghostty native action
  - `R1` (`rightShoulder`): cycle tabs (next tab) via Ghostty native action

Dictation stability note:
- Auto-submit-on-release behavior is intentionally not configured for triggers.
- Reason: dictation completion timing is asynchronous, so automatic `Enter` can submit partial/previous text.
- Recommended pattern: keep trigger and submit separate (for example, trigger on `R2`, submit with a dedicated button).

Non-profiled apps:
- If frontmost app is not mapped in `appProfiles`, only controls listed in `alwaysOn` still execute.
- All other controls log `[SKIP] no active app profile`.

If your Ghostty split binding differs, edit `config/mappings.json`.
For design intent behind the current layout, see `docs/references/ghostty-mapping-rationale.md`.
If Ghostty AppleScript is disabled or you are on Ghostty older than `1.3.0`, the `share` mapping must be changed back to a plain keystroke or another supported action type.

## Hot Reload
- `config/mappings.json` is watched while the bridge is running.
- Save changes to mappings and the process reloads automatically.
- Code changes still require a process restart.
- Runtime/config-schema changes also require reinstalling the staged launchd app so launchd stops running the old binary:
  - `~/GitHub/scripts/setup/stadia/install-launchd-stadia-controller-bridge.sh --mode live`

## Ghostty AppleScript Note
- This repo intentionally builds part of the Ghostty flow on top of Ghostty's native AppleScript support.
- Current AppleScript usage is narrow:
  - `Share` creates a new tab with custom startup behavior and immediately runs `codex_jump`.
  - Left thumbstick click creates a right split with custom startup behavior and immediately runs `codex_jump`.
  - `ghosttyAction` dispatches Ghostty-native terminal actions through Ghostty's AppleScript bridge.
- Ghostty marks AppleScript as a preview API in `1.3.x`, but this is currently the cleanest way to express tab-level startup behavior and has been validated in live use.

## Launchd Service (optional)
Install as a user LaunchAgent:

```bash
cd ~/GitHub/scripts
./setup/stadia/install-launchd-stadia-controller-bridge.sh --mode live
```

Uninstall:

```bash
cd ~/GitHub/scripts
./setup/stadia/uninstall-launchd-stadia-controller-bridge.sh
```

Verify:

```bash
cd ~/GitHub/scripts
./setup/stadia/verify-launchd-stadia-controller-bridge.sh
```

## Troubleshooting (Recurring Issues)
- Symptom: controller events appear in logs but no actions fire.
  - Cause: Accessibility trust missing for staged app executable.
  - Fix: re-enable `~/Library/Application Support/stadia-controller-bridge/StadiaControllerBridge.app/Contents/MacOS/stadia-controller-bridge` in Accessibility.
- Symptom: `menu`/`options`/`share` events appear, but `home` never appears in logs even after repeated presses.
  - Cause: likely input exposure limitation for current controller mode/connection; some APIs do not surface Assistant/Home on Stadia.
  - Fix: treat `home` as unavailable on that setup; map other confirmed buttons instead.
  - Quick check:
    - `rg -n "button=home|button=share|button=menu|button=options" ~/Library/Logs/stadia-controller-bridge.launchd.out.log -S`
- Symptom: worked earlier, then broke right after reinstall.
  - Cause: signing identity changed, or app executable was unnecessarily rebuilt/re-signed.
  - Fix: reinstall with stable signing:
    - `cd ~/GitHub/scripts && ./setup/stadia/install-launchd-stadia-controller-bridge.sh --mode live`
- Fast status checks:
  - `launchctl print gui/$(id -u)/com.stadia-controller-bridge | sed -n '1,90p'`
  - `tail -n 120 ~/Library/Logs/stadia-controller-bridge.launchd.out.log`

External context:
- Google Chrome team notes Stadia Assistant/Capture are outside the standard gamepad set and need lower-level access (`WebHID`) in browsers: https://developer.chrome.com/blog/stadia
