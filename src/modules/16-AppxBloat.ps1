# ============================================================================
#  Module 16 - App-Bloat (NATIVE appx removal, download-independent)
#  Removes pre-installed Store apps that auto-start / sync / fetch in the
#  background (Teams, new Outlook, Phone Link, Cortana, Bing apps, ...) by name -
#  works even when the Win11Debloat download was skipped (offline). Appx removal
#  is debloat-style and NOT restored by -Revert (reinstall from the Store).
#  GAMING keeps Game Bar + Gaming App; those go only in the Clean profile.
# ============================================================================

function Remove-Sel01Appx {
    param([Parameter(Mandatory)][string]$Name)
    if ($Global:Sel01Tweaker.DryRun) { Write-Log "DRYRUN appx remove: $Name" 'INFO'; return }
    try {
        $p = Get-AppxPackage -AllUsers -Name $Name -ErrorAction SilentlyContinue
        if ($p) {
            $p | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Write-Log "appx removed: $Name" 'INFO'
            Add-Change "App entfernt: $Name"
        }
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq $Name } |
            ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -AllUsers -ErrorAction SilentlyContinue | Out-Null }
    } catch { Write-Log "appx remove failed: $Name -> $($_.Exception.Message)" 'WARN' }
}

function Invoke-Module-AppxBloat {
    Write-Log '=== Module: App-Bloat entfernen (nativ) ===' 'STEP'

    # Both profiles: background processes / auto-start first.
    $both = @(
        'Microsoft.YourPhone','Microsoft.OutlookForWindows','MSTeams','MicrosoftTeams',
        'Microsoft.549981C3F5F4','Microsoft.Windows.DevHome','Microsoft.PowerAutomateDesktop',
        'Microsoft.BingSearch','Microsoft.BingNews','Microsoft.BingWeather','Microsoft.MicrosoftOfficeHub',
        'Microsoft.People','Microsoft.Todos','Microsoft.GetHelp','Microsoft.WindowsFeedbackHub',
        'Microsoft.WindowsMaps','MicrosoftCorporationII.QuickAssist','MicrosoftCorporationII.MicrosoftFamily',
        'Clipchamp.Clipchamp','Microsoft.MicrosoftSolitaireCollection','Microsoft.Microsoft3DViewer',
        'Microsoft.MixedReality.Portal','Microsoft.SkypeApp','Microsoft.XboxSpeechToTextOverlay',
        'Microsoft.Getstarted','Microsoft.Print3D'
    )
    foreach ($a in $both) { Remove-Sel01Appx $a }

    # Clean only (Office box, no gaming) - includes Widgets host + media + mail.
    # GAMING KEEPS: Microsoft.GamingApp, Microsoft.XboxGamingOverlay (Game Bar).
    if ($Global:Sel01Tweaker.Profile -eq 'Clean') {
        foreach ($a in 'MicrosoftWindows.Client.WebExperience','Microsoft.ZuneMusic','Microsoft.ZuneVideo',
                        'Microsoft.WindowsCommunicationsApps','Microsoft.MicrosoftStickyNotes',
                        'Microsoft.BingNews','MicrosoftWindows.CrossDevice',
                        'Microsoft.GamingApp','Microsoft.XboxGamingOverlay') {
            Remove-Sel01Appx $a
        }
    }
}
