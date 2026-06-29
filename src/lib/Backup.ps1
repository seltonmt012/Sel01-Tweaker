# ============================================================================
#  Sel01Tweaker - lib/Backup.ps1
#  System Restore point creation, backup-JSON persistence, and -Revert.
#  Depends on Common.ps1 ($Global:Sel01Tweaker state, Write-Log, Set-Reg helpers).
# ============================================================================

function New-Sel01TweakerRestorePoint {
    <#  Ensures System Restore is enabled on the system drive, then snapshots.
        Windows rate-limits restore points to one per 24h by default; we relax
        that for this run so the checkpoint is guaranteed to take.  #>
    if ($Global:Sel01Tweaker.DryRun) { Write-Log 'DRYRUN restore point' 'INFO'; return }
    try {
        Write-Log 'Creating System Restore point...' 'STEP'
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        # Relax the 24h frequency gate so the checkpoint is not silently skipped.
        Set-Reg -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' `
                -Name 'SystemRestorePointCreationFrequency' -Type DWord -Value 0
        Checkpoint-Computer -Description 'Sel01Tweaker - before optimization' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Log 'Restore point created' 'OK'
    } catch {
        Write-Log "Restore point failed (continuing): $($_.Exception.Message)" 'WARN'
    }
}

function Save-Sel01TweakerBackup {
    <#  Writes the accumulated registry snapshots + run metadata to the backup
        JSON.  Called at the end of a run so -Revert has a manifest.  #>
    if ($Global:Sel01Tweaker.DryRun) { Write-Log 'DRYRUN skip backup write' 'INFO'; return }
    $obj = [ordered]@{
        Profile  = $Global:Sel01Tweaker.Profile
        Created  = $Global:Sel01Tweaker.Stamp
        PowerSchemeGuid = $Global:Sel01Tweaker.PowerSchemeGuid   # minted Ultimate-Performance GUID, if any
        RamTask  = $Global:Sel01Tweaker.RamTaskName              # scheduled task name, if created
        Registry = $Global:Sel01Tweaker.Backup
    }
    $obj | ConvertTo-Json -Depth 6 | Set-Content -Path $Global:Sel01Tweaker.BackupFile -Encoding UTF8
    Write-Log "Backup written: $($Global:Sel01Tweaker.BackupFile)" 'OK'
}

function Get-LatestBackup {
    $files = Get-ChildItem -Path $Global:Sel01Tweaker.DataDir -Filter 'backup-*.json' -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending
    if (-not $files) { return $null }
    return $files[0].FullName
}

function Invoke-Revert {
    <#  Restores every snapshotted registry value, removes the periodic RAM
        scheduled task, and deletes the minted power scheme.  #>
    param([string]$BackupPath)
    if (-not $BackupPath) { $BackupPath = Get-LatestBackup }
    if (-not $BackupPath -or -not (Test-Path $BackupPath)) {
        Write-Log 'No backup file found - nothing to revert.' 'ERROR'
        return
    }
    Write-Log "Reverting from $BackupPath" 'STEP'
    $data = Get-Content -Path $BackupPath -Raw | ConvertFrom-Json

    foreach ($entry in $data.Registry) {
        try {
            if ($entry.Existed) {
                $kind = if ($entry.OldType) { $entry.OldType } else { 'String' }
                $val  = $entry.OldValue
                if ($kind -eq 'Binary' -and $val) { $val = [byte[]]($val | ForEach-Object { [byte]$_ }) }
                if (-not (Test-Path $entry.Path)) { New-Item -Path $entry.Path -Force | Out-Null }
                New-ItemProperty -Path $entry.Path -Name $entry.Name -PropertyType $kind -Value $val -Force | Out-Null
                Write-Log "restored $($entry.Path)\$($entry.Name)" 'INFO'
            } else {
                # Value did not exist before -> remove what we added.
                if (Test-Path $entry.Path) {
                    Remove-ItemProperty -Path $entry.Path -Name $entry.Name -Force -ErrorAction SilentlyContinue
                    Write-Log "removed added $($entry.Path)\$($entry.Name)" 'INFO'
                }
            }
        } catch {
            Write-Log "revert failed for $($entry.Path)\$($entry.Name): $($_.Exception.Message)" 'WARN'
        }
    }

    if ($data.RamTask) {
        try {
            schtasks /Delete /TN $data.RamTask /F 2>$null | Out-Null
            Write-Log "removed scheduled task $($data.RamTask)" 'INFO'
        } catch { Write-Log "task removal failed: $($_.Exception.Message)" 'WARN' }
    }

    if ($data.PowerSchemeGuid) {
        try {
            powercfg /setactive SCHEME_BALANCED 2>$null | Out-Null
            powercfg /delete $data.PowerSchemeGuid 2>$null | Out-Null
            Write-Log "removed power scheme $($data.PowerSchemeGuid), reset to Balanced" 'INFO'
        } catch { Write-Log "power scheme revert failed: $($_.Exception.Message)" 'WARN' }
    }

    Broadcast-SettingChange
    Write-Log 'Revert complete. A sign-out / reboot finalises all changes.' 'OK'
    Write-Log 'Note: apps removed by debloat are NOT reinstalled by revert (use winget/Store).' 'WARN'
}
