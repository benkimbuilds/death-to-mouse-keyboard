# Deployment (Two Machines)

Use this when you want the controller bridge running on both machines with the same repo/config.

## 1) Clone and verify
On each machine:

```bash
git clone git@github.com:wisdom-in-a-nutshell/stadia-macos-controller.git ~/GitHub/stadia-macos-controller
cd ~/GitHub/stadia-macos-controller
swift build
```

## 2) Configure mappings
Edit `config/mappings.json` as needed. Hot reload is enabled while the bridge process is running.
For Ghostty layout rationale, see `docs/references/ghostty-mapping-rationale.md`.

## 3) Install launchd service
Canonical machine-ops command (recommended) from `~/GitHub/scripts`:

```bash
cd ~/GitHub/scripts
./setup/stadia/install-launchd-stadia-controller-bridge.sh --mode live
```

Optional signing override examples:
- `./setup/stadia/install-launchd-stadia-controller-bridge.sh --mode live --sign-identity auto` (default behavior)
- `./setup/stadia/install-launchd-stadia-controller-bridge.sh --mode live --sign-identity adhoc`

Project-local fallback (equivalent):

```bash
cd ~/GitHub/stadia-macos-controller
./scripts/install-launchd-bridge.sh --mode live
```

For safer testing first:

```bash
cd ~/GitHub/scripts
./setup/stadia/install-launchd-stadia-controller-bridge.sh --mode dry-run
```

What this installer now does:
- Reuses the staged runtime app bundle when source files are unchanged (avoids unnecessary re-sign/trust churn).
- Builds a fresh binary (`release` by default) only when source changed or `--force-build` is used.
- Stages it to a stable app bundle path: `~/Library/Application Support/stadia-controller-bridge/StadiaControllerBridge.app`.
- Uses one stable default LaunchAgent label on both machines: `com.stadia-controller-bridge`.
- Uses one stable default signing/bundle identifier on both machines: `com.stadia-controller-bridge`.
- Code-signs the staged app bundle target (`auto` by default with ad-hoc fallback).
- Points launchd to the staged app executable.

This avoids relying on transient `.build/...` binaries and reduces repeated Accessibility re-approval.

## 4) Accessibility permission (first-time, one stable app executable)
Grant Accessibility to the staged executable path used by launchd:
- `System Settings > Privacy & Security > Accessibility`
- Add/enable:
  - `~/Library/Application Support/stadia-controller-bridge/StadiaControllerBridge.app/Contents/MacOS/stadia-controller-bridge`

If entries got messy from old runs:
1. Remove old `stadia-controller-bridge` entries.
2. Re-add the staged executable path above.
3. Re-run installer:

```bash
cd ~/GitHub/scripts
./setup/stadia/install-launchd-stadia-controller-bridge.sh --mode live
```

## 5) Validate service state
```bash
launchctl print gui/$(id -u)/com.stadia-controller-bridge | sed -n '1,90p'
```

Check logs:
```bash
tail -n 80 ~/Library/Logs/stadia-controller-bridge.launchd.out.log
tail -n 80 ~/Library/Logs/stadia-controller-bridge.launchd.err.log
```

One-command verifier (recommended):
```bash
cd ~/GitHub/scripts
./setup/stadia/verify-launchd-stadia-controller-bridge.sh
```

## 6) Update workflow
On either machine:

```bash
cd ~/GitHub/stadia-macos-controller
git pull --rebase
```

No restart is needed for mapping changes only (hot reload). Restart/reinstall is needed if code or launchd settings change.
Do not copy built binaries between machines; each machine should run the installer locally so build/signing and launchd registration match local macOS trust state.

## Troubleshooting (Recovery Runbook)
If actions stop firing but controller appears connected:

1. Check service + logs:
```bash
launchctl print gui/$(id -u)/com.stadia-controller-bridge | sed -n '1,90p'
tail -n 120 ~/Library/Logs/stadia-controller-bridge.launchd.out.log
```
2. If logs show Accessibility errors, re-enable staged executable in:
   `System Settings > Privacy & Security > Accessibility`
3. Reconcile install with stable signing:
```bash
cd ~/GitHub/scripts
./setup/stadia/install-launchd-stadia-controller-bridge.sh --mode live
```
