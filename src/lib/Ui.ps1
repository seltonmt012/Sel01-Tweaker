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
