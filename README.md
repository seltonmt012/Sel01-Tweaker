# Twerk — One-Click Windows 11 Optimizer

One command. Runs once, unattended. Debloats, removes Windows AI/Copilot,
applies performance + visual-effects tweaks, sets the Ultimate Performance power
plan, applies gaming tweaks, and installs a native RAM cleaner — then it's done.
No GUI clicking. Creates a restore point and a full registry backup so you can
undo everything with `-Revert`.

Combines/orchestrates: **Win11Debloat**, **RemoveWindowsAI**, **winutil** tweaks
(reimplemented), **WinMemoryCleaner**-style RAM clean (reimplemented), plus the
standard Windows Performance Options. See `NOTICE.md` for licenses/attribution.

## Run it

Open **PowerShell as Administrator** (the script also self-elevates) and:

```powershell
# from a local copy
.\dist\Twerk.ps1 -Profile Gaming
```

Or, once hosted at a URL, the winutil-style one-liner (supports parameters):

```powershell
& ([scriptblock]::Create((irm https://YOUR-URL/Twerk.ps1))) -Profile Gaming
```

> The plain `irm <url> | iex` form runs the default Gaming profile but cannot
> pass parameters — use the `scriptblock` form above when you need flags.

## Profiles

| Profile  | For | Behaviour |
|----------|-----|-----------|
| **Gaming** (default) | Gaming rigs | Keeps **Game Mode** + **HAGS** (GPU scheduling) ON, GameDVR/capture OFF, network throttling off, Ultimate Performance plan, gentler service trimming. |
| **Clean** | Office / all-round | Max debloat: Game Bar/DVR fully off, background apps off, fuller AI removal, more services to Manual, telemetry tasks disabled, hibernation off. |

```powershell
.\dist\Twerk.ps1 -Profile Clean
```

## Flags

| Flag | Effect |
|------|--------|
| `-Profile Gaming\|Clean` | Choose preset (default `Gaming`). |
| `-Revert` | Undo the last run from the newest backup JSON. |
| `-DryRun` | Log every intended change, write nothing. **Try this first.** |
| `-NoRestore` | Skip the System Restore point. |
| `-SkipDebloat` | Skip the Win11Debloat download/run. |
| `-SkipAI` | Skip the RemoveWindowsAI download/run. |
| `-NoRamTask` | Run the one-shot RAM clean but don't install the hourly task. |

## Undo

```powershell
.\dist\Twerk.ps1 -Revert
```

Restores every changed registry value, deletes the minted power scheme (back to
Balanced), and removes the hourly RAM-clean task.
**Not undone by revert:** apps removed during debloat (reinstall via Store/winget)
and the disabled telemetry scheduled tasks (Clean profile) — re-enable manually if
needed.

## What it changes (high level)

1. **Debloat** — removes bloat apps, telemetry, Bing/suggestions, ads (Win11Debloat).
2. **AI removal** — Copilot, Recall, AI scheduled tasks, re-add protection (RemoveWindowsAI).
3. **Native tweaks** — telemetry/activity-history/consumer-features/advertising-ID off,
   location denied, Delivery Optimization P2P off, Wi-Fi Sense off (+ service trim on Clean).
4. **Performance/Visual** — "best performance" effects, **keeping** window-drag contents,
   font smoothing, and thumbnails; transparency/animations off; 0ms menus; no startup delay;
   mouse acceleration off.
5. **Power plan** — Ultimate Performance.
6. **Gaming** — GameDVR off; Game Mode + HAGS per profile; MMCSS game priorities.
7. **RAM cleaner** — one-shot clean + optional hourly background task (native Win32, no GPL code).

## Files

```
src/Twerk.ps1          entry (self-elevate, flow, summary)
src/lib/Common.ps1     logging, Set-Reg (typed+snapshot), P/Invoke, orchestration
src/lib/Backup.ps1     restore point, backup JSON, -Revert
src/modules/01..07     the seven stages
build.ps1              bundles src -> dist/Twerk.ps1 (single file, syntax-checked)
dist/Twerk.ps1         generated one-file distributable
tests/                 Pester tests (non-destructive)
```

Backups + logs live in `%ProgramData%\Twerk\`.

## Build

```powershell
.\build.ps1            # -> dist\Twerk.ps1, validates syntax
```

## Caveats

- HKCU changes apply to the **current user** only (v1). Some changes apply after
  sign-out/in; **HAGS and the power plan need a reboot.**
- Orchestrated steps (debloat, AI removal) need internet; they skip + log if offline.
- The `UserPreferencesMask` "best performance" byte value is the widely-documented
  one — verify on a reference machine if you want byte-exact parity with your manual setup.
- Test with `-DryRun` on a new machine before a real run.
