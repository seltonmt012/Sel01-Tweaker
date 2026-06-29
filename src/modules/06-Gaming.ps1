# ============================================================================
#  Module 06 - Gaming  (profile-gated)
#  GameDVR / background capture is disabled in BOTH profiles (pure overhead).
#  Game Mode + Hardware-accelerated GPU Scheduling (HAGS) are kept ON for the
#  Gaming profile (they help gaming) and turned OFF for the Clean profile.
#  HAGS needs WDDM 2.7+ driver and a reboot to take effect.
# ============================================================================

function Invoke-Module-Gaming {
    Write-Log '=== Module: Gaming tweaks ===' 'STEP'

    $gaming = ($Global:Sel01Tweaker.Profile -eq 'Gaming')

    # --- GameDVR / capture OFF (both profiles) ---------------------------
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' DWord 0 -Note 'GameDVR off'
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' DWord 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' DWord 0

    # --- Game Mode + HAGS -------------------------------------------------
    if ($gaming) {
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\GameBar' 'AllowAutoGameMode' DWord 1 -Note 'Game Mode ON (gaming profile)'
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\GameBar' 'AutoGameModeEnabled' DWord 1
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' DWord 2 -Note 'HAGS ON (reboot needed)'
        $Global:Sel01Tweaker.RebootNeeded = $true
    } else {
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\GameBar' 'AllowAutoGameMode' DWord 0 -Note 'Game Mode OFF (clean profile)'
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\GameBar' 'AutoGameModeEnabled' DWord 0
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' DWord 1 -Note 'HAGS OFF (clean profile)'
        $Global:Sel01Tweaker.RebootNeeded = $true
    }

    # --- Multimedia scheduler: favour foreground game responsiveness -----
    $mm = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    # 10 (not 0): leaves a small background guarantee so MMCSS audio threads
    # don't get starved (0 causes sound crackle). 10 is the safe gaming value.
    Set-Reg $mm 'SystemResponsiveness' DWord 10 -Note 'System responsiveness favours foreground (audio-safe 10)'
    if ($gaming) {
        Set-Reg $mm 'NetworkThrottlingIndex' DWord 0xffffffff -Note 'Network throttling off'
    }
    $games = "$mm\Tasks\Games"
    Set-Reg $games 'GPU Priority' DWord 8
    Set-Reg $games 'Priority'     DWord 6
    Set-Reg $games 'Scheduling Category' String 'High'
}
