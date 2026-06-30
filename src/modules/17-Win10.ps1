# ============================================================================
#  Module 17 - Windows 10 specific  (only runs on Win10: -not IsWin11)
#  Tweaks that are Win10-only or use Win10 paths a Win11-era tool would miss.
#  All via Set-Reg / Set-ServiceStart -> snapshotted + reversible. No-ops on
#  Win11 (the whole module is gated off). Researched, low-risk, both profiles.
# ============================================================================

function Invoke-Module-Win10 {
    Write-Log '=== Module: Windows 10 specific ===' 'STEP'

    if ($Global:Sel01Tweaker.IsWin11) {
        Write-Log 'Windows 11 erkannt - Win10-Modul uebersprungen' 'INFO'
        return
    }

    # --- Classic Cortana off ---------------------------------------------
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' DWord 0 -Note 'Cortana off (Win10)'

    # --- Bing / web results in Win10 Start search off --------------------
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchUseWeb' DWord 0 -Note 'Web search in Start off (Win10)'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch'      DWord 1
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled'       DWord 0
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent'          DWord 0

    # --- Taskbar clutter: My People + sync-provider ads ------------------
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People' 'PeopleBand' DWord 0 -Note 'My People taskbar off (Win10)'
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' DWord 0 -Note 'Explorer OneDrive/Office ads off (Win10)'

    # --- First-logon animation off (faster first sign-in) ----------------
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableFirstLogonAnimation' DWord 0 -Note 'First-logon animation off (Win10)'

    # --- Edge Legacy preload/prelaunch off (no-op if absent) -------------
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main' 'AllowPrelaunch' DWord 0 -Note 'Edge Legacy preload off (Win10)'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader' 'AllowTabPreloading' DWord 0

    # --- Win10 diagnostics standard collector service off ----------------
    Set-ServiceStart 'diagnosticshub.standardcollector.service' Disabled -Note 'Diagnostics collector off (Win10)'
}
