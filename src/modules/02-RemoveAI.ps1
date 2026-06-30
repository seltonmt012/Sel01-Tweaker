# ============================================================================
#  Module 02 - RemoveAI  (orchestrates zoicware/RemoveWindowsAI, MIT)
#  Params passed as a hashtable so -nonInteractive binds as a switch and
#  -Options passes as a real string[] (each element validated by the script's
#  ValidateSet). Gaming = lighter option set, Clean = -AllOptions.
#  Recall is Win11-only; the script handles missing components gracefully, so
#  it is safe to run on Windows 10 too (Copilot exists there as well).
# ============================================================================

function Invoke-Module-RemoveAI {
    Write-Log '=== Module: Remove Windows AI ===' 'STEP'

    # --- Native, reliable, reversible AI policy disables (run first) ------
    # The upstream RemoveWindowsAI script does deep appx/CBS surgery that can
    # crash on newer builds (e.g. a settings.dat editor hitting an array value);
    # its failure is caught below and never aborts the run, but the high-value
    # AI switch-offs are documented policy keys we set natively via Set-Reg so
    # they always apply and revert cleanly.
    $copilotHKLM = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
    $copilotHKCU = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
    Set-Reg $copilotHKLM 'TurnOffWindowsCopilot' DWord 1 -Note 'Windows Copilot off (policy)'
    Set-Reg $copilotHKCU 'TurnOffWindowsCopilot' DWord 1
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' DWord 0 -Note 'Copilot taskbar button off'

    $winAiHKLM = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
    $winAiHKCU = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
    Set-Reg $winAiHKLM 'DisableAIDataAnalysis' DWord 1 -Note 'Recall (AI data analysis) off (policy)'
    Set-Reg $winAiHKCU 'DisableAIDataAnalysis' DWord 1
    Set-Reg $winAiHKLM 'DisableClickToDo'      DWord 1 -Note 'Click to Do off (policy)'
    Set-Reg $winAiHKCU 'DisableClickToDo'      DWord 1

    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Notepad' 'DisableAIFeatures' DWord 1 -Note 'Notepad AI features off'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'HubsSidebarEnabled' DWord 0 -Note 'Edge Copilot sidebar off'

    $url = 'https://raw.githubusercontent.com/zoicware/RemoveWindowsAI/main/RemoveWindowsAi.ps1'

    if ($Global:Sel01Tweaker.Profile -eq 'Clean') {
        $params = @{ nonInteractive = $true; AllOptions = $true }
    } else {
        # Gaming: strip Copilot/Recall + re-add protection, skip the heaviest
        # CBS/file surgery to keep the run fast and low-risk.
        $params = @{
            nonInteractive = $true
            Options = @(
                'DisableRegKeys',
                'PreventAIPackageReinstall',
                'DisableCopilotPolicies',
                'RemoveAppxPackages',
                'RemoveRecallFeature',
                'RemoveWindowsAITasks',
                'UpdateCleanupCheck'
            )
        }
    }

    Invoke-Remote -Name 'RemoveWindowsAI' -Url $url -Params $params
}
