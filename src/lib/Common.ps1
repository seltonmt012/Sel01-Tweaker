# ============================================================================
#  Sel01Tweaker - lib/Common.ps1
#  Shared helpers: state, logging, registry (typed + snapshot), P/Invoke,
#  remote-script orchestration, preferences-mask builder.
#  All modules dot-source this file and share $Global:Sel01Tweaker state.
# ============================================================================

# ---------------------------------------------------------------------------
#  Global state (initialised by Sel01Tweaker.ps1, but guarded here so modules can be
#  dot-sourced and unit-tested in isolation).
# ---------------------------------------------------------------------------
if (-not $Global:Sel01Tweaker) {
    $Global:Sel01Tweaker = [ordered]@{
        Version   = '1.1.2'   # single source of truth - bump on releases (see RELEASING.md)
        Profile   = 'Gaming'
        DryRun    = $false
        DataDir   = (Join-Path $env:ProgramData 'Sel01Tweaker')
        LogFile   = $null
        BackupFile= $null
        Backup    = [System.Collections.Generic.List[object]]::new()
        Changes   = [System.Collections.Generic.List[string]]::new()
        TasksDisabled = [System.Collections.Generic.List[string]]::new()
        RebootNeeded = $false
        SkippedCount = 0
        IsWin11   = $true
        OSBuild   = 0
        OSName    = 'Windows'
        IsLaptop  = $false
        OnBattery = $false
    }
}

function Get-Sel01PowerInfo {
    <#  Detects laptop vs desktop and AC vs battery so power tweaks can be
        skipped on portables / on battery (where they hurt battery / devices).  #>
    $bat = $null
    try { $bat = Get-CimInstance Win32_Battery -ErrorAction Stop } catch {}
    $chassis = @()
    try { $chassis = @((Get-CimInstance Win32_SystemEnclosure -ErrorAction Stop).ChassisTypes) } catch {}
    $laptopChassis = 8,9,10,11,12,14,18,21,30,31,32   # portable/laptop/notebook/tablet/convertible
    $isLaptop = ($null -ne $bat) -or (($chassis | Where-Object { $laptopChassis -contains $_ }).Count -gt 0)
    $onBattery = $false
    if ($bat) { $onBattery = (@($bat)[0].BatteryStatus -eq 1) }   # 1 = discharging
    $Global:Sel01Tweaker.IsLaptop  = [bool]$isLaptop
    $Global:Sel01Tweaker.OnBattery = [bool]$onBattery
}

function Get-Sel01OSInfo {
    <#  Detects Windows 10 vs 11. [Environment]::OSVersion reports 10.0.x for
        BOTH, so we use the build number: Win11 = build >= 22000. ProductName
        also lies ("Windows 10" on 11), so the friendly name is derived from
        the build + DisplayVersion.  #>
    $cv = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = 0
    try { $build = [int](Get-ItemProperty $cv -Name CurrentBuildNumber -ErrorAction Stop).CurrentBuildNumber } catch {}
    if ($build -eq 0) { try { $build = [Environment]::OSVersion.Version.Build } catch {} }
    $disp = ''
    try { $disp = (Get-ItemProperty $cv -Name DisplayVersion -ErrorAction Stop).DisplayVersion } catch {}
    $isWin11 = ($build -ge 22000)
    $Global:Sel01Tweaker.IsWin11 = $isWin11
    $Global:Sel01Tweaker.OSBuild = $build
    $Global:Sel01Tweaker.OSName  = ('Windows {0}{1}' -f ($(if ($isWin11) {'11'} else {'10'})), $(if ($disp) {" $disp"} else {''}))
    return $Global:Sel01Tweaker.OSName
}

function Initialize-Sel01TweakerState {
    <#  Creates the data dir and timestamped log/backup file paths.
        Timestamp is passed in (Date.now-style calls are avoided in scripted
        contexts; the entry point supplies it).  #>
    param([string]$Stamp)
    if (-not (Test-Path $Global:Sel01Tweaker.DataDir)) {
        New-Item -ItemType Directory -Path $Global:Sel01Tweaker.DataDir -Force | Out-Null
    }
    $Global:Sel01Tweaker.LogFile    = Join-Path $Global:Sel01Tweaker.DataDir "log-$Stamp.txt"
    $Global:Sel01Tweaker.BackupFile = Join-Path $Global:Sel01Tweaker.DataDir "backup-$Stamp.json"
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
    if ($Global:Sel01Tweaker.LogFile) {
        Add-Content -Path $Global:Sel01Tweaker.LogFile -Value $line -Encoding UTF8
    }
}

function Add-Change {
    param([string]$Text)
    $Global:Sel01Tweaker.Changes.Add($Text) | Out-Null
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

function Test-RegValueEqual {
    <#  True when an existing registry value already equals the target, so the
        write can be skipped (idempotency - never re-force what's already set).
        Normalises DWORD to uint32 so e.g. 0x80000001 (stored as int32 -2147...)
        compares equal to the long literal.  #>
    param($Current,[string]$Type,$Target)
    switch ($Type) {
        'Binary' {
            $a = [byte[]]$Current; $b = [byte[]]$Target
            if ($a.Length -ne $b.Length) { return $false }
            for ($i=0; $i -lt $a.Length; $i++) { if ($a[$i] -ne $b[$i]) { return $false } }
            return $true
        }
        'DWord' { return ((([int64]$Current) -band 0xFFFFFFFF) -eq (([int64]$Target) -band 0xFFFFFFFF)) }
        'QWord' { return ([int64]$Current -eq [int64]$Target) }
        'MultiString' { return ((@($Current) -join "`0") -eq (@($Target) -join "`0")) }
        default { return ([string]$Current -eq [string]$Target) }   # String / ExpandString
    }
}

function Set-Reg {
    <#  The single typed registry-write entry point used by every module.
        - If the value is ALREADY correct, skips (no snapshot, no write, no
          change recorded) so re-runs don't re-force settings you already have.
        - Otherwise snapshots the prior value BEFORE writing (enables -Revert).
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

    # --- Idempotency: already correct? skip entirely ----------------------
    if ($prior.Exists -and ("$($prior.Kind)" -eq $Type) -and (Test-RegValueEqual $prior.Value $Type $Value)) {
        $Global:Sel01Tweaker.SkippedCount++
        Write-Log "schon ok, skip: $Path\$Name" 'INFO'
        return
    }

    # Record snapshot once per (Path,Name) so first-seen original wins.
    $already = $Global:Sel01Tweaker.Backup | Where-Object { $_.Path -eq $Path -and $_.Name -eq $Name }
    if (-not $already) {
        $snap = [ordered]@{
            Path    = $Path
            Name    = $Name
            Existed = $prior.Exists
            OldType = if ($prior.Kind) { "$($prior.Kind)" } else { $null }
            OldValue= if ($prior.Exists) { $prior.Value } else { $null }
        }
        $Global:Sel01Tweaker.Backup.Add([pscustomobject]$snap) | Out-Null
    }

    $display = if ($Type -eq 'Binary') { ($Value | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' } else { "$Value" }
    $label = "$Path\$Name = $display ($Type)"

    if ($Global:Sel01Tweaker.DryRun) {
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
    # Idempotency: nothing there -> nothing to remove.
    if (-not $prior.Exists) { $Global:Sel01Tweaker.SkippedCount++; Write-Log "schon weg, skip: $Path\$Name" 'INFO'; return }
    $already = $Global:Sel01Tweaker.Backup | Where-Object { $_.Path -eq $Path -and $_.Name -eq $Name }
    if (-not $already) {
        $Global:Sel01Tweaker.Backup.Add([pscustomobject]@{
            Path=$Path; Name=$Name; Existed=$prior.Exists
            OldType= if ($prior.Kind) { "$($prior.Kind)" } else { $null }
            OldValue= if ($prior.Exists) { $prior.Value } else { $null }
        }) | Out-Null
    }
    if ($Global:Sel01Tweaker.DryRun) { Write-Log "DRYRUN reg-del: $Path\$Name" 'INFO'; return }
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
#  Scheduled task disable (idempotent + revertable)
#  Records each task we actually disable so -Revert can re-enable it.
# ---------------------------------------------------------------------------
function Disable-Task {
    param([Parameter(Mandatory)][string]$Path)
    if ($Global:Sel01Tweaker.DryRun) { Write-Log "DRYRUN disable task: $Path" 'INFO'; return }
    try {
        $info = schtasks /Query /TN $Path /FO LIST 2>$null
        if (-not $info) { Write-Log "task fehlt, skip: $Path" 'INFO'; return }
        if ($info -match 'Disabled|Deaktiviert') {
            $Global:Sel01Tweaker.SkippedCount++; Write-Log "task schon aus, skip: $Path" 'INFO'; return
        }
        schtasks /Change /TN $Path /Disable 2>$null | Out-Null
        if (-not ($Global:Sel01Tweaker.TasksDisabled -contains $Path)) {
            $Global:Sel01Tweaker.TasksDisabled.Add($Path) | Out-Null
        }
        Write-Log "task disabled: $Path" 'INFO'
    } catch { Write-Log "task disable failed: $Path -> $($_.Exception.Message)" 'WARN' }
}

# ---------------------------------------------------------------------------
#  Machine environment variable (revertable via Set-Reg snapshot)
# ---------------------------------------------------------------------------
function Set-MachineEnv {
    param([Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][string]$Value,[string]$Note)
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' $Name String $Value -Note $Note
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
    if ($Global:Sel01Tweaker.DryRun) { return }
    if (-not ([System.Management.Automation.PSTypeName]'Sel01Tweaker.Native').Type) {
        Add-Type -Namespace Sel01Tweaker -Name Native -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError=true, CharSet=System.Runtime.InteropServices.CharSet.Auto)]
public static extern System.IntPtr SendMessageTimeout(System.IntPtr hWnd, uint Msg, System.IntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out System.IntPtr lpdwResult);
'@ -ErrorAction SilentlyContinue
    }
    try {
        $HWND_BROADCAST = [IntPtr]0xffff
        $WM_SETTINGCHANGE = 0x1A
        $res = [IntPtr]::Zero
        [void][Sel01Tweaker.Native]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [IntPtr]::Zero, 'Environment', 2, 5000, [ref]$res)
    } catch { Write-Log "Broadcast-SettingChange failed: $($_.Exception.Message)" 'WARN' }
}

function Restart-Explorer {
    if ($Global:Sel01Tweaker.DryRun) { Write-Log 'DRYRUN restart explorer' 'INFO'; return }
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
    # Params is a hashtable splatted by NAME into the downloaded script. Use a
    # hashtable (not a flat -Flag array) so switch params bind reliably and
    # array params (e.g. RemoveWindowsAI -Options) pass as real arrays that pass
    # the script's ValidateSet element-by-element.
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Url,
        [hashtable]$Params = @{}
    )
    $shown = (($Params.GetEnumerator() | Sort-Object Name | ForEach-Object {
        if     ($_.Value -is [bool])  { "-$($_.Key)" }
        elseif ($_.Value -is [array]) { "-$($_.Key) $($_.Value -join ',')" }
        else                          { "-$($_.Key) $($_.Value)" }
    }) -join ' ')

    if ($Global:Sel01Tweaker.DryRun) {
        Write-Log "DRYRUN orchestrate $Name : $Url $shown" 'INFO'
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
        Write-Log "Running $Name $shown" 'INFO'
        & $sb @Params
        Write-Log "$Name finished" 'OK'
        Add-Change "$Name applied ($shown)"
    } catch {
        Write-Log "$Name failed: $($_.Exception.Message)" 'WARN'
    }
}
