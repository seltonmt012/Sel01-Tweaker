# ============================================================================
#  Module 01 - Debloat  (orchestrates Raphire/Win11Debloat, MIT)
#  Downloads and runs the upstream script silently. Params are passed as a
#  hashtable (named/splatted) so switches bind reliably. Win11Debloat itself
#  supports Windows 10 and 11. Skipped when offline or -SkipDebloat.
# ============================================================================

function Invoke-Module-Debloat {
    Write-Log '=== Module: Debloat (Win11Debloat) ===' 'STEP'

    $url = 'https://debloat.raphi.re/'   # official redirect to latest Win11Debloat.ps1

    # Shared across both profiles.
    $params = @{
        RemoveApps             = $true
        DisableTelemetry       = $true
        DisableBing            = $true
        DisableSuggestions     = $true
        DisableLockscreenTips  = $true
        DisableSettingsHome    = $true
        DisableSettings365Ads  = $true
        RevertContextMenu      = $true
        DisableMouseAcceleration = $true
        ShowKnownFileExt       = $true
        Silent                 = $true
    }

    # Clean = more aggressive. Gaming keeps gaming apps + Game Bar (handled in 06).
    if ($Global:Sel01Tweaker.Profile -eq 'Clean') {
        $params += @{
            RemoveGamingApps    = $true
            DisableWidgets      = $true
            DisableCopilot      = $true
            DisableRecall       = $true
            HideChat            = $true
            DisableDesktopSpotlight = $true
        }
    }

    Invoke-Remote -Name 'Win11Debloat' -Url $url -Params $params
}
