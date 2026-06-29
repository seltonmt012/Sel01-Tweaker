# ============================================================================
#  Module 04 - Performance / Visual Effects  (NATIVE)
#  Replicates the "Adjust for best performance" custom Performance Options
#  state, keeping three effects ON:
#    - Show window contents while dragging  (DragFullWindows = 1)
#    - Smooth edges of screen fonts         (FontSmoothing  = 2)
#    - Show thumbnails instead of icons     (IconsOnly      = 0)
#  Plus transparency/animation off, snappier menus, no startup delay.
# ============================================================================

function Invoke-Module-Performance {
    Write-Log '=== Module: Performance / Visual Effects (native) ===' 'STEP'

    $desktop  = 'HKCU:\Control Panel\Desktop'
    $advanced = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $visualfx = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'

    # Custom visual-effects mode.
    Set-Reg $visualfx 'VisualFXSetting' DWord 3 -Note 'Visual Effects: Custom (best performance + 3 kept)'

    # The "best performance" preferences mask (animations/fades/shadows off).
    Set-Reg $desktop 'UserPreferencesMask' Binary (Build-PreferencesMask)

    # --- The three effects we KEEP ON ------------------------------------
    Set-Reg $desktop  'DragFullWindows' String '1'   -Note 'Keep: window contents while dragging'
    Set-Reg $desktop  'FontSmoothing'   String '2'   -Note 'Keep: smooth screen fonts (ClearType)'
    Set-Reg $advanced 'IconsOnly'       DWord  0     -Note 'Keep: thumbnails instead of icons'

    # --- Effects we turn OFF ---------------------------------------------
    Set-Reg $advanced 'ListviewShadow'      DWord 0
    Set-Reg $advanced 'ListviewAlphaSelect' DWord 0
    Set-Reg $advanced 'TaskbarAnimations'   DWord 0
    Set-Reg $desktop  'MenuShowDelay'       String '0' -Note 'Menu show delay -> 0ms'

    # Window minimize/maximize animation off (accessibility-honored value).
    Set-Reg "$desktop\WindowMetrics" 'MinAnimate' String '0'

    # --- Transparency off -------------------------------------------------
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' DWord 0 -Note 'Transparency off'

    # --- Remove app startup delay ----------------------------------------
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' DWord 0 -Note 'Startup app delay -> 0'

    # Optional: disable mouse acceleration (1:1 input). Applied in both profiles
    # since it never hurts; revertable like everything else.
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed'      String '0' -Note 'Mouse acceleration off'
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' String '0'
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' String '0'
}
