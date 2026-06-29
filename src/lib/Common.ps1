# ============================================================================
#  Twerk - lib/Common.ps1
#  Shared helpers: state, logging, registry (typed + snapshot), P/Invoke,
#  remote-script orchestration, preferences-mask builder.
#  All modules dot-source this file and share $Global:Twerk state.
# ============================================================================

# ---------------------------------------------------------------------------
#  Global state (initialised by Twerk.ps1, but guarded here so modules can be
#  dot-sourced and unit-tested in isolation).
# ---------------------------------------------------------------------------
if (-not $Global:Twerk) {
    $Global:Twerk = [ordered]@{
        Profile   = 'Gaming'
        DryRun    = $false
        DataDir   = (Join-Path $env:ProgramData 'Twerk')
        LogFile   = $null
        BackupFile= $null
        Backup    = [System.Collections.Generic.List[object]]::new()
        Changes   = [System.Collections.Generic.List[string]]::new()
        RebootNeeded = $false
    }
}

function Initialize-TwerkState {
    <#  Creates the data dir and timestamped log/backup file paths.
        Timestamp is passed in (Date.now-style calls are avoided in scripted
        contexts; the entry point supplies it).  #>
    param([string]$Stamp)
    if (-not (Test-Path $Global:Twerk.DataDir)) {
        New-Item -ItemType Directory -Path $Global:Twerk.DataDir -Force | Out-Null
    }
    $Global:Twerk.LogFile    = Join-Path $Global:Twerk.DataDir "log-$Stamp.txt"
    $Global:Twerk.BackupFile = Join-Path $Global:Twerk.DataDir "backup-$Stamp.json"
}

# ---------------------------------------------------------------------------
#  Logging
# ---------------------------------------------------------------------------
function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','OK','STEP')][string]$Level = 'INFO'
    )
    $line = "[$Level] $Message"
    $color = switch ($Level) {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'STEP'  { 'Cyan' }
        default { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color
    if ($Global:Twerk.LogFile) {
        Add-Content -Path $Global:Twerk.LogFile -Value $line -Encoding UTF8
    }
}

function Add-Change {
    param([string]$Text)
    $Global:Twerk.Changes.Add($Text) | Out-Null
}

# ---------------------------------------------------------------------------
#  Admin / elevation
# ---------------------------------------------------------------------------
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# ---------------------------------------------------------------------------
#  Network guard (for orchestrated downloads)
# ---------------------------------------------------------------------------
function Test-Online {
    try { return (Test-Connection -ComputerName 'github.com' -Count 1 -Quiet -ErrorAction Stop) }
    catch { return $false }
}

# ---------------------------------------------------------------------------
#  Registry helpers
# ---------------------------------------------------------------------------
function Get-RegValueSafe {
    <#  Returns @{ Exists=$bool; Value=...; Kind=[Microsoft.Win32.RegistryValueKind] }
        Works on a PS-provider path like 'HKCU:\Software\Foo'.  #>
    param([string]$Path,[string]$Name)
    $result = @{ Exists = $false; Value = $null; Kind = $null }
    if (-not (Test-Path $Path)) { return $result }
    $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $result }
    # Resolve the real RegistryValueKind via the .NET key.
    try {
        $rk = Get-Item -Path $Path -ErrorAction Stop
        $kind = $rk.GetValueKind($Name)
        $result.Exists = $true
        $result.Value  = $rk.GetValue($Name)
        $result.Kind   = $kind
    } catch {
        $result.Exists = $true
        $result.Value  = $item.$Name
    }
    return $result
}

function Set-Reg {
    <#  The single typed registry-write entry point used by every module.
        - Snapshots the prior value into the backup list BEFORE writing
          (enables -Revert).
        - Honours DryRun (logs intent, writes nothing).
        - Handles String / ExpandString / DWord / QWord / Binary / MultiString.
        $Value for Binary must be a byte[].  #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('String','ExpandString','DWord','QWord','Binary','MultiString')]
        [string]$Type,
        [Parameter(Mandatory)]$Value,
        [string]$Note
    )

    $prior = Get-RegValueSafe -Path $Path -Name $Name

    # Record snapshot once per (Path,Name) so first-seen original wins.
    $already = $Global:Twerk.Backup | Where-Object { $_.Path -eq $Path -and $_.Name -eq $Name }
    if (-not $already) {
        $snap = [ordered]@{
            Path    = $Path
            Name    = $Name
            Existed = $prior.Exists
            OldType = if ($prior.Kind) { "$($prior.Kind)" } else { $null }
            OldValue= if ($prior.Exists) { $prior.Value } else { $null }
        }
        $Global:Twerk.Backup.Add([pscustomobject]$snap) | Out-Null
    }

    $display = if ($Type -eq 'Binary') { ($Value | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' } else { "$Value" }
    $label = "$Path\$Name = $display ($Type)"

    if ($Global:Twerk.DryRun) {
        Write-Log "DRYRUN reg: $label" 'INFO'
        return
    }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force | Out-Null
        Write-Log "reg: $label" 'INFO'
        if ($Note) { Add-Change $Note }
    } catch {
        Write-Log "reg FAILED: $label -> $($_.Exception.Message)" 'WARN'
    }
}

function Remove-Reg {
    <#  Deletes a value; snapshots first so revert can re-create it.  #>
    param([string]$Path,[string]$Name,[string]$Note)
    $prior = Get-RegValueSafe -Path $Path -Name $Name
    $already = $Global:Twerk.Backup | Where-Object { $_.Path -eq $Path -and $_.Name -eq $Name }
    if (-not $already) {
        $Global:Twerk.Backup.Add([pscustomobject]@{
            Path=$Path; Name=$Name; Existed=$prior.Exists
            OldType= if ($prior.Kind) { "$($prior.Kind)" } else { $null }
            OldValue= if ($prior.Exists) { $prior.Value } else { $null }
        }) | Out-Null
    }
    if ($Global:Twerk.DryRun) { Write-Log "DRYRUN reg-del: $Path\$Name" 'INFO'; return }
    if ((Test-Path $Path) -and $prior.Exists) {
        Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue
        Write-Log "reg-del: $Path\$Name" 'INFO'
        if ($Note) { Add-Change $Note }
    }
}

# ---------------------------------------------------------------------------
#  Service start-type helper (used by winutil-tweak reimplementation)
# ---------------------------------------------------------------------------
function Set-ServiceStart {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Boot','System','Automatic','Manual','Disabled')]
        [string]$StartupType,
        [string]$Note
    )
    # Map to the registry Start DWORD so snapshot/revert flows through Set-Reg.
    $map = @{ Boot=0; System=1; Automatic=2; Manual=3; Disabled=4 }
    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    if (-not (Test-Path $path)) {
        Write-Log "service not present, skip: $Name" 'INFO'
        return
    }
    Set-Reg -Path $path -Name 'Start' -Type DWord -Value $map[$StartupType] -Note $Note
}

# ---------------------------------------------------------------------------
#  UserPreferencesMask builder
#  Deliberate per-byte construction of the "best performance" mask, keeping
#  font-smoothing / drag-full-window behaviour.  Documented value:
#  90 12 03 80 10 00 00 00
# ---------------------------------------------------------------------------
function Build-PreferencesMask {
    # byte0 0x90 = HotTracking(0x80) | GradientCaptions(0x10)
    # byte1 0x12 = TooltipFade(0x10)  | MenuFade(0x02)
    # byte2 0x03, byte3 0x80, byte4 0x10, bytes5-7 0x00  (Win "best performance")
    return [byte[]]@(0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)
}

# ---------------------------------------------------------------------------
#  Broadcast WM_SETTINGCHANGE so UI picks up changes without sign-out.
# ---------------------------------------------------------------------------
function Broadcast-SettingChange {
    if ($Global:Twerk.DryRun) { return }
    if (-not ([System.Management.Automation.PSTypeName]'Twerk.Native').Type) {
        Add-Type -Namespace Twerk -Name Native -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError=true, CharSet=System.Runtime.InteropServices.CharSet.Auto)]
public static extern System.IntPtr SendMessageTimeout(System.IntPtr hWnd, uint Msg, System.IntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out System.IntPtr lpdwResult);
'@ -ErrorAction SilentlyContinue
    }
    try {
        $HWND_BROADCAST = [IntPtr]0xffff
        $WM_SETTINGCHANGE = 0x1A
        $res = [IntPtr]::Zero
        [void][Twerk.Native]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [IntPtr]::Zero, 'Environment', 2, 5000, [ref]$res)
    } catch { Write-Log "Broadcast-SettingChange failed: $($_.Exception.Message)" 'WARN' }
}

function Restart-Explorer {
    if ($Global:Twerk.DryRun) { Write-Log 'DRYRUN restart explorer' 'INFO'; return }
    try {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        # Windows auto-restarts explorer; start one if it didn't.
        Start-Sleep -Milliseconds 800
        if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
        Write-Log 'explorer restarted' 'INFO'
    } catch { Write-Log "explorer restart failed: $($_.Exception.Message)" 'WARN' }
}

# ---------------------------------------------------------------------------
#  Orchestration: download a remote script and invoke it with args.
#  Used by the Win11Debloat / RemoveWindowsAI modules (MIT, run as-is).
# ---------------------------------------------------------------------------
function Invoke-Remote {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Url,
        [string[]]$ArgList = @()
    )
    if ($Global:Twerk.DryRun) {
        Write-Log "DRYRUN orchestrate $Name : $Url $($ArgList -join ' ')" 'INFO'
        return
    }
    if (-not (Test-Online)) {
        Write-Log "Offline - skipping $Name (needs download)" 'WARN'
        return
    }
    try {
        Write-Log "Downloading $Name ..." 'INFO'
        $code = Invoke-RestMethod -Uri $Url -UseBasicParsing -ErrorAction Stop
        $sb = [scriptblock]::Create($code)
        Write-Log "Running $Name $($ArgList -join ' ')" 'INFO'
        & $sb @ArgList
        Write-Log "$Name finished" 'OK'
        Add-Change "$Name applied ($($ArgList -join ' '))"
    } catch {
        Write-Log "$Name failed: $($_.Exception.Message)" 'WARN'
    }
}
