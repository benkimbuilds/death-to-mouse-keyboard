# Mapping Config Reference

The bridge config lives at `config/mappings.json`.

## Top-level fields
- `appProfiles` (`object<string,string>`): map macOS bundle ID -> profile name.
- `alwaysOn` (`AlwaysOnConfig`, optional): explicit controls that bypass frontmost-app matching and remain active across apps.
- `profiles` (`object<string, ProfileConfig>`): named profile definitions.
- `safety` (`SafetyConfig`): runtime safety defaults.

Behavior note:
- The bridge does not use a global fallback profile.
- `alwaysOn` is not a fallback profile. It is a narrow explicit list of controls that always remain active.
- If the frontmost app bundle ID is not present in `appProfiles`, only controls listed in `alwaysOn` can still fire.

## AlwaysOnConfig
- `analog` (`AnalogConfig`, optional): analog-axis behaviors that stay active across apps.
- `mappings` (`object<string, MappingConfig>`, optional): button mappings that stay active across apps.

## ProfileConfig
- `enabled` (`bool`, optional, default `true`): disable an entire profile.
- `analog` (`AnalogConfig`, optional): analog-axis behaviors for this profile.
- `mappings` (`object<string, MappingConfig>`): button name -> mapping.

## AnalogConfig
- `leftStickVerticalScroll` (`StickVerticalScrollConfig`, optional): map left stick `Y` axis to vertical scrolling.
- `leftStickVerticalActions` (`StickVerticalActionConfig`, optional): map left stick `Y` tilt into up/down discrete actions.
- `leftStickHorizontalActions` (`StickHorizontalActionConfig`, optional): map left stick `X` tilt into left/right discrete actions.
- `rightStickVerticalScroll` (`StickVerticalScrollConfig`, optional): map right stick `Y` axis to vertical scrolling.
- `rightStickPointer` (`StickPointerConfig`, optional): map right stick `X/Y` axes to mouse pointer movement.
- `rightStickVerticalActions` (`StickVerticalActionConfig`, optional): map right stick `Y` tilt into up/down discrete actions.
- `rightStickHorizontalActions` (`StickHorizontalActionConfig`, optional): map right stick `X` tilt into left/right discrete actions.

## StickVerticalScrollConfig
- `enabled` (`bool`, optional, default `true`)
- `deadzone` (`double`, optional, default `0.22`): ignore small stick drift (`>= 0`, `< 1`).
- `intervalMs` (`int`, optional, default `45`): minimum time between scroll ticks.
- `minLinesPerTick` (`int`, optional, default `1`): slowest scroll step when just outside deadzone.
- `maxLinesPerTick` (`int`, optional, default `8`): fastest scroll step at full tilt.
- `responseExponent` (`double`, optional, default `1.8`): acceleration curve shape (`> 1` is smoother/finer near center, `< 1` is more aggressive).
- `invert` (`bool`, optional, default `false`): invert axis direction.

## StickPointerConfig
- `enabled` (`bool`, optional, default `true`)
- `deadzone` (`double`, optional, default `0.16`): ignore small right-stick drift (`>= 0`, `< 1`).
- `intervalMs` (`int`, optional, default `16`): minimum time between pointer move ticks.
- `minPixelsPerTick` (`int`, optional, default `1`): slowest pointer step outside deadzone.
- `maxPixelsPerTick` (`int`, optional, default `24`): fastest pointer step at full tilt.
- `responseExponent` (`double`, optional, default `1.6`): acceleration curve (`> 1` gives finer center control).
- `invertX` (`bool`, optional, default `false`): invert horizontal direction.
- `invertY` (`bool`, optional, default `false`): invert vertical direction.

## StickHorizontalActionConfig
- `enabled` (`bool`, optional, default `true`)
- `deadzone` (`double`, optional, default `0.58`): ignore small horizontal stick drift (`>= 0`, `< 1`).
- `repeatIntervalMs` (`int`, optional, default `260`): minimum interval between repeated triggers while the stick stays held past the deadzone.
- `edgeTrigger` (`bool`, optional, default `true`): when true, fire once per fresh tilt and require returning to center before triggering again.
- `leftAction` (`ActionConfig`, required): action to execute when the right stick tilts left past the deadzone.
- `rightAction` (`ActionConfig`, required): action to execute when the right stick tilts right past the deadzone.

## StickVerticalActionConfig
- `enabled` (`bool`, optional, default `true`)
- `deadzone` (`double`, optional, default `0.58`): ignore small vertical stick drift (`>= 0`, `< 1`).
- `repeatIntervalMs` (`int`, optional, default `260`): minimum interval between repeated triggers while the stick stays held past the deadzone.
- `edgeTrigger` (`bool`, optional, default `true`): when true, fire once per fresh tilt and require returning to center before triggering again.
- `upAction` (`ActionConfig`, optional): action to execute when the right stick tilts up past the deadzone.
- `downAction` (`ActionConfig`, optional): action to execute when the right stick tilts down past the deadzone.
- At least one of `upAction` or `downAction` is required when the config is present.

## MappingConfig
- `debounceMs` (`int`, optional): minimum interval between triggers.
- `edgeTrigger` (`bool`, optional, default `true`): when true, only fire on initial press.
- `action` (`ActionConfig`): action to execute.

## ActionConfig
- `type` (`"keystroke" | "holdKeystroke" | "focusApp" | "shell" | "applescript" | "ghosttyAction" | "text" | "mouseClick"`)
- Keystroke fields:
  - `keyCode` (`int`, required)
  - `modifiers` (`string[]`, optional)
  - `postKeyCode` (`int`, optional): second keystroke to send after the main keystroke.
  - `postModifiers` (`string[]`, optional): modifiers for `postKeyCode`.
  - `postDelayMs` (`int`, optional): delay after the main keystroke and before `postKeyCode`.
- Hold keystroke fields:
  - `keyCode` (`int`, required)
  - `modifiers` (`string[]`, optional)
  - Behavior: key down on button press, key up on button release, with synthetic auto-repeat while held for non-modifier keys.
- Focus app fields:
  - `bundleID` (`string`, required): bundle identifier of the running app whose active window should be focused.
- Shell fields:
  - `command` (`string`, required)
- AppleScript fields:
  - `script` (`string`, required)
- Ghostty native action fields:
  - `ghosttyAction` (`string`, required): Ghostty action string executed through Ghostty's native macOS AppleScript bridge against the focused terminal in the selected tab of the front window.
- Text fields:
  - `text` (`string`, required)
  - `preKeyCode` (`int`, optional): keystroke to send before typing text.
  - `preModifiers` (`string[]`, optional): modifiers for `preKeyCode`.
  - `preDelayMs` (`int`, optional): delay after pre-keystroke and before typing text.
  - `pressEnter` (`bool`, optional): if true, press Enter after typing text.
  - `delayMs` (`int`, optional): delay between typing text and Enter.
- Mouse click fields:
  - `mouseButton` (`"left" | "right" | "center"`, optional, default `"left"`)
- Optional shared field:
  - `description` (`string`)

## SafetyConfig
- `dryRun` (`bool`): if true, print actions without executing.
- `emergencyToggleButton` (`string`, optional): pressing this button toggles bridge enablement.

## Known Button Names
- `a`, `b`, `x`, `y`
- `leftShoulder`, `rightShoulder`
- `leftTrigger`, `rightTrigger`
- `dpadUp`, `dpadDown`, `dpadLeft`, `dpadRight`
- `menu`, `options`
- `home`, `share` (Assistant/Capture on Stadia controller)
- `leftThumbstickButton`, `rightThumbstickButton`
- `thumbsticksBoth` (virtual combo fired when both thumbstick buttons are pressed together)

Availability note:
- A button name can be valid in config but never emit events at runtime if macOS does not expose that physical control via `GameController` for the current device/connection mode.
- On Stadia controllers specifically, `home` (Assistant) may be unavailable even when `menu`/`options`/`share` are available.
