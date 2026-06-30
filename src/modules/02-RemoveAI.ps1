# ============================================================================
#  Module 02 - RemoveAI  (NATIVE reimplementation)
#  The upstream zoicware/RemoveWindowsAI script is chronically broken on current
#  Win11 builds (26x00): cascading runtime bugs - an array-index returns the
#  whole @('0','1') array (Object[]->Int32), then an int reaches a [switch]
#  param (Int32->SwitchParameter) - so it aborts before doing anything. Rather
#  than fork its 400KB, we reimplement the high-value, documented, reversible AI
#  switch-offs natively via Set-Reg (like modules 03/04/10 do for winutil), plus
#  a debloat-style removal of the Copilot app. Reliable, no download dependency.
# ============================================================================

function Invoke-Module-RemoveAI {
    Write-Log '=== Module: Remove Windows AI (native) ===' 'STEP'

    # --- Copilot off (policy + shell eligibility + taskbar button) -------
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' DWord 1 -Note 'Windows Copilot off (policy)'
    Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' DWord 1
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' DWord 0 -Note 'Copilot taskbar button off'
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Shell\Copilot\BingChat' 'IsUserEligible' DWord 0 -Note 'Copilot eligibility off'
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Shell\Copilot' 'IsCopilotAvailable' DWord 0

    # --- Recall / Click to Do / Windows AI data analysis off -------------
    $winAiHKLM = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
    $winAiHKCU = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
    Set-Reg $winAiHKLM 'DisableAIDataAnalysis' DWord 1 -Note 'Recall (AI data analysis) off (policy)'
    Set-Reg $winAiHKCU 'DisableAIDataAnalysis' DWord 1
    Set-Reg $winAiHKLM 'DisableClickToDo'      DWord 1 -Note 'Click to Do off (policy)'
    Set-Reg $winAiHKCU 'DisableClickToDo'      DWord 1

    # --- App AI: Notepad, Paint, Edge Copilot sidebar --------------------
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Notepad' 'DisableAIFeatures' DWord 1 -Note 'Notepad AI features off'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'HubsSidebarEnabled' DWord 0 -Note 'Edge Copilot sidebar off'

    # --- Recall optional feature off (Copilot+ 24H2 only; no-op elsewhere) -
    if (-not $Global:Sel01Tweaker.DryRun) {
        try {
            $recall = Get-WindowsOptionalFeature -Online -FeatureName 'Recall' -ErrorAction SilentlyContinue
            if ($recall -and "$($recall.State)" -notlike 'Disabled*') { Disable-Sel01Feature 'Recall' }
        } catch {}
    }

    # --- Remove the Copilot app (debloat-style; like module 01, NOT restored
    #     by -Revert - reinstall from the Store/winget if ever wanted) -------
    if ($Global:Sel01Tweaker.DryRun) {
        Write-Log 'DRYRUN: would remove Copilot app + provisioned package' 'INFO'
        return
    }
    foreach ($pkg in 'Microsoft.Copilot','Microsoft.Windows.Ai.Copilot.Provider') {
        try {
            $p = Get-AppxPackage -AllUsers -Name $pkg -ErrorAction SilentlyContinue
            if ($p) { $p | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue; Write-Log "removed appx: $pkg" 'INFO' }
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -eq $pkg } |
                ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
        } catch { Write-Log "appx remove failed: $pkg -> $($_.Exception.Message)" 'WARN' }
    }
    Add-Change 'Windows AI off (Copilot/Recall/Click-to-Do/Notepad+Edge AI) + Copilot app removed'
}
