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
        $hb=[char]0x2550; $vb=[char]0x2551; $ml=[char]0x2560; $mr=[char]0x2563
        $top = "$tl$([string]$hb * $inner)$tr"
        $sep = "$ml$([string]$hb * $inner)$mr"
        $bot = "$bl$([string]$hb * $inner)$br"

        $title  = "$vb$(_pad("  SEL01-TWEAKER   $($Global:Sel01Tweaker.Profile)   v$($Global:Sel01Tweaker.Version)"))$vb"
        $modln  = "$vb$(_pad("  $spin  $($ui.CurrentIdx)/$($ui.Total)  $($ui.Current)"))$vb"
        $modbar = "$vb$(_pad("  $(Get-Sel01Bar $modPct $barW)  $($modPct.ToString().PadLeft(3))%"))$vb"
        $statln = "$vb$(_pad("  $($ui.LastMsg)"))$vb"
        $allbar = "$vb$(_pad("  Gesamt $(Get-Sel01Bar $allPct $barW)  $($ui.Done)/$($ui.Total)"))$vb"

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
