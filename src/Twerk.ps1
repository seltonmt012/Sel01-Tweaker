#Requires -Version 5.1
<#
.SYNOPSIS
    Twerk - one-click Windows 11 debloat + performance optimizer.
.DESCRIPTION
    Runs a single unattended pass: debloat (Win11Debloat), AI removal
    (RemoveWindowsAI), native winutil-style tweaks, performance/visual effects,
    Ultimate Performance power plan, gaming tweaks, and a native RAM cleaner.
    Creates a System Restore point and a registry backup enabling -Revert.
.PARAMETER Profile
    Gaming (default) keeps Game Mode + HAGS on and is gentler on services.
    Clean is maximum debloat.
.PARAMETER Revert
    Undo a previous run from the latest backup JSON.
.EXAMPLE
    & ([scriptblock]::Create((irm https://example/twerk.ps1))) -Profile Gaming
.EXAMPLE
    .\Twerk.ps1 -Profile Clean
.EXAMPLE
    .\Twerk.ps1 -Revert
#>
[CmdletBinding()]
param(
    [ValidateSet('Gaming','Clean')]
    [string]$Profile = 'Gaming',
    [switch]$Revert,
    [switch]$NoRestore,
    [switch]$SkipDebloat,
    [switch]$SkipAI,
    [switch]$NoRamTask,
    [switch]$DryRun
)

#__TWERK_BUNDLE_INSERT__
# ---------------------------------------------------------------------------
#  Load parts. When bundled into dist\Twerk.ps1 the functions already exist,
#  so dot-sourcing is skipped. When running from src\, pull lib + modules.
# ---------------------------------------------------------------------------
if (-not (Get-Command Invoke-Module-Performance -ErrorAction SilentlyContinue)) {
    $root = $PSScriptRoot
    . (Join-Path $root 'lib\Common.ps1')
    . (Join-Path $root 'lib\Backup.ps1')
    Get-ChildItem (Join-Path $root 'modules') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
}

function Start-Twerk {
    param($Profile,$Revert,$NoRestore,$SkipDebloat,$SkipAI,$NoRamTask,$DryRun)

    # --- Self-elevate -----------------------------------------------------
    if (-not (Test-Admin)) {
        if ($PSCommandPath) {
            Write-Host 'Twerk needs administrator rights - relaunching elevated...' -ForegroundColor Yellow
            $argline = @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"","-Profile",$Profile)
            if ($Revert)      { $argline += '-Revert' }
            if ($NoRestore)   { $argline += '-NoRestore' }
            if ($SkipDebloat) { $argline += '-SkipDebloat' }
            if ($SkipAI)      { $argline += '-SkipAI' }
            if ($NoRamTask)   { $argline += '-NoRamTask' }
            if ($DryRun)      { $argline += '-DryRun' }
            Start-Process powershell.exe -Verb RunAs -ArgumentList $argline
            return
        } else {
            Write-Host 'ERROR: Run this in an ELEVATED PowerShell (Run as Administrator).' -ForegroundColor Red
            return
        }
    }

    # --- State init -------------------------------------------------------
    $Global:Twerk.Profile = $Profile
    $Global:Twerk.DryRun  = [bool]$DryRun
    $Global:Twerk.Stamp   = (Get-Date -Format 'yyyyMMdd-HHmmss')
    Initialize-TwerkState -Stamp $Global:Twerk.Stamp

    Write-Log "Twerk starting | Profile=$Profile | DryRun=$($Global:Twerk.DryRun)" 'STEP'

    # --- Revert branch ----------------------------------------------------
    if ($Revert) {
        Invoke-Revert
        return
    }

    # --- Safety -----------------------------------------------------------
    if (-not $NoRestore) { New-TwerkRestorePoint } else { Write-Log 'Restore point skipped (-NoRestore)' 'WARN' }

    # --- Run modules (failures non-fatal) ---------------------------------
    $steps = @(
        @{ Name='Debloat';    Skip=$SkipDebloat; Run={ Invoke-Module-Debloat } },
        @{ Name='RemoveAI';   Skip=$SkipAI;      Run={ Invoke-Module-RemoveAI } },
        @{ Name='WinutilTweaks'; Skip=$false;    Run={ Invoke-Module-WinutilTweaks } },
        @{ Name='Performance';   Skip=$false;    Run={ Invoke-Module-Performance } },
        @{ Name='PowerPlan';     Skip=$false;    Run={ Invoke-Module-PowerPlan } },
        @{ Name='Gaming';        Skip=$false;    Run={ Invoke-Module-Gaming } },
        @{ Name='RamCleaner';    Skip=$false;    Run={ Invoke-Module-RamCleaner -NoTask:$NoRamTask } }
    )
    foreach ($s in $steps) {
        if ($s.Skip) { Write-Log "Skipping $($s.Name)" 'WARN'; continue }
        try { & $s.Run } catch { Write-Log "$($s.Name) crashed: $($_.Exception.Message)" 'ERROR' }
    }

    # --- Apply live + persist backup --------------------------------------
    Broadcast-SettingChange
    Restart-Explorer
    Save-TwerkBackup

    # --- Summary ----------------------------------------------------------
    Write-Log '============ SUMMARY ============' 'STEP'
    foreach ($c in $Global:Twerk.Changes) { Write-Log " - $c" 'OK' }
    Write-Log "Backup: $($Global:Twerk.BackupFile)" 'INFO'
    Write-Log "Log:    $($Global:Twerk.LogFile)" 'INFO'
    Write-Log "Undo with:  .\Twerk.ps1 -Revert" 'INFO'
    if ($Global:Twerk.RebootNeeded) { Write-Log 'REBOOT recommended (HAGS / power plan).' 'WARN' }
    Write-Log 'Done.' 'OK'
}

Start-Twerk -Profile $Profile -Revert:$Revert -NoRestore:$NoRestore -SkipDebloat:$SkipDebloat -SkipAI:$SkipAI -NoRamTask:$NoRamTask -DryRun:$DryRun
