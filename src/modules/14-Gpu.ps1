# ============================================================================
#  Module 14 - GPU telemetry  (NVIDIA + AMD; only the detected vendor runs)
#  Disables vendor telemetry/diagnostic scheduled tasks via Disable-Task
#  (recorded for -Revert) and sets documented telemetry opt-out reg flags.
#  Drivers are never touched (no repack). Driver auto-update tasks are left
#  alone (disabling updates would weaken security). Tasks tied to overclock /
#  fan curves / autostart of the control panel are deliberately NOT touched.
# ============================================================================

function Get-Sel01GpuVendors {
    <#  Returns a set of vendor strings present: 'NVIDIA' and/or 'AMD'.  #>
    $v = @()
    try {
        $names = Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object { $_.Name }
        if ($names -match 'NVIDIA')          { $v += 'NVIDIA' }
        if ($names -match 'AMD|Radeon|ATI')  { $v += 'AMD' }
    } catch {}
    return ($v | Sort-Object -Unique)
}

function Disable-Sel01GpuTasks {
    <#  Disables scheduled tasks whose name matches any of the given patterns.
        Returns the count disabled. Honours DryRun via Disable-Task.  #>
    param([string[]]$Patterns)
    $hits = @()
    try {
        $csv = schtasks /Query /FO CSV /NH 2>$null
        foreach ($row in $csv) {
            if (-not $row) { continue }
            $name = ($row -split '","')[0].Trim('"').Trim()
            if (-not $name -or $name -eq 'TaskName') { continue }
            foreach ($pat in $Patterns) { if ($name -like "*$pat*") { $hits += $name; break } }
        }
    } catch { Write-Log "Task-Liste fehlgeschlagen: $($_.Exception.Message)" 'WARN' }
    $hits = $hits | Sort-Object -Unique
    foreach ($t in $hits) { Disable-Task $t }
    return $hits.Count
}

function Invoke-Module-Gpu {
    Write-Log '=== Module: GPU-Telemetrie (NVIDIA / AMD) ===' 'STEP'

    $vendors = Get-Sel01GpuVendors
    if (-not $vendors) { Write-Log 'Keine NVIDIA/AMD-GPU erkannt, skip' 'INFO'; return }

    # ---------------- NVIDIA ----------------
    if ($vendors -contains 'NVIDIA') {
        Write-Log 'NVIDIA erkannt' 'INFO'
        $n = Disable-Sel01GpuTasks -Patterns @('NvTmRep','NvTmMon','NvProfileUpdater','NvBackend','GFExperience')
        if ($n -eq 0) { Write-Log 'Keine klassischen NVIDIA-Telemetrie-Tasks (modernes NVIDIA App?)' 'INFO' }
        # Documented "do not participate" RIDs. Harmless if client absent
        # (Set-Reg creates the value; -Revert removes it again).
        $fts = 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS'
        Set-Reg $fts 'EnableRID44231' DWord 0 -Note 'NVIDIA telemetry opt-out (RID44231)'
        Set-Reg $fts 'EnableRID64640' DWord 0
        Set-Reg $fts 'EnableRID66610' DWord 0
    }

    # ---------------- AMD -------------------
    if ($vendors -contains 'AMD') {
        Write-Log 'AMD/Radeon erkannt' 'INFO'
        # Telemetry/diagnostic/auto-update tasks only. NOT 'StartCN' (Radeon
        # autostart) so fan curves / overclock profiles at boot keep working.
        $n = Disable-Sel01GpuTasks -Patterns @('AMD*Telemetry','AMD Crash','AMDLink','AMDInstallLauncher','AMDRyzenMasterSDK')
        if ($n -eq 0) { Write-Log 'Keine AMD-Telemetrie-/Update-Tasks gefunden' 'INFO' }
        # AMD "User Experience / Survey" opt-out (Radeon Software). Reversible;
        # harmless if the keys do not apply to the installed version.
        Set-Reg 'HKCU:\SOFTWARE\AMD\CN' 'UserExperienceProgram' DWord 0 -Note 'AMD User-Experience telemetry opt-out'
        Set-Reg 'HKCU:\SOFTWARE\AMD\CN' 'OnlineSurvey'          DWord 0
    }
}
