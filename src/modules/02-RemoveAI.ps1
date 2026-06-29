# ============================================================================
#  Module 02 - RemoveAI  (orchestrates zoicware/RemoveWindowsAI, MIT)
#  Runs the upstream script non-interactively. Gaming = lighter option set,
#  Clean = -AllOptions. Skipped when offline or -SkipAI.
# ============================================================================

function Invoke-Module-RemoveAI {
    Write-Log '=== Module: Remove Windows AI ===' 'STEP'

    $url = 'https://raw.githubusercontent.com/zoicware/RemoveWindowsAI/main/RemoveWindowsAi.ps1'

    if ($Global:Sel01Tweaker.Profile -eq 'Clean') {
        $args = @('-nonInteractive', '-AllOptions')
    } else {
        # Gaming: strip Copilot/Recall + re-add protection, but skip the heaviest
        # CBS/file surgery to keep the run fast and low-risk on a gaming box.
        $args = @(
            '-nonInteractive',
            '-Options', 'DisableRegKeys,PreventAIPackageReinstall,DisableCopilotPolicies,RemoveAppxPackages,RemoveRecallFeature,RemoveWindowsAITasks,UpdateCleanupCheck'
        )
    }

    Invoke-Remote -Name 'RemoveWindowsAI' -Url $url -ArgList $args
}
