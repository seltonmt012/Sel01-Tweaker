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
    if ($found) { foreach ($t in $found) { Disable-Task $t } }
    else        { Write-Log 'Keine klassischen NVIDIA-Telemetrie-Tasks (modernes NVIDIA App?)' 'INFO' }

    # --- Telemetry opt-out flags (reversible; telemetry only, NOT driver/update) ---
    # NVIDIA's documented "do not participate" RIDs. Harmless if the client isn't
    # installed (Set-Reg creates the value; -Revert removes it again).
    $fts = 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS'
    Set-Reg $fts 'EnableRID44231' DWord 0 -Note 'NVIDIA telemetry opt-out (RID44231)'
    Set-Reg $fts 'EnableRID64640' DWord 0
    Set-Reg $fts 'EnableRID66610' DWord 0
}
