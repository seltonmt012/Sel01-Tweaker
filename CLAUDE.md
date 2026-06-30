# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Sel01-Tweaker is a one-click, unattended Windows 10/11 debloat + performance
optimizer written in PowerShell. One elevated run applies debloat, AI removal,
privacy/telemetry tweaks, visual-effects/performance settings, a power plan,
gaming + FiveM tweaks, and cleaners, then exits. It creates a System Restore
point and a per-value registry backup, and can undo everything with `-Revert`.
Published as GitHub releases under `seltonmt012/Sel01-Tweaker`.

## Commands

```powershell
.\build.ps1                       # bundle src -> dist\Sel01Tweaker.ps1 (+ syntax-validates)
powershell -ExecutionPolicy Bypass -File .\tests\run-checks.ps1   # tests (NOT Pester - see below)
.\release.ps1 -Version X.Y.Z      # bump version, build, zip, commit, tag, push, publish GitHub release

# Run the tool (self-elevates via UAC)
.\dist\Sel01Tweaker.ps1                       # interactive menu
.\dist\Sel01Tweaker.ps1 -Profile Gaming       # run a profile directly (one-liner path)
.\dist\Sel01Tweaker.ps1 -DryRun -Profile Gaming   # preview, writes nothing
.\dist\Sel01Tweaker.ps1 -Revert               # undo last run from newest backup JSON
```

Tests: use `tests\run-checks.ps1` (dependency-free). The `tests\Sel01Tweaker.Tests.ps1`
specs are Pester v5 syntax and will NOT run on the Pester 3.x that ships with Windows.
There is no single-test runner; `run-checks.ps1` runs all assertions and exits non-zero on failure.

**Testing on a clean VM** (`tools/`): `new-testvm.ps1` builds an unattended Hyper-V
Gen2 Win11 VM (vTPM + SecureBoot, `autounattend.xml` delivered as a second DVD ISO
built via IMAPI - a fixed seed VHDX is NOT scanned by Setup) and boots it; LabConfig
bypass keys let it install on hosts whose CPU isn't Win11-listed. `vm-autofinish.ps1`
(registered as a one-shot SYSTEM logon/startup task) starts the VM, waits for the
desktop, and snapshots `clean-desktop`. Revert + retest: `new-testvm.ps1 -RevertTo clean-desktop`.
Note: the Hyper-V hypervisor only loads at boot, so enabling Hyper-V or
`bcdedit /set hypervisorlaunchtype auto` needs a host reboot before VMs can start;
Gen2 + a Windows ISO shows a "Press any key to boot from CD" prompt that times out
headless - send keystrokes via the Msvm_Keyboard WMI `TypeKey` during the first boot.

DryRun-smoke one module without elevation (writes nothing):
```powershell
. .\src\lib\Common.ps1; . .\src\lib\Backup.ps1; . .\src\lib\Ui.ps1
Get-ChildItem .\src\modules\*.ps1 | Sort-Object Name | ForEach-Object { . $_.FullName }
$Global:Sel01Tweaker.DryRun = $true; Initialize-Sel01TweakerState -Stamp 'smoke'
$Global:Sel01Tweaker.Profile = 'Gaming'; $Global:Sel01Tweaker.Backup = [System.Collections.Generic.List[object]]::new()
Invoke-Module-FiveM   # or any Invoke-Module-*
```

## Architecture

Single self-elevating orchestrator, developed as `src/Sel01Tweaker.ps1` (entry)
plus three libs and a numbered module set, all dot-sourced at runtime. `build.ps1`
inlines libs+modules at the `#__SEL01TWEAKER_BUNDLE_INSERT__` marker to produce
`dist/Sel01Tweaker.ps1`, the single file users run / `irm`.

- `src/lib/Common.ps1` - shared `$Global:Sel01Tweaker` state + every primitive.
  **All registry/service writes go through `Set-Reg` / `Remove-Reg` /
  `Set-ServiceStart` / `Set-MachineEnv`**, which snapshot the prior value before
  writing and are idempotent. Also: `Get-Sel01OSInfo` (Win10 vs 11 by build
  >=22000), `Get-Sel01PowerInfo` (laptop/desktop + battery), `Disable-Task`
  (records disabled tasks for revert), `Invoke-Remote` (download + run upstream),
  `Build-PreferencesMask`, `Broadcast-SettingChange`.
- `src/lib/Backup.ps1` - restore point, writes the backup JSON (registry
  snapshots + disabled tasks + disabled optional-features + removed capabilities +
  minted power-scheme GUID + RAM task), and `Invoke-Revert` reads it back to restore
  values, re-enable tasks, re-enable features / re-add capabilities (via
  `Disable-Sel01Feature` / `Remove-Sel01Capability` records), delete the power
  scheme, and remove the RAM task.
- `src/lib/Ui.ps1` - the console overlay (framed live panel, per-module + overall
  progress bars, spinner). `Initialize-Ui` probes VT/ANSI and sets `UI.Fancy`;
  it is `$false` (→ plain `Write-Log` output, unchanged) when output is redirected
  (`irm | iex`, captured) or VT is unavailable, and any render error latches it off
  permanently. Driven zero-touch through `Write-Log` + `Invoke-Pipeline` hooks
  (`Set-UiModule`/`Complete-UiModule`/`Complete-UiPanel`) - modules need no changes.
- `src/modules/01..17` - the stages, run in order by `Invoke-Pipeline`:
  01 Debloat **orchestrates** (downloads MIT upstream Win11Debloat, runs silently);
  16 AppxBloat is a **native** app-removal backstop (removes ~20 bloat Store apps by name,
  download-independent; appx removal is NOT reverted - like Debloat); 17 Win10 is a
  Win10-only block (gated `-not IsWin11`, no-ops on Win11);
  02 RemoveAI, 03 WinutilTweaks, 04 Performance, 06 Gaming, 09 Extra, 10 Privacy are
  **native** reimplementations (02 was orchestrated but upstream RemoveWindowsAI is
  chronically broken on Win11 26x00, so it's now native policy disables + Copilot-app
  removal); 08 FiveM (Gaming only, includes a whitelist cache cleaner), 11 Power
  (desktop-on-AC only, plus opt-in `-TimerFix`/`-MsiMode`), 12 Cleaner, 07 RamCleaner
  (independent Win32 P/Invoke - WinMemoryCleaner is GPL, so no code is copied);
  13 Network (Gaming-only, Nagle off per NIC), 14 Gpu (NVIDIA + AMD telemetry
  tasks + opt-out reg flags; vendor-gated, drivers/updates untouched), 15 Features
  (DISM: disables legacy optional features + niche capabilities; reboot to finalise).

**Profiles** (`-Profile Gaming|Clean`) gate behaviour inside modules via
`$Global:Sel01Tweaker.Profile`. Gaming keeps Game Mode + HAGS and is gentler;
Clean is maximum debloat. Many tweaks are also OS-gated via `IsWin11` and
hardware-gated via `IsLaptop`/`OnBattery`.

**Entry UI:** when no `-Profile`/`-Revert` is given, a simple console menu shows
(Jetzt optimieren / Nur testen / Mehr-Experte; the submenu has Clean, Reparatur,
DNS, Revert). `-Profile X` runs directly (for the one-liner). A guard exits
cleanly when stdin is non-interactive so the menu can't spin.

## Invariants (break these and things silently fail)

- **Never write the registry directly.** Use `Set-Reg`/`Remove-Reg`/`Set-ServiceStart`,
  or `-Revert` can't undo it. Binary values must be `byte[]`; `Set-Reg`'s `-Type`
  distinguishes REG_SZ (`String`) vs `DWord` (the classic bug). `Set-Reg` skips
  writes when the value already equals the target (idempotent), so re-runs are clean.
- **Scheduled tasks** go through `Disable-Task` (recorded in state) so revert can
  re-enable them. Don't `schtasks /Disable` directly.
- **Never weaken security.** No disabling Defender/SmartScreen, no disabling
  Windows Update (use the no-forced-reboot / active-hours QoL instead), no
  hosts/firewall telemetry blocking. See PROGRESS.md "EXCLUDED" lists.
- **`param()` must stay the first statement** in `src/Sel01Tweaker.ps1`; the
  bundle marker sits right after it. New `-Skip*`/opt-in switches must be wired in
  4 places: the `param()` block, the elevation-relaunch `$argline`, the
  `$Global:Sel01Tweaker.*` stash, and the final `Start-Sel01Tweaker` call.
- **`build.ps1` uses `.Replace()`, not `-replace`** (bundle text has `$` and
  here-string terminators). **`Add-Type -MemberDefinition` can't contain `using`** -
  pass `-UsingNamespace` (not `System`/`System.Runtime.InteropServices`, which are
  defaults). See `07-RamCleaner.ps1`.
- **`Invoke-Remote` splats a hashtable by name** (only module 01 Debloat orchestrates
  now; RemoveAI is native). Switches bind and array params pass element-by-element. The
  param names must match the **live** upstream Win11Debloat (params get renamed - e.g.
  `DisableChat` → `HideChat`); a wrong name aborts the whole orchestrated run. Verify by
  parsing the downloaded script's `param()` block.
- **The overlay must always degrade.** Never assume `UI.Fancy`; all panel rendering
  stays in `try/catch` that latches `Fancy=$false`, and `Write-Log` keeps its plain
  path so redirected/`iex` runs and legacy consoles look exactly as before. External
  tools (Win11Debloat/winget/DISM) corrupt the framed box, so wrap them in
  `Suspend-Panel`/`Resume-Panel`, set `$ProgressPreference='SilentlyContinue'`, and
  redirect their output to a **separate** `-extern.txt` file (NOT the main log — a
  child process can keep that handle open and lock `Write-Log` out, hence the
  lock-resilient `Add-Content` there).
- **`Set-Reg`/`Set-ServiceStart` must never throw raw red.** `Set-Reg` uses
  `-ErrorAction Stop` so a non-terminating `PermissionDenied` on an ACL-protected key
  (e.g. service `DPS`) is caught and logged as a WARN (and its snapshot dropped). Don't
  add protected keys to the service lists. `Set-ServiceStart` also has a hard
  **deny-list** (Defender/Update/RPC/audio/network/notification core) and stops the
  service immediately after retyping it (so the change takes effect without a reboot).
- **App (appx) removal is NOT reverted** (modules 01 Debloat, 02 RemoveAI Copilot app,
  16 AppxBloat) — like Win11Debloat. Optional features/capabilities (15) ARE reverted via
  `Disable-Sel01Feature`/`Remove-Sel01Capability` records; DISM changes need a reboot.
- **Any reboot-requiring tweak must set `$Global:Sel01Tweaker.RebootNeeded = $true`** so
  the end-of-run interactive restart prompt (now/later) fires. That prompt only asks when
  stdin is interactive — never hang the `-Profile` one-liner. `Test-Online` probes TCP 443,
  not ICMP (ping is often blocked while HTTPS works).
- **FiveM module (08) is gated on `Test-FiveMInstalled`** (folder exists; not "running"),
  and targets the modern `FiveM_b<build>_GTAProcess.exe` (the legacy `FiveM_GTAProcess.exe`
  no longer exists). HKCU writes done while running as SYSTEM (e.g. a test scheduled task)
  land in SYSTEM's hive — to verify per-user tweaks, run in the actual user's context.
- After editing `src/`, **rebuild** (`.\build.ps1`) and re-run `run-checks.ps1`.
  Never hand-edit `dist/Sel01Tweaker.ps1` - it's generated. Runtime logs/backups
  live in `%ProgramData%\Sel01Tweaker\`.

## Workflow

`PROGRESS.md` is the running step log: each finished step is ticked and committed
with a `step: <what>` message. **Versioning:** `Version` in `src/lib/Common.ps1`
is the single source of truth (shown in banner + log). Every big update (new
module/feature) gets a version bump + GitHub release via `.\release.ps1 -Version X.Y.Z`
(SemVer: MINOR for new modules, PATCH for fixes). `release.ps1` reuses the git
credential for `gh` auth. See `RELEASING.md`. Orchestrated steps need internet
(skip + log when offline); HAGS, power plan, TimerFix, MsiMode need a reboot;
HKCU changes apply to the current user only.
