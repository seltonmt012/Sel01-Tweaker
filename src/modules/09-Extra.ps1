# ============================================================================
#  Module 09 - Extra  (privacy / QoL, Windows 10 + 11 aware)
#  Safe, reversible additions researched for BOTH OSes. OS-specific bits are
#  gated by $Global:Sel01Tweaker.IsWin11. Everything via Set-Reg (revertable).
#  Deliberately EXCLUDES: ShowSuperHidden, 8.3-name disable, USB-suspend,
#  hibernation-off, HKLM background-app hammer, keyboard repeat, sticky keys,
#  Reserved Storage / Fast Startup (conditional - left to the user).
# ============================================================================

function Invoke-Module-Extra {
    Write-Log '=== Module: Extra privacy / QoL (OS-aware) ===' 'STEP'

    $win11 = $Global:Sel01Tweaker.IsWin11
    $adv   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $cdm   = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'

    # --- Search / assistants (both OSes) ---------------------------------
    Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' DWord 1 -Note 'Web/Bing results off in Start search'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' DWord 0
    Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' DWord 1 -Note 'Copilot taskbar entry hidden'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' DWord 1

    # --- Explorer QoL -----------------------------------------------------
    Set-Reg $adv 'LaunchTo' DWord 1 -Note 'Explorer opens to This PC'
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\NamingTemplates' 'ShortcutNameTemplate' String '"%s.lnk"' -Note 'New shortcuts without "- Shortcut" suffix'
    Set-Reg $adv 'ShowSyncProviderNotifications' DWord 0 -Note 'Explorer ad / OneDrive notifications off'

    # --- Lock-screen tips + Settings suggestions (privacy) ----------------
    Set-Reg $cdm 'RotatingLockScreenOverlayEnabled' DWord 0 -Note 'Lock-screen tips / fun facts off'
    foreach ($v in 'SubscribedContent-338387Enabled','SubscribedContent-338393Enabled',
                    'SubscribedContent-353694Enabled','SubscribedContent-353696Enabled') {
        Set-Reg $cdm $v DWord 0
    }

    # --- Edge background / startup ---------------------------------------
    $edge = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    Set-Reg $edge 'StartupBoostEnabled'   DWord 0 -Note 'Edge startup boost off'
    Set-Reg $edge 'BackgroundModeEnabled' DWord 0 -Note 'Edge background mode off'
    Set-Reg $edge 'HideFirstRunExperience' DWord 1

    # --- Filesystem (SSD-friendly, dev QoL) ------------------------------
    $fs = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
    Set-Reg $fs 'NtfsDisableLastAccessUpdate' DWord 0x80000001 -Note 'NTFS last-access updates off (SSD-friendly)'
    Set-Reg $fs 'LongPathsEnabled' DWord 1 -Note 'Long paths (>260 chars) enabled'

    # --- OS-specific ------------------------------------------------------
    if ($win11) {
        Set-Reg $adv 'Start_TrackDocs' DWord 0 -Note 'Recent docs tracking off (Win11)'
        Set-Reg "$adv\TaskbarDeveloperSettings" 'TaskbarEndTask' DWord 1 -Note 'Taskbar right-click End Task (Win11)'
    } else {
        # Older Win10 builds where the policy key above may not cover web search.
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' DWord 0 -Note 'Bing search off (Win10)'
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent'    DWord 0
    }
}
