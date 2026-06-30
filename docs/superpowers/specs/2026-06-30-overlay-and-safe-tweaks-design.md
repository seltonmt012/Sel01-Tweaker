# Design: Modern console overlay + safe new tweaks

Date: 2026-06-30
Target version: 1.3.0 (MINOR — two new modules)

## Goal

Two related improvements to Sel01-Tweaker:

1. **A modern, good-looking console overlay** during a run — a framed panel with a
   per-module progress bar, an overall progress bar, status icons, and a spinner —
   while never breaking the `irm | iex` one-liner path or legacy consoles.
2. **New safe optimization tweaks** drawn from current GitHub optimizer projects,
   every one reversible via `-Revert` and none weakening security.

Both ship together as release 1.3.0.

## Non-goals

- No full-screen TUI / multi-panel layout (too fragile for the one-liner path).
- No GPU driver repacking (license/copy risk — telemetry tasks only).
- No NIC power-save / EEE tweak (not cleanly reversible across driver variants).
- No security weakening (unchanged invariant: no Defender/SmartScreen/Update/hosts).

## Part A — Console overlay

### New library: `src/lib/Ui.ps1`

Dot-sourced like `Common.ps1` / `Backup.ps1`, inlined by `build.ps1` at the bundle
marker. Holds all rendering. Loaded before modules.

### Capability detection (the safety gate)

On first use, `Initialize-Ui` decides `$Global:Sel01Tweaker.UI.Fancy`:

- Enable VT/ANSI via `SetConsoleMode` P/Invoke (`ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004`)
  on the stdout handle. Use `Add-Type -MemberDefinition` per the `07-RamCleaner.ps1`
  rules (no `using`; pass namespaces via `-UsingNamespace`).
- `Fancy = $false` (→ current plain `Write-Log` behavior, unchanged) when **any** of:
  - `SetConsoleMode` fails / VT not supported,
  - `[Console]::IsOutputRedirected` is true (piped, `iex`, captured),
  - the console window/buffer is unavailable (`[Console]::WindowWidth` throws).
- Any exception in any render call flips `Fancy = $false` **permanently** for the run
  (one-way latch) so a mid-run glitch degrades gracefully instead of corrupting output.

### State

```
$Global:Sel01Tweaker.UI = @{
    Fancy       = $false
    AnchorRow   = $null      # console row where the panel starts
    TotalSteps  = 12         # module count (overall bar denominator)
    DoneSteps   = 0          # modules finished
    Current     = ''         # current module display name
    CurrentIdx  = 0          # 1-based module index
    ModuleStep  = 0          # sub-steps observed in current module
    ModuleEst   = 1          # static estimate of sub-steps for current module
}
```

`ModuleEst` comes from a static per-module table (rough expected `Set-Reg`/log count),
used only to render a believable per-module %. Clamped to 99% until the module returns,
then snapped to 100%.

### Rendering

- `Show-Panel` redraws the box (the approved mockup) by moving the cursor to
  `AnchorRow` via `[Console]::SetCursorPosition`, then overwriting each line padded to
  width. No full-screen clear → minimal flicker. Box is the only pinned region.
- Bars built from `█` (filled) / `░` (empty); icons `✓ ⟳ · ✗`. Width adapts to
  `[Console]::WindowWidth` (min 40, capped ~60).
- Banner / menus (`Show-Banner`, `Show-MainMenu`, `Show-AdvancedMenu`, `Show-Overview`)
  re-skinned with the same box characters and color scheme for a consistent look. In
  non-Fancy mode they render as today (ASCII).

### Zero-touch module integration

No module bodies change. The hooks are:

- `Invoke-Pipeline`, before each step: set `UI.Current`, `UI.CurrentIdx`,
  reset `UI.ModuleStep=0`, look up `UI.ModuleEst`; after the step: `UI.DoneSteps++`,
  snap module bar to 100%, redraw.
- `Write-Log` (single central sink) gains panel awareness:
  - When `Fancy` and a module is active: `INFO`/`OK` increments `UI.ModuleStep` and
    triggers a throttled `Show-Panel` redraw; the detailed line is written to the **log
    file only** (screen stays clean).
  - `WARN`/`ERROR` always also print on screen, below the panel.
  - When not `Fancy`: behaves exactly as today (prints `[LEVEL] msg`).

This keeps the chatty `[INFO] reg: …` lines in the file (for debugging) while the
screen shows the curated panel.

## Part B — New tweaks

All values written through `Set-Reg` / `Set-ServiceStart` / `Disable-Task`, so they are
snapshotted and undone by `-Revert`. All idempotent (skip when already correct). All
honor `-DryRun`.

### New module `src/modules/13-Network.ps1` (Gaming profile only)

Nagle's algorithm off on each active NIC. For every interface GUID under
`HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{guid}` that has an
assigned address (`DhcpIPAddress` or `IPAddress`):

- `TcpAckFrequency` DWord `1`
- `TCPNoDelay` DWord `1`

Each write is a normal `Set-Reg` (per-GUID snapshot) → fully reversible. Skipped for the
Clean profile. Impact: marginally more small-packet bandwidth, lower in-game latency.

### New module `src/modules/14-Gpu.ps1` (only if NVIDIA GPU present)

Detect NVIDIA via `Get-CimInstance Win32_VideoController` name match. If present,
enumerate scheduled tasks and `Disable-Task` those whose name matches the NVIDIA
telemetry/updater prefixes:

- `\NvTmRep*`, `\NvTmMon*`, `\NvTmRepOnLogon*`
- `\NvProfileUpdaterDaily*`, `\NvProfileUpdaterOnLogon*`
- `\NVIDIA GeForce Experience*` update/telemetry tasks

Drivers are never touched (no repack). Each disabled task is recorded by `Disable-Task`
and re-enabled by `-Revert`. Runs in both profiles (telemetry removal suits Clean too),
gated only on NVIDIA presence.

### Mouse / input — added to `06-Gaming.ps1` (Gaming profile, HKCU)

Disable "Enhance pointer precision" (mouse acceleration) for consistent aim:

- `HKCU:\Control Panel\Mouse` `MouseSpeed` String `0`
- `HKCU:\Control Panel\Mouse` `MouseThreshold1` String `0`
- `HKCU:\Control Panel\Mouse` `MouseThreshold2` String `0`

Gaming profile only. Reversible via `Set-Reg` string snapshots.

### Small QoL / perf — added to `04-Performance.ps1` (both profiles)

- `HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl` `Win32PrioritySeparation`
  DWord `26` (foreground boost, classic "optimize for programs").
- `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize`
  `StartupDelayInMSec` DWord `0` (no artificial startup-app delay).
- `HKCU:\Control Panel\Desktop` `MenuShowDelay` String `0` (snappier menus).
- `HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem` `NtfsDisableLastAccessUpdate`
  DWord `1` (less disk churn). Written via `Set-Reg` so the prior system-managed value
  is snapshotted and restored on revert — no `fsutil` special-casing.
- `HKCU:\Control Panel\Accessibility\StickyKeys` `Flags` String `506` (no accidental
  5×Shift Sticky-Keys prompt). Reversible.

## Wiring (the four-places rule)

New modules are profile-gated and need **no** new `-Skip*` switch, so the four-places
relaunch wiring is untouched. Required changes:

- `Invoke-Pipeline` `$steps`: insert `Network` (after `Gaming`) and `Gpu` (after
  `Network`). `build.ps1` picks up `13-*.ps1` / `14-*.ps1` automatically (numeric sort).
- `Ui.ps1` dot-sourced in `Sel01Tweaker.ps1` alongside `Common.ps1` / `Backup.ps1`,
  and inlined by `build.ps1` at `#__SEL01TWEAKER_BUNDLE_INSERT__`.
- `Initialize-Ui` called once at run start (in `Invoke-Pipeline` and the menu entry).
- Version bump in `src/lib/Common.ps1` → `1.3.0`.
- `Show-Overview` text updated to list the two new modules.

## Safety / impact summary

| Tweak | Mechanism | Reversible | Risk |
|-------|-----------|-----------|------|
| Overlay rendering | screen-only, latched fallback | n/a | none (degrades to plain) |
| Nagle off (per NIC) | `Set-Reg` per GUID | yes | minimal |
| NVIDIA telemetry tasks | `Disable-Task` | yes | none to gameplay |
| Mouse accel off | `Set-Reg` HKCU | yes | feel change (intended) |
| Win32PrioritySeparation | `Set-Reg` | yes | low |
| Startup delay / menu delay | `Set-Reg` | yes | low |
| NTFS LastAccess off | `Set-Reg` DWord | yes | low |
| Sticky Keys prompt off | `Set-Reg` | yes | low |

## Testing

`tests/run-checks.ps1` gets new assertions:

- New modules define `Invoke-Module-Network` / `Invoke-Module-Gpu`.
- Bundle (`dist/Sel01Tweaker.ps1`) contains `Initialize-Ui` and the new modules.
- `Ui.ps1` exposes a non-Fancy fallback path (no VT calls when redirected).
- Existing assertions still pass; `build.ps1` syntax-validates the bundle.

Manual smoke (per CLAUDE.md DryRun pattern): dot-source libs+modules, set `DryRun`,
run `Invoke-Module-Network` / `Invoke-Module-Gpu` — writes nothing, logs intent.
Run the bundle in Windows Terminal (Fancy) and via a redirected pipe (fallback) to
confirm both paths render.
