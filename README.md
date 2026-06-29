# Sel01-Tweaker - One-Click Windows 10/11 Optimizer

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Run it once, as admin, and it tidies up a fresh Windows 10 or 11 install for you:
removes bloat apps and Copilot, turns off telemetry, sets the performance and
visual-effects options most people change by hand, switches on the Ultimate
Performance power plan, applies gaming and FiveM tweaks, and clears out temp files
and RAM. No menus to click through. Before it touches anything it makes a restore
point and a registry backup, so `-Revert` puts everything back.

It runs Win11Debloat and RemoveWindowsAI for you, and reimplements the winutil
tweaks and a WinMemoryCleaner-style RAM clean natively (no GPL code bundled).
NOTICE.md has the licenses.

## Run it

**Easiest:** double-click `START_Sel01-Tweaker.bat`, confirm the UAC prompt, and a
console menu appears with three choices: "Jetzt optimieren" (recommended), "Nur
testen" (changes nothing), and "Mehr / Experte" (Clean mode, repair, DNS, revert).
It shows an overview of exactly what will run and asks you to confirm first.

From a terminal (the script self-elevates):

```powershell
.\dist\Sel01Tweaker.ps1            # interactive menu (overview + confirm)
.\dist\Sel01Tweaker.ps1 -Profile Gaming   # run a profile directly, no menu
```

> First time? Build the single file with **`build.bat`** (double-click). It runs
> the build with `-ExecutionPolicy Bypass`, which avoids the "running scripts is
> disabled" / Mark-of-the-Web error you get from PowerShell on downloaded files.

Or run it straight from GitHub, winutil-style (supports parameters):

```powershell
& ([scriptblock]::Create((irm https://github.com/seltonmt012/Sel01-Tweaker/releases/latest/download/Sel01Tweaker.ps1))) -Profile Gaming
```

> Run that in an elevated PowerShell. The plain
> `irm https://github.com/seltonmt012/Sel01-Tweaker/releases/latest/download/Sel01Tweaker.ps1 | iex`
> form works too but can't pass flags, so use the `scriptblock` form above when you need `-Profile Clean`, `-Revert`, etc.

## Profiles

| Profile  | For | Behaviour |
|----------|-----|-----------|
| **Gaming** (default) | Gaming rigs | Keeps **Game Mode** + **HAGS** (GPU scheduling) ON, GameDVR/capture OFF, network throttling off, Ultimate Performance plan, gentler service trimming. |
| **Clean** | Office / all-round | Max debloat: Game Bar/DVR fully off, background apps off, fuller AI removal, more services to Manual, telemetry tasks disabled, hibernation off. |

```powershell
.\dist\Sel01Tweaker.ps1 -Profile Clean
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
| `-SkipFiveM` | Skip the FiveM tweaks (Gaming profile only). |
| `-SkipClean` | Skip the temp/disk cleaner. |
| `-TimerFix` | Opt-in: Win11 global timer resolution (fixes micro-stutter; desktop). |
| `-MsiMode` | Opt-in: enable GPU MSI mode (lower interrupt latency; auto-detects the GPU). |
| `-NoRamTask` | Run the one-shot RAM clean but don't install the hourly task. |

## Undo

```powershell
.\dist\Sel01Tweaker.ps1 -Revert
```

Restores every changed registry value, deletes the minted power scheme (back to
Balanced), and removes the hourly RAM-clean task.
**Not undone by revert:** apps removed during debloat (reinstall via Store/winget)
and the disabled telemetry scheduled tasks (Clean profile) - re-enable manually if
needed.

## What it changes (high level)

1. **Debloat** - removes bloat apps, telemetry, Bing/suggestions, ads (Win11Debloat).
2. **AI removal** - Copilot, Recall, AI scheduled tasks, re-add protection (RemoveWindowsAI).
3. **Native tweaks** - telemetry/activity-history/consumer-features/advertising-ID off,
   location denied, Delivery Optimization P2P off, Wi-Fi Sense off (+ service trim on Clean).
   **+ Extra** (OS-aware): web-search/Copilot/Cortana off, Explorer QoL, Edge background off, LongPaths.
   **+ Privacy+**: CEIP / Error-Reporting upload / speech / inking / Office & Edge & .NET/PS telemetry off,
   cloud-clipboard sync off, Find My Device off, telemetry scheduled-task batch off (re-enabled on revert),
   Update QoL (no forced reboot + active hours - updates stay on). Already-correct settings are skipped
   (idempotent); nothing weakens Defender/SmartScreen.
4. **Performance/Visual** - "best performance" effects, **keeping** window-drag contents,
   font smoothing, and thumbnails; transparency/animations off; 0ms menus; no startup delay;
   mouse acceleration off.
5. **Power plan** - Ultimate Performance.
6. **Gaming** - GameDVR off; Game Mode + HAGS per profile; MMCSS game priorities (audio-safe).
7. **FiveM** (Gaming only) - per-app fullscreen-optimizations off + High-Performance GPU for the
   real FiveM executables, `TdrDelay=8` GPU crash guard, Above-Normal process priority, and
   Nagle/delayed-ACK off on the active adapter. Skips cleanly if FiveM isn't installed. Only safe,
   reversible tweaks - deliberately excludes the harmful "hitreg booster" registry hacks (see PROGRESS.md).
8. **Power** (Desktop on AC only) - USB selective suspend off, PCIe ASPM off, disk no-sleep; auto-skipped on laptops/battery.
9. **Cleaner** - empties temp / Windows Update cache / thumbnail cache / Recycle Bin and reports freed space (`-SkipClean` to skip).
10. **RAM cleaner** - one-shot clean + optional hourly background task (native Win32, no GPL code).

## Files

```
src/Sel01Tweaker.ps1          entry (self-elevate, flow, summary)
src/lib/Common.ps1     logging, Set-Reg (typed+snapshot), P/Invoke, orchestration
src/lib/Backup.ps1     restore point, backup JSON, -Revert
src/modules/01..12     the stages (debloat, AI, tweaks, privacy, perf, gaming, FiveM, power, cleaner, RAM)
build.ps1              bundles src -> dist/Sel01Tweaker.ps1 (single file, syntax-checked)
dist/Sel01Tweaker.ps1         generated one-file distributable
tests/                 Pester tests (non-destructive)
```

Backups + logs live in `%ProgramData%\Sel01Tweaker\`.

## Build

```powershell
.\build.ps1            # -> dist\Sel01Tweaker.ps1, validates syntax
```

## Caveats

- HKCU changes apply to the **current user** only (v1). Some changes apply after
  sign-out/in; **HAGS and the power plan need a reboot.**
- Orchestrated steps (debloat, AI removal) need internet; they skip + log if offline.
- The `UserPreferencesMask` "best performance" byte value is the widely-documented
  one - verify on a reference machine if you want byte-exact parity with your manual setup.
- Test with `-DryRun` on a new machine before a real run.

## License

MIT - see [LICENSE](LICENSE). Third-party attribution in [NOTICE.md](NOTICE.md).
No third-party code is bundled: orchestrated tools are downloaded/run as-is,
winutil-style tweaks and the RAM cleaner are independent reimplementations, so
there is no GPL obligation. Provided without warranty - use at your own risk.
