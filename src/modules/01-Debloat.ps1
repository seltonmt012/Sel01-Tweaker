# ============================================================================
#  Module 01 - Debloat  (orchestrates Raphire/Win11Debloat, MIT)
#  Downloads and runs the upstream script silently with a per-profile flag set.
#  Skipped automatically when offline or -SkipDebloat.
# ============================================================================

function Invoke-Module-Debloat {
    Write-Log '=== Module: Debloat (Win11Debloat) ===' 'STEP'

    $url = 'https://debloat.raphi.re/'   # official redirect to latest Win11Debloat.ps1

    # Shared flags applied in both profiles.
    $common = @(
        '-RemoveApps',
        '-DisableTelemetry',
        '-DisableBing',
        '-DisableSuggestions',
        '-DisableLockscreenTips',
        '-DisableSettingsHome',
        '-DisableSettings365Ads',
        '-RevertContextMenu',
        '-DisableMouseAcceleration',
        '-ShowKnownFileExt',
        '-Silent'
    )

    # Clean profile = more aggressive; gaming keeps gaming apps + Game Bar intact
    # (Game Bar / DVR is handled deliberately in module 06 per profile).
    $cleanExtra = @(
        '-RemoveGamingApps',
        '-DisableWidgets',
        '-DisableCopilot',
        '-DisableRecall',
        '-DisableChat',
        '-DisableDesktopSpotlight'
    )

    $args = if ($Global:Sel01Tweaker.Profile -eq 'Clean') { $common + $cleanExtra } else { $common }

    Invoke-Remote -Name 'Win11Debloat' -Url $url -ArgList $args
}
