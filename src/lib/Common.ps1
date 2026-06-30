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
        Version   = '1.8.0'   # single source of truth - bump on releases (see RELEASING.md)
        Profile   = 'Gaming'
        DryRun    = $false
        DataDir   = (Join-Path $env:ProgramData 'Sel01Tweaker')
        LogFile   = $null
        BackupFile= $null
        Backup    = [System.Collections.Generic.List[object]]::new()
        Changes   = [System.Collections.Generic.List[string]]::new()
        TasksDisabled = [System.Collections.Generic.List[string]]::new()
        FeaturesDisabled = [System.Collections.Generic.List[string]]::new()
        CapabilitiesRemoved = [System.Collections.Generic.List[string]]::new()
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
    # File log always (full detail, regardless of overlay). Never let a transient
    # file lock (e.g. an external tool's child process still holding a handle)
    # throw raw red - logging must never crash the run.
    if ($Global:Sel01Tweaker.LogFile) {
        try { Add-Content -Path $Global:Sel01Tweaker.LogFile -Value $line -Encoding UTF8 -ErrorAction Stop }
        catch { try { [System.IO.File]::AppendAllText($Global:Sel01Tweaker.LogFile, "$line`r`n") } catch {} }
    }
    $ui = $Global:Sel01Tweaker.UI
    # Panel suspended (external tool running): file log only, no screen output.
    if ($ui -and $ui.Fancy -and $ui.Suspended) { return }
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
    # TCP 443, not ICMP: many networks block ping while HTTPS works, which would
    # otherwise make Invoke-Remote falsely skip the Debloat/AI downloads.
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $ok = $c.ConnectAsync('github.com', 443).Wait(3000)
        $r = $ok -and $c.Connected
        $c.Close()
        return $r
    } catch { return $false }
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

    # Record snapshot once per (Path,Name) so first-seen original wins. Keep a
    # handle to the exact object added so the catch can drop it if the write fails.
    $snap = $null
    $already = $Global:Sel01Tweaker.Backup | Where-Object { $_.Path -eq $Path -and $_.Name -eq $Name }
    if (-not $already) {
        $snap = [pscustomobject][ordered]@{
            Path    = $Path
            Name    = $Name
            Existed = $prior.Exists
            OldType = if ($prior.Kind) { "$($prior.Kind)" } else { $null }
            OldValue= if ($prior.Exists) { $prior.Value } else { $null }
        }
        $Global:Sel01Tweaker.Backup.Add($snap) | Out-Null
    }

    $display = if ($Type -eq 'Binary') { ($Value | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' } else { "$Value" }
    $label = "$Path\$Name = $display ($Type)"

    if ($Global:Sel01Tweaker.DryRun) {
        Write-Log "DRYRUN reg: $label" 'INFO'
        return
    }

    try {
        # -ErrorAction Stop so a non-terminating PermissionDenied (protected keys
        # like some service hives) is caught here and logged as a clean WARN
        # instead of escaping as raw red console spam.
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force -ErrorAction Stop | Out-Null
        Write-Log "reg: $label" 'INFO'
        if ($Note) { Add-Change $Note }
    } catch {
        # Drop the snapshot we recorded above - the write didn't happen, so revert
        # must not try to "restore" a value we never changed.
        if ($snap) { [void]$Global:Sel01Tweaker.Backup.Remove($snap) }
        Write-Log "reg uebersprungen ($Path\$Name): $($_.Exception.Message)" 'WARN'
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
    # Hard deny-list backstop: never touch security/update/RPC/audio/network/
    # notification core, no matter what a call site asks for.
    $deny = @('WinDefend','SecurityHealthService','wscsvc','Sense','wuauserv','UsoSvc',
              'WaaSMedicSvc','mpssvc','BFE','CryptSvc','EventLog','Winmgmt','RpcSs',
              'RpcEptMapper','DcomLaunch','Audiosrv','AudioEndpointBuilder','Dnscache',
              'NlaSvc','nsi','Dhcp','WpnService','LanmanWorkstation','LanmanServer')
    if ($deny -contains $Name) {
        Write-Log "service geschuetzt, NICHT angefasst: $Name" 'INFO'
        return
    }
    # Map to the registry Start DWORD so snapshot/revert flows through Set-Reg.
    $map = @{ Boot=0; System=1; Automatic=2; Manual=3; Disabled=4 }
    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    if (-not (Test-Path $path)) {
        Write-Log "service not present, skip: $Name" 'INFO'
        return
    }
    Set-Reg -Path $path -Name 'Start' -Type DWord -Value $map[$StartupType] -Note $Note
    # Stop it now (best-effort) so the change takes effect without waiting for the
    # reboot - lowers the live process/service count immediately. Snapshot already
    # recorded the prior Start type, so -Revert restores it regardless.
    if (-not $Global:Sel01Tweaker.DryRun -and ($StartupType -eq 'Disabled' -or $StartupType -eq 'Manual')) {
        try { Stop-Service -Name $Name -Force -ErrorAction Stop } catch {}
    }
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
#  Optional Windows features / capabilities (idempotent + revertable)
#  Records what we actually turned off so -Revert can re-enable / re-add it.
#  DISM changes need a reboot to finalise.
# ---------------------------------------------------------------------------
function Disable-Sel01Feature {
    param([Parameter(Mandatory)][string]$Name)
    $ProgressPreference = 'SilentlyContinue'
    if ($Global:Sel01Tweaker.DryRun) { Write-Log "DRYRUN disable feature: $Name" 'INFO'; return }
    try {
        $f = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction Stop
        if (-not $f) { Write-Log "feature fehlt, skip: $Name" 'INFO'; return }
        if ("$($f.State)" -like 'Disabled*') { $Global:Sel01Tweaker.SkippedCount++; Write-Log "feature schon aus, skip: $Name" 'INFO'; return }
        Disable-WindowsOptionalFeature -Online -FeatureName $Name -NoRestart -ErrorAction Stop | Out-Null
        if (-not ($Global:Sel01Tweaker.FeaturesDisabled -contains $Name)) { $Global:Sel01Tweaker.FeaturesDisabled.Add($Name) | Out-Null }
        $Global:Sel01Tweaker.RebootNeeded = $true
        Write-Log "feature disabled: $Name" 'INFO'
    } catch { Write-Log "feature disable failed: $Name -> $($_.Exception.Message)" 'WARN' }
}

function Remove-Sel01Capability {
    <#  $InstalledCaps is an optional pre-fetched Get-WindowsCapability list (that
        call is slow, so callers can fetch once and pass it in). $Name is a prefix
        before the ~~~~ version suffix.  #>
    param([Parameter(Mandatory)][string]$Name, $InstalledCaps)
    $ProgressPreference = 'SilentlyContinue'
    if ($Global:Sel01Tweaker.DryRun) { Write-Log "DRYRUN remove capability: $Name" 'INFO'; return }
    try {
        if (-not $InstalledCaps) { $InstalledCaps = Get-WindowsCapability -Online -ErrorAction Stop }
        $hits = @($InstalledCaps | Where-Object { $_.Name -like "$Name*" -and "$($_.State)" -eq 'Installed' })
        if (-not $hits) { Write-Log "capability nicht installiert, skip: $Name" 'INFO'; return }
        foreach ($c in $hits) {
            Remove-WindowsCapability -Online -Name $c.Name -ErrorAction Stop | Out-Null
            if (-not ($Global:Sel01Tweaker.CapabilitiesRemoved -contains $c.Name)) { $Global:Sel01Tweaker.CapabilitiesRemoved.Add($c.Name) | Out-Null }
            $Global:Sel01Tweaker.RebootNeeded = $true
            Write-Log "capability removed: $($c.Name)" 'INFO'
        }
    } catch { Write-Log "capability remove failed: $Name -> $($_.Exception.Message)" 'WARN' }
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
    $ProgressPreference = 'SilentlyContinue'
    try {
        Write-Log "Downloading $Name ..." 'INFO'
        $code = Invoke-RestMethod -Uri $Url -UseBasicParsing -ErrorAction Stop
        $sb = [scriptblock]::Create($code)
        Write-Log "Running $Name $shown (Ausgabe -> Log)" 'INFO'
        # The upstream tool prints lots of Write-Host / winget output that would
        # paint over the overlay - park the panel and funnel every stream to the
        # run log, then redraw a fresh panel.
        Suspend-Panel
        # Redirect to a SEPARATE file, never the main log: the external tool can
        # spawn child processes (winget/DISM) that keep the redirected handle open,
        # which would lock our own Write-Log out of the main log file.
        $ext = if ($Global:Sel01Tweaker.LogFile) { $Global:Sel01Tweaker.LogFile -replace '\.txt$','-extern.txt' } else { $null }
        if ($ext) { & $sb @Params *>> $ext } else { & $sb @Params *> $null }
        Resume-Panel
        Write-Log "$Name finished" 'OK'
        Add-Change "$Name applied ($shown)"
    } catch {
        Resume-Panel
        Write-Log "$Name failed: $($_.Exception.Message)" 'WARN'
    }
}
