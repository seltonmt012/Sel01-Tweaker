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
