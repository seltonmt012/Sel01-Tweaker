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

DryRun-smoke one module without elevation (writes nothing):
```powershell
. .\src\lib\Common.ps1; . .\src\lib\Backup.ps1
Get-ChildItem .\src\modules\*.ps1 | Sort-Object Name | ForEach-Object { . $_.FullName }
$Global:Sel01Tweaker.DryRun = $true; Initialize-Sel01TweakerState -Stamp 'smoke'
$Global:Sel01Tweaker.Profile = 'Gaming'; $Global:Sel01Tweaker.Backup = [System.Collections.Generic.List[object]]::new()
Invoke-Module-FiveM   # or any Invoke-Module-*
```

## Architecture

Single self-elevating orchestrator, developed as `src/Sel01Tweaker.ps1` (entry)
plus two libs and a numbered module set, all dot-sourced at runtime. `build.ps1`
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
  snapshots + disabled tasks + minted power-scheme GUID + RAM task), and
  `Invoke-Revert` reads it back to restore values, re-enable tasks, delete the
  power scheme, and remove the RAM task.
- `src/modules/01..12` - the stages, run in order by `Invoke-Pipeline`:
  01 Debloat + 02 RemoveAI **orchestrate** (download MIT upstream Win11Debloat /
  RemoveWindowsAI and run them silently); 03 WinutilTweaks, 04 Performance,
  06 Gaming, 09 Extra, 10 Privacy are **native** reimplementations; 08 FiveM
  (Gaming only, includes a whitelist cache cleaner), 11 Power (desktop-on-AC
  only, plus opt-in `-TimerFix`/`-MsiMode`), 12 Cleaner, 07 RamCleaner
  (independent Win32 P/Invoke - WinMemoryCleaner is GPL, so no code is copied).

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
- **`Invoke-Remote` splats a hashtable by name**, not a flat `-Flag` array, so
  switches bind and array params (RemoveWindowsAI `-Options`) pass element-by-element.
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
