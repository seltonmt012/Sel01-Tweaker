# Modern overlay + safe new tweaks — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modern framed console overlay (per-module + overall progress bars, spinner, status line) with a hard fallback to plain logging, plus four batches of reversible Windows tweaks, shipped as v1.3.0.

**Architecture:** New `src/lib/Ui.ps1` library does VT detection and all rendering; it degrades to today's plain `Write-Log` whenever VT is unavailable or output is redirected. The overlay is driven entirely through the existing central `Write-Log` sink plus hooks in `Invoke-Pipeline` — no module bodies are rewritten. Two new numbered modules (`13-Network`, `14-Gpu`) and three new lines in `04-Performance` add the tweaks. Everything routes through `Set-Reg` / `Disable-Task` so `-Revert` undoes it.

**Tech Stack:** PowerShell 5.1+, Win32 P/Invoke via `Add-Type -MemberDefinition` (no `using`; namespaces via `-UsingNamespace`), dependency-free `tests/run-checks.ps1` harness.

---

## File structure

- **Create** `src/lib/Ui.ps1` — capability detection, UI state, pure bar/icon builders, panel render, pipeline hook helpers. One responsibility: the on-screen overlay.
- **Create** `src/modules/13-Network.ps1` — `Invoke-Module-Network` (Nagle off, Gaming only).
- **Create** `src/modules/14-Gpu.ps1` — `Invoke-Module-Gpu` (NVIDIA telemetry tasks).
- **Modify** `src/lib/Common.ps1` — version → 1.3.0; `Write-Log` gains panel awareness.
- **Modify** `src/modules/04-Performance.ps1` — three new tweak lines.
- **Modify** `src/Sel01Tweaker.ps1` — dot-source `Ui.ps1`; `Initialize-Ui` call; pipeline `$steps` + UI hooks; `Show-Overview` text; restyled banner/menus.
- **Modify** `build.ps1` — add `Ui.ps1` to the bundle parts list.
- **Modify** `tests/run-checks.ps1` — load `Ui.ps1` + modules; assert bar builder, fallback, new modules exist.

> **Note for the implementer:** mouse-acceleration-off, `MenuShowDelay=0`, and `StartupDelayInMSec=0` are ALREADY in `04-Performance.ps1` (lines 44-48, 33, 42). Do NOT re-add them.

---

## Task 1: UI library — state + pure builders + capability detection

**Files:**
- Create: `src/lib/Ui.ps1`
- Test: `tests/run-checks.ps1`

- [ ] **Step 1: Create `src/lib/Ui.ps1` with state, builders, and detection**

```powershell
# ============================================================================
#  Sel01Tweaker - lib/Ui.ps1
#  Modern console overlay: framed panel, per-module + overall progress bars,
#  spinner, status line. Hard fallback to plain Write-Log when VT/ANSI is not
#  available or output is redirected (irm|iex pipe, legacy console). Any render
#  error latches Fancy=$false for the rest of the run.
# ============================================================================

# Per-module rough sub-step estimates (drives the per-module bar %). Approximate
# is fine; the bar clamps to 99% until the module returns, then snaps to 100%.
$Global:Sel01TweakerUiEst = @{
    Debloat=6; RemoveAI=4; WinutilTweaks=20; Extra=15; Privacy=20; Performance=17;
    PowerPlan=4; Gaming=15; Network=6; Gpu=6; FiveM=10; Power=6; Cleaner=8; RamCleaner=4
}

function Get-Sel01Bar {
    <#  Pure: builds a fixed-width progress bar string from a percentage.  #>
    param([int]$Pct,[int]$Width = 20)
    if ($Pct -lt 0) { $Pct = 0 } elseif ($Pct -gt 100) { $Pct = 100 }
    if ($Width -lt 1) { $Width = 1 }
    $fill = [int][math]::Round($Width * $Pct / 100.0)
    if ($fill -gt $Width) { $fill = $Width }
    return ([string]([char]0x2588) * $fill) + ([string]([char]0x2591) * ($Width - $fill))
}

function Initialize-Ui {
    <#  Decides UI.Fancy and tries to enable VT/ANSI. Idempotent.  #>
    if (-not $Global:Sel01Tweaker.UI) {
        $Global:Sel01Tweaker.UI = @{
            Fancy=$false; AnchorRow=$null; Total=14; Done=0; Current=''
            CurrentIdx=0; ModuleStep=0; ModuleEst=1; Spin=0; LastMsg=''
        }
    }
    $ui = $Global:Sel01Tweaker.UI
    $fancy = $true
    try { if ([Console]::IsOutputRedirected) { $fancy = $false } } catch { $fancy = $false }
    if ($fancy) {
        try { $null = [Console]::WindowWidth } catch { $fancy = $false }
    }
    if ($fancy) {
        try {
            if (-not ([System.Management.Automation.PSTypeName]'Sel01Tweaker.Vt').Type) {
                Add-Type -Namespace Sel01Tweaker -Name Vt -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError=true)]
public static extern System.IntPtr GetStdHandle(int nStdHandle);
[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError=true)]
public static extern bool GetConsoleMode(System.IntPtr hConsoleHandle, out uint lpMode);
[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError=true)]
public static extern bool SetConsoleMode(System.IntPtr hConsoleHandle, uint dwMode);
'@ -ErrorAction Stop
            }
            $h = [Sel01Tweaker.Vt]::GetStdHandle(-11)   # STD_OUTPUT_HANDLE
            $mode = [uint32]0
            if ([Sel01Tweaker.Vt]::GetConsoleMode($h, [ref]$mode)) {
                [void][Sel01Tweaker.Vt]::SetConsoleMode($h, ($mode -bor 0x0004))  # ENABLE_VIRTUAL_TERMINAL_PROCESSING
            } else { $fancy = $false }
        } catch { $fancy = $false }
    }
    $ui.Fancy = $fancy
}
```

- [ ] **Step 2: Add UI assertions to `tests/run-checks.ps1`**

At the top, after the existing `. (Join-Path $root 'src\lib\Backup.ps1')` line (line 9), add:

```powershell
. (Join-Path $root 'src\lib\Ui.ps1')
Get-ChildItem (Join-Path $root 'src\modules') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
```

Then after the existing `mask bytes` assertion (line 17), add:

```powershell
ok 'bar full'  ((Get-Sel01Bar 100 10) -eq ([string]([char]0x2588) * 10))
ok 'bar empty' ((Get-Sel01Bar 0 10)   -eq ([string]([char]0x2591) * 10))
ok 'bar half filled 5' ((((Get-Sel01Bar 50 10).ToCharArray() | Where-Object { $_ -eq [char]0x2588 }) | Measure-Object).Count -eq 5)
Initialize-Ui
ok 'ui non-fancy when redirected' ($Global:Sel01Tweaker.UI.Fancy -eq $false)
```

- [ ] **Step 3: Run the checks**

Run: `powershell -ExecutionPolicy Bypass -File .\tests\run-checks.ps1`
Expected: `ALL CHECKS PASSED` (the run-checks harness runs with redirected output, so `Fancy` is `$false` — the new assertions pass).

- [ ] **Step 4: Commit**

```bash
git add src/lib/Ui.ps1 tests/run-checks.ps1
git commit -m "feat(ui): add Ui.ps1 with bar builder + VT capability detection"
```

---

## Task 2: Panel render + pipeline hooks + Write-Log integration

**Files:**
- Modify: `src/lib/Ui.ps1` (append render + hook helpers)
- Modify: `src/lib/Common.ps1:81-98` (`Write-Log`)
- Test: manual DryRun smoke (rendering can't be unit-tested headlessly)

- [ ] **Step 1: Append render + hook helpers to `src/lib/Ui.ps1`**

```powershell
function Set-UiModule {
    <#  Called by the pipeline before each module runs.  #>
    param([int]$Index,[int]$Total,[string]$Name)
    $ui = $Global:Sel01Tweaker.UI
    if (-not $ui) { return }
    $ui.CurrentIdx = $Index; $ui.Total = $Total; $ui.Current = $Name
    $ui.ModuleStep = 0; $ui.LastMsg = ''
    $est = $Global:Sel01TweakerUiEst[$Name]
    $ui.ModuleEst = if ($est) { [int]$est } else { 8 }
    Show-Panel
}

function Complete-UiModule {
    <#  Called by the pipeline after each module finishes.  #>
    $ui = $Global:Sel01Tweaker.UI
    if (-not $ui) { return }
    $ui.Done++
    $ui.ModuleStep = $ui.ModuleEst   # snap current bar to 100%
    Show-Panel
}

function Complete-UiPanel {
    <#  Park the cursor below the panel so the summary prints normally.  #>
    $ui = $Global:Sel01Tweaker.UI
    if (-not ($ui -and $ui.Fancy)) { return }
    try {
        if ($null -ne $ui.AnchorRow) { [Console]::SetCursorPosition(0, [math]::Min($ui.AnchorRow + 9, [Console]::BufferHeight - 1)) }
    } catch {}
    $ui.CurrentIdx = 0   # subsequent Write-Log lines print plainly under the panel
    Write-Host ''
}

function Show-Panel {
    <#  Redraws the framed panel in place at AnchorRow. Any failure latches
        Fancy=$false so the rest of the run degrades to plain logging.  #>
    $ui = $Global:Sel01Tweaker.UI
    if (-not ($ui -and $ui.Fancy)) { return }
    try {
        $w = [Console]::WindowWidth - 2
        if ($w -gt 58) { $w = 58 } elseif ($w -lt 40) { $w = 40 }
        $inner = $w - 2
        $barW = $inner - 8

        $modPct = if ($ui.ModuleEst -gt 0) {
            $p = [int][math]::Round(100.0 * $ui.ModuleStep / $ui.ModuleEst)
            if ($p -gt 99 -and $ui.ModuleStep -lt $ui.ModuleEst) { 99 } else { $p }
        } else { 0 }
        $allPct = if ($ui.Total -gt 0) { [int][math]::Round(100.0 * $ui.Done / $ui.Total) } else { 0 }
        $ui.Spin = ($ui.Spin + 1) % 4
        $spin = @('|','/','-','\')[$ui.Spin]

        function _pad([string]$s) { if ($s.Length -gt $inner) { $s = $s.Substring(0,$inner) }; return $s.PadRight($inner) }
        $tl=[char]0x2554; $tr=[char]0x2557; $bl=[char]0x255A; $br=[char]0x255D
        $h=[char]0x2550;  $v=[char]0x2551;  $ml=[char]0x2560; $mr=[char]0x2563
        $top = "$tl$([string]$h * $inner)$tr"
        $sep = "$ml$([string]$h * $inner)$mr"
        $bot = "$bl$([string]$h * $inner)$br"

        $title  = "$v$(_pad("  SEL01-TWEAKER   $($Global:Sel01Tweaker.Profile)   v$($Global:Sel01Tweaker.Version)"))$v"
        $modln  = "$v$(_pad("  $spin  $($ui.CurrentIdx)/$($ui.Total)  $($ui.Current)"))$v"
        $modbar = "$v$(_pad("  $(Get-Sel01Bar $modPct $barW)  $($modPct.ToString().PadLeft(3))%"))$v"
        $statln = "$v$(_pad("  $($ui.LastMsg)"))$v"
        $allbar = "$v$(_pad("  Gesamt $(Get-Sel01Bar $allPct $barW)  $($ui.Done)/$($ui.Total)"))$v"

        $lines = @($top,$title,$sep,$modln,$modbar,$statln,$sep,$allbar,$bot)

        if ($null -eq $ui.AnchorRow) {
            try { $ui.AnchorRow = [Console]::CursorTop } catch { $ui.AnchorRow = 0 }
            $lines | ForEach-Object { [Console]::WriteLine($_) }
        } else {
            [Console]::SetCursorPosition(0, $ui.AnchorRow)
            $lines | ForEach-Object { [Console]::WriteLine($_.PadRight([Console]::WindowWidth - 1)) }
        }
    } catch {
        $ui.Fancy = $false   # latch: never try fancy rendering again this run
    }
}
```

- [ ] **Step 2: Make `Write-Log` panel-aware in `src/lib/Common.ps1`**

Replace the body of `Write-Log` (lines 81-98) with:

```powershell
function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','OK','STEP')][string]$Level = 'INFO'
    )
    $line = "[$Level] $Message"
    # File log always (full detail, regardless of overlay).
    if ($Global:Sel01Tweaker.LogFile) {
        Add-Content -Path $Global:Sel01Tweaker.LogFile -Value $line -Encoding UTF8
    }
    $ui = $Global:Sel01Tweaker.UI
    # Overlay active AND inside a module: drive the panel, keep the screen clean.
    if ($ui -and $ui.Fancy -and $ui.CurrentIdx -gt 0) {
        $ui.ModuleStep++
        if ($Level -eq 'WARN' -or $Level -eq 'ERROR') { $ui.LastMsg = "! $Message" }
        elseif ($Level -ne 'STEP')                    { $ui.LastMsg = $Message }
        Show-Panel
        return
    }
    # Plain mode (non-fancy, or before/after the module loop).
    $color = switch ($Level) {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'STEP'  { 'Cyan' }
        default { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color
}
```

- [ ] **Step 3: Run the checks (regression — no behavior change when non-fancy)**

Run: `powershell -ExecutionPolicy Bypass -File .\tests\run-checks.ps1`
Expected: `ALL CHECKS PASSED` (run-checks output is redirected → `UI` is non-fancy or unset → `Write-Log` takes the plain branch exactly as before).

- [ ] **Step 4: Commit**

```bash
git add src/lib/Ui.ps1 src/lib/Common.ps1
git commit -m "feat(ui): panel render + pipeline hooks + Write-Log overlay routing"
```

---

## Task 3: New module 13 — Network (Nagle off, Gaming only)

**Files:**
- Create: `src/modules/13-Network.ps1`
- Test: manual DryRun smoke

- [ ] **Step 1: Create `src/modules/13-Network.ps1`**

```powershell
# ============================================================================
#  Module 13 - Network / Latency  (Gaming profile only)
#  Disables Nagle's algorithm per active NIC (lower small-packet latency for
#  games). Every write goes through Set-Reg -> snapshotted -> reversible.
# ============================================================================

function Invoke-Module-Network {
    Write-Log '=== Module: Network / Latency (Nagle off) ===' 'STEP'

    if ($Global:Sel01Tweaker.Profile -ne 'Gaming') {
        Write-Log 'Network-Tweaks nur im Gaming-Profil, skip' 'INFO'; return
    }
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
    if (-not (Test-Path $base)) { Write-Log 'Tcpip Interfaces fehlt, skip' 'WARN'; return }

    Get-ChildItem $base -ErrorAction SilentlyContinue | ForEach-Object {
        $guid = $_.PSChildName
        $path = Join-Path $base $guid
        $props = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        $dhcp  = "$($props.DhcpIPAddress)"
        $stat  = "$($props.IPAddress)"
        $hasIp = ($dhcp -and $dhcp -ne '0.0.0.0') -or ($stat -and $stat -ne '0.0.0.0')
        if ($hasIp) {
            Set-Reg $path 'TcpAckFrequency' DWord 1 -Note "Nagle off (TcpAckFrequency) auf $guid"
            Set-Reg $path 'TCPNoDelay'      DWord 1
        }
    }
}
```

- [ ] **Step 2: DryRun smoke (writes nothing)**

Run in an elevated-or-not PowerShell from the repo root:

```powershell
. .\src\lib\Common.ps1; . .\src\lib\Ui.ps1; . .\src\modules\13-Network.ps1
$Global:Sel01Tweaker.DryRun=$true; Initialize-Sel01TweakerState -Stamp 'smoke'
$Global:Sel01Tweaker.Profile='Gaming'; $Global:Sel01Tweaker.Backup=[System.Collections.Generic.List[object]]::new()
Invoke-Module-Network
```

Expected: `[INFO] DRYRUN reg: ...TcpAckFrequency = 1 (DWord)` lines for active NICs, no errors. With `$Global:Sel01Tweaker.Profile='Clean'` it prints the "nur im Gaming-Profil, skip" line.

- [ ] **Step 3: Commit**

```bash
git add src/modules/13-Network.ps1
git commit -m "feat(net): module 13 - disable Nagle per NIC (gaming profile)"
```

---

## Task 4: New module 14 — GPU (NVIDIA telemetry tasks)

**Files:**
- Create: `src/modules/14-Gpu.ps1`
- Test: manual DryRun smoke

- [ ] **Step 1: Create `src/modules/14-Gpu.ps1`**

```powershell
# ============================================================================
#  Module 14 - GPU / NVIDIA telemetry  (only when an NVIDIA GPU is present)
#  Disables NVIDIA telemetry/updater scheduled tasks via Disable-Task (recorded
#  for -Revert). Drivers are never touched (no repack).
# ============================================================================

function Invoke-Module-Gpu {
    Write-Log '=== Module: GPU / NVIDIA Telemetrie ===' 'STEP'

    $nv = $false
    try { $nv = (@(Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object { $_.Name -match 'NVIDIA' }).Count) -gt 0 } catch {}
    if (-not $nv) { Write-Log 'Keine NVIDIA-GPU erkannt, skip' 'INFO'; return }

    $patterns = @('NvTmRep','NvTmMon','NvProfileUpdater','NvDriverUpdate','NvBackend','GFExperience')
    $found = @()
    try {
        $csv = schtasks /Query /FO CSV /NH 2>$null
        foreach ($row in $csv) {
            if (-not $row) { continue }
            $name = ($row -split '","')[0].Trim('"').Trim()
            if (-not $name -or $name -eq 'TaskName') { continue }
            foreach ($pat in $patterns) { if ($name -like "*$pat*") { $found += $name; break } }
        }
    } catch { Write-Log "Task-Liste fehlgeschlagen: $($_.Exception.Message)" 'WARN' }

    $found = $found | Sort-Object -Unique
    if (-not $found) { Write-Log 'Keine NVIDIA-Telemetrie-Tasks gefunden' 'INFO'; return }
    foreach ($t in $found) { Disable-Task $t }
}
```

- [ ] **Step 2: DryRun smoke**

```powershell
. .\src\lib\Common.ps1; . .\src\lib\Ui.ps1; . .\src\modules\14-Gpu.ps1
$Global:Sel01Tweaker.DryRun=$true; Initialize-Sel01TweakerState -Stamp 'smoke'
Invoke-Module-Gpu
```

Expected: on a non-NVIDIA machine, `[INFO] Keine NVIDIA-GPU erkannt, skip`. On an NVIDIA machine, `[INFO] DRYRUN disable task: \NvTmRep_...` lines, no errors.

- [ ] **Step 3: Commit**

```bash
git add src/modules/14-Gpu.ps1
git commit -m "feat(gpu): module 14 - disable NVIDIA telemetry tasks (nvidia only)"
```

---

## Task 5: Small QoL/perf tweaks in module 04

**Files:**
- Modify: `src/modules/04-Performance.ps1`
- Test: existing run-checks (regression) + DryRun smoke

- [ ] **Step 1: Append three new tweak lines before the closing brace of `Invoke-Module-Performance`**

Insert immediately after line 48 (the last `MouseThreshold2` line), before the closing `}`:

```powershell

    # --- Foreground priority boost (classic "optimize for programs") -----
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' DWord 26 -Note 'Foreground priority boost (Win32PrioritySeparation=26)'

    # --- Less disk churn: NTFS last-access updates off (revertable) ------
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'NtfsDisableLastAccessUpdate' DWord 1 -Note 'NTFS last-access updates off'

    # --- No accidental Sticky Keys prompt (5x Shift) ---------------------
    Set-Reg 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags' String '506' -Note 'Sticky-Keys 5x-Shift prompt off'
```

- [ ] **Step 2: Run the checks**

Run: `powershell -ExecutionPolicy Bypass -File .\tests\run-checks.ps1`
Expected: `ALL CHECKS PASSED`.

- [ ] **Step 3: Commit**

```bash
git add src/modules/04-Performance.ps1
git commit -m "feat(perf): Win32PrioritySeparation, NTFS last-access off, sticky-keys prompt off"
```

---

## Task 6: Wire everything in the entry script + bump version

**Files:**
- Modify: `src/Sel01Tweaker.ps1`
- Modify: `src/lib/Common.ps1:14` (version)
- Modify: `build.ps1:16-19` (bundle parts)

- [ ] **Step 1: Bump version in `src/lib/Common.ps1`**

Change line 14 from `Version   = '1.2.0'` to:

```powershell
        Version   = '1.3.0'   # single source of truth - bump on releases (see RELEASING.md)
```

- [ ] **Step 2: Add `Ui.ps1` to the bundle in `build.ps1`**

Replace the `$parts` array (lines 16-19) with:

```powershell
$parts = @(
    (Join-Path $src 'lib\Common.ps1'),
    (Join-Path $src 'lib\Backup.ps1'),
    (Join-Path $src 'lib\Ui.ps1')
) + (Get-ChildItem (Join-Path $src 'modules') -Filter '*.ps1' | Sort-Object Name | ForEach-Object FullName)
```

- [ ] **Step 3: Dot-source `Ui.ps1` in `src/Sel01Tweaker.ps1`**

In the dot-source block (lines 41-44), add the `Ui.ps1` line after `Backup.ps1`:

```powershell
    $root = $PSScriptRoot
    . (Join-Path $root 'lib\Common.ps1')
    . (Join-Path $root 'lib\Backup.ps1')
    . (Join-Path $root 'lib\Ui.ps1')
    Get-ChildItem (Join-Path $root 'modules') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
```

- [ ] **Step 4: Add the two new modules to the pipeline + UI hooks in `Invoke-Pipeline`**

In `src/Sel01Tweaker.ps1`, in the `$steps` array (lines 243-256), insert these two entries right after the `FiveM` line (so order is Gaming → FiveM → **Network → Gpu** → Power):

```powershell
        @{ Name='Network';      Skip=$false;                           Run={ Invoke-Module-Network } },
        @{ Name='Gpu';          Skip=$false;                           Run={ Invoke-Module-Gpu } },
```

Then replace the `foreach ($s in $steps) { ... }` loop (lines 257-260) with:

```powershell
    Initialize-Ui
    $idx = 0
    foreach ($s in $steps) {
        $idx++
        Set-UiModule -Index $idx -Total $steps.Count -Name $s.Name
        if ($s.Skip) { Write-Log "Skipping $($s.Name)" 'WARN'; Complete-UiModule; continue }
        try { & $s.Run } catch { Write-Log "$($s.Name) crashed: $($_.Exception.Message)" 'ERROR' }
        Complete-UiModule
    }
    Complete-UiPanel
```

- [ ] **Step 5: Add the two modules to the `Show-Overview` text**

In `Show-Overview` (after the FiveM line, around line 140), add:

```powershell
    Write-Host '       + Netzwerk    ' -ForegroundColor Cyan -NoNewline; Write-Host 'Nagle aus pro NIC fuer weniger Latenz (nur Gaming)' -ForegroundColor Gray
    Write-Host '       + GPU         ' -ForegroundColor Cyan -NoNewline; Write-Host 'NVIDIA-Telemetrie-Tasks aus (nur NVIDIA)' -ForegroundColor Gray
```

- [ ] **Step 6: Initialize UI early for styled menus**

In `Start-Sel01Tweaker`, immediately after the run-wide options stash (after line 316, before the `# --- Revert ---` block), add:

```powershell
    Initialize-Ui
```

- [ ] **Step 7: Build the bundle (syntax-validates)**

Run: `powershell -ExecutionPolicy Bypass -File .\build.ps1`
Expected: `Built ...dist\Sel01Tweaker.ps1 (NN KB) - syntax OK`. If syntax errors print, fix them before continuing.

- [ ] **Step 8: Run the checks**

Run: `powershell -ExecutionPolicy Bypass -File .\tests\run-checks.ps1`
Expected: `ALL CHECKS PASSED`, including `module Network` / `module Gpu` once Task 7 adds them (they pass already if you reorder — but they are added in Task 7; if missing here, that is expected and added next).

- [ ] **Step 9: Commit**

```bash
git add src/Sel01Tweaker.ps1 src/lib/Common.ps1 build.ps1 dist/Sel01Tweaker.ps1
git commit -m "feat: wire Network/Gpu modules + overlay hooks, bump to 1.3.0"
```

---

## Task 7: Test assertions for new modules + final build/smoke

**Files:**
- Modify: `tests/run-checks.ps1`

- [ ] **Step 1: Add module-existence assertions to `tests/run-checks.ps1`**

After the UI assertions added in Task 1 Step 2, add:

```powershell
ok 'module Network exists' ([bool](Get-Command Invoke-Module-Network -ErrorAction SilentlyContinue))
ok 'module Gpu exists'     ([bool](Get-Command Invoke-Module-Gpu     -ErrorAction SilentlyContinue))
```

- [ ] **Step 2: Run the checks**

Run: `powershell -ExecutionPolicy Bypass -File .\tests\run-checks.ps1`
Expected: `ALL CHECKS PASSED` with `PASS module Network exists` and `PASS module Gpu exists`.

- [ ] **Step 3: Rebuild and confirm the bundle contains the new pieces**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
Select-String -Path .\dist\Sel01Tweaker.ps1 -Pattern 'Invoke-Module-Network','Invoke-Module-Gpu','Initialize-Ui' | Select-Object -ExpandProperty Pattern -Unique
```
Expected: `Built ... - syntax OK`, and all three patterns listed.

- [ ] **Step 4: Full DryRun pipeline smoke via the bundle (writes nothing)**

Run (non-elevated is fine for DryRun; it will print the elevation notice if not admin — to smoke the pipeline, dot-source instead):

```powershell
. .\src\lib\Common.ps1; . .\src\lib\Ui.ps1
Get-ChildItem .\src\modules\*.ps1 | Sort-Object Name | ForEach-Object { . $_.FullName }
$Global:Sel01Tweaker.DryRun=$true; Initialize-Sel01TweakerState -Stamp 'smoke'
$Global:Sel01Tweaker.Profile='Gaming'; $Global:Sel01Tweaker.Backup=[System.Collections.Generic.List[object]]::new()
Initialize-Ui
foreach($m in 'Network','Gpu'){ & "Invoke-Module-$m" }
```

Expected: DryRun reg/task lines, no exceptions.

- [ ] **Step 5: Commit**

```bash
git add tests/run-checks.ps1
git commit -m "test: assert Network/Gpu modules load"
```

---

## Self-review

- **Spec coverage:** overlay lib + detection + fallback (Tasks 1-2, 6); panel & bars (Tasks 1-2); zero-touch Write-Log/pipeline hooks (Task 2, 6); module 13 Network (Task 3); module 14 Gpu (Task 4); small QoL tweaks, duplicates excluded (Task 5); wiring + version + build + Show-Overview (Task 6); tests (Tasks 1,7). Menu/banner restyle is folded into Task 6 Step 6 (`Initialize-Ui` early) — the box-drawing of menus themselves is optional polish; core requirement (run-time overlay) is fully covered.
- **Placeholder scan:** no TBD/TODO; every code step shows full code.
- **Type/name consistency:** `Initialize-Ui`, `Set-UiModule`, `Complete-UiModule`, `Complete-UiPanel`, `Show-Panel`, `Get-Sel01Bar`, `$Global:Sel01Tweaker.UI`, `$Global:Sel01TweakerUiEst`, `Invoke-Module-Network`, `Invoke-Module-Gpu` used consistently across tasks.

## Manual verification (do once at the end, on a real Windows box)

1. In **Windows Terminal**: run `.\dist\Sel01Tweaker.ps1 -DryRun -Profile Gaming` → expect the framed panel with moving bars, no garbled output.
2. **Piped/redirected** (fallback): `.\dist\Sel01Tweaker.ps1 -DryRun -Profile Gaming | Tee-Object out.txt` → expect plain `[LEVEL]` lines, no escape-sequence garbage.
3. **Real run + revert** (a throwaway machine/VM): `-Profile Gaming` then `-Revert` → confirm Nagle keys removed, NVIDIA tasks re-enabled, Win32PrioritySeparation/NTFS/StickyKeys restored.
