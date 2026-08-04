# Sel01-Tweaker - One-Click Windows 10/11 Optimizer

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Run it once, as admin, and it tidies up a fresh Windows 10 or 11 install for you:
removes bloat apps and Copilot, turns off telemetry, sets the performance and
visual-effects options most people change by hand, switches on the Ultimate
Performance power plan, applies gaming and FiveM tweaks, and clears out temp files.
No menus to click through. Before it touches anything it makes a restore
point and a registry backup, so `-Revert` puts everything back.

It runs Win11Debloat and RemoveWindowsAI for you, and reimplements the winutil
tweaks and an opt-in, one-shot standby-list purge natively (no GPL code bundled).
NOTICE.md has the licenses. It never installs a background task that touches
memory - see "Honest effectiveness" for why.

## ⚡ Schnellster Start (1 Zeile)

Open **PowerShell** (normal is fine — it asks for admin via UAC by itself) and paste:

```powershell
& ([scriptblock]::Create((irm https://github.com/seltonmt012/Sel01-Tweaker/releases/latest/download/Sel01Tweaker.ps1))) -Profile Gaming
```

That downloads the latest single-file build and runs the Gaming profile. Drop
`-Profile Gaming` to get the menu, or use `-Profile Clean` / `-Revert` instead.

Under the hood it self-elevates by relaunching itself as admin:
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script> -Profile Gaming`.

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
| `-MsiMode` | Opt-in: enable GPU MSI mode (lower interrupt latency; auto-detects the GPU, desktop only). |
| `-ShaderClean` | Opt-in: clear the GPU shader caches (NVIDIA/AMD/Intel + DirectX). Fixes stutter after a driver update; the **next** game start recompiles shaders once. |
| `-RamClean` | Opt-in: purge the standby list **once**. No background task, no working sets touched. Skipped when the pagefile is on an HDD. |
| `-NoRamTask` | Deprecated no-op (kept so old command lines still bind). There is no background RAM task any more. |

## Undo

```powershell
.\dist\Sel01Tweaker.ps1 -Revert
```

Restores every changed registry value and deletes the minted power scheme (back to
Balanced). Revert also uninstalls the old hourly RAM-clean task and its leftover
helper script if they are still present, whatever the backup says - but you don't
have to revert for that: any normal v1.10.0 run uninstalls them too.
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
6. **Gaming** - GameDVR off; Game Mode + HAGS per profile; MMCSS game priorities (audio-safe);
   for an installed **GTA V** (Rockstar/Steam/Epic, Legacy + Enhanced): per-app fullscreen-optimizations
   off + High-Performance GPU.
7. **FiveM** (Gaming only) - per-app fullscreen-optimizations off + High-Performance GPU for the
   real FiveM executables, `TdrDelay=8` GPU crash guard, Above-Normal process priority, and
   Nagle/delayed-ACK off on the active adapter. Skips cleanly if FiveM isn't installed. Only safe,
   reversible tweaks - deliberately excludes the harmful "hitreg booster" registry hacks (see PROGRESS.md).
8. **Power** (AC only) - CPU power throttling off on **desktops and laptops on mains** (that is where
   Windows throttles hardest); the device-level settings (USB selective suspend, PCIe ASPM, disk
   no-sleep) stay desktop-only. On battery the whole module is skipped.
9. **Cleaner** - empties temp / Windows Update cache / thumbnail cache / Recycle Bin and reports freed space (`-SkipClean` to skip).
10. **Shader cache** (opt-in, `-ShaderClean` or menu) - clears NVIDIA/AMD/Intel + DirectX shader caches.
11. **RAM cleaner** - uninstalls the hourly RAM-clean task that versions up to v1.9.0 installed
    (it caused the periodic freezes). Nothing else happens unless you pass `-RamClean`, which
    purges the standby list **once** (native Win32, no GPL code). No background task is ever
    installed, and no process working sets are emptied.

## Honest effectiveness

No tweak here doubles your FPS. Nothing in a registry key can. This is what each
change is actually worth, so you can judge the tool instead of trusting a
marketing table:

| Rating | Meaning |
|--------|---------|
| ✅ | Measurable or clearly noticeable |
| ⚠️ | Situational - helps on specific hardware or in specific cases |
| ❌ | No real gaming benefit; kept only because it is harmless and expected |

| Change | Rating | Reality |
|--------|--------|---------|
| Debloat / Appx removal, background apps off | ✅ | Fewer background processes, less disk/RAM, faster boot. |
| Telemetry / privacy / AI off | ✅ privacy, ⚠️ perf | The point is data, not frames. |
| Startup delay 0, menu delay 0, animations off | ✅ *perceived* | Windows feels snappier; it is not more FPS. |
| Mouse acceleration off | ✅ | 1:1 input, real for aiming. |
| Power throttling off (on AC) | ✅ | Biggest win on laptops with aggressive OEM power management. |
| FiveM cache clean | ✅ | Fixes texture bugs, load failures, crash loops. |
| Shader cache clean (`-ShaderClean`) | ✅ | Fixes stutter after GPU-driver / Windows updates. |
| Page-file guard (FiveM) | ✅ | Prevents out-of-memory crashes when the page file was switched off. |
| Windowed flip-model upgrade (Win11) | ✅ | Real latency drop in borderless windowed mode. |
| Ultimate Performance plan | ⚠️ | Helps older/laptop hardware, near-nothing on a modern desktop. |
| HAGS | ⚠️ | Mixed per GPU and game - test it. |
| GameDVR / Game Bar off | ⚠️ | Removes capture overhead you probably weren't using. |
| MMCSS game priorities, SystemResponsiveness 10 | ⚠️ | Only matters when the CPU is contended. `0` would starve audio - we use the safe value. |
| FSO off + High-Performance GPU per exe (GTA V / FiveM) | ⚠️ | GPU preference matters on hybrid-graphics laptops; FSO helps vsync/tearing cases. |
| `TdrDelay=8` | ⚠️ | Crash guard for GPU-heavy FiveM streaming, not performance. |
| Timer resolution (`-TimerFix`, Win11) | ⚠️ | Steadier frame pacing for people sensitive to micro-stutter. |
| GPU MSI mode (`-MsiMode`) | ⚠️ | Interrupt latency; measurable only with proper tooling. |
| Services → Manual, optional features off | ⚠️ | A little RAM/disk and attack surface. Never *Disabled*, never core services. |
| Temp / update-cache cleaner | ⚠️ | Frees disk. Zero FPS. |
| Periodic RAM "cleaning" (shipped up to v1.9.0, now removed) | ❌ actively harmful | The hourly task we used to install called `EmptyWorkingSet` on every process and dropped the standby list. That evicts the whole live working set of the machine to the pagefile, so everything you touch next has to be faulted back in - which is exactly the recurring multi-minute freeze users reported, once an hour, with nothing in the event log. Worst when the pagefile sits on an HDD. "Free RAM" rising in Task Manager is the damage, not the win. Every v1.10.0 run uninstalls that task. |
| One-shot standby purge (`-RamClean`, opt-in) | ⚠️ | Drops the standby list once, when you ask for it. The one defensible case is a standby list stuffed with data you will not read again (after a huge file copy). Otherwise pointless: the standby list is already reclaimable and Windows hands it back on demand. Never touches working sets, and refuses to run when the pagefile is on an HDD. |
| USB selective suspend / PCIe ASPM off | ⚠️ | Avoids device wake-up hitches on desktops. |
| `Win32PrioritySeparation` | ❌ | Scheduler folklore. We ship a safe value, not the harmful `38`. |
| `NetworkThrottlingIndex` off | ❌ | It throttles *multimedia streaming*, not games. Harmless, expected by users. |
| Nagle / delayed-ACK off | ❌ gameplay, ⚠️ TCP | FiveM gameplay is UDP. Only the connect/download path is TCP. |

**Deliberately not shipped** (however much FPS the internet promises): disabling
VBS/HVCI, Defender or SmartScreen, turning Windows Update off, CPU core
unparking, `TdrLevel=0`, page-file off, `DisablePagingExecutive`, hosts/firewall
telemetry blocking, and **any periodic/background memory cleaning** - no scheduled
RAM task, no `EmptyWorkingSet` across processes, no system-file-cache flushing (we
shipped that until v1.9.0 and it froze machines). See PROGRESS.md for the full
excluded list and why.

## Files

```
src/Sel01Tweaker.ps1          entry (self-elevate, flow, summary)
src/lib/Common.ps1     logging, Set-Reg (typed+snapshot), P/Invoke, orchestration
src/lib/Backup.ps1     restore point, backup JSON, -Revert
src/modules/01..19     the stages (debloat, AI, tweaks, privacy, perf, gaming, FiveM, power,
                       cleaner, shader cache, RAM, services, network, GPU, features)
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
winutil-style tweaks and the standby-list purge are independent reimplementations,
so there is no GPL obligation. Provided without warranty - use at your own risk.
