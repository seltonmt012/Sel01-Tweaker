# ============================================================================
#  Module 03 - Winutil Tweaks  (NATIVE reimplementation)
#  winutil (ChrisTitusTech, MIT) has no real headless apply in the current
#  release, so the relevant "Essential Tweaks" are reimplemented here directly
#  from the declarative registry / service / scheduled-task data in its
#  config/tweaks.json. Every change flows through Set-Reg -> snapshot -> revert.
# ============================================================================

function Invoke-Module-WinutilTweaks {
    Write-Log '=== Module: Winutil Essential Tweaks (native) ===' 'STEP'

    $clean = ($Global:Sel01Tweaker.Profile -eq 'Clean')

    # --- Telemetry --------------------------------------------------------
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' DWord 0 -Note 'Telemetry off'
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' DWord 0
    Set-ServiceStart 'DiagTrack' Disabled -Note 'DiagTrack (Connected User Experiences) disabled'
    Set-ServiceStart 'dmwappushservice' Disabled

    # --- Activity history / timeline -------------------------------------
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' DWord 0 -Note 'Activity history off'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' DWord 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' DWord 0

    # --- Consumer features / suggested content ---------------------------
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' DWord 1 -Note 'Consumer features off'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' DWord 1

    # --- Advertising ID / tailored experiences (per-user) ----------------
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' DWord 0 -Note 'Advertising ID off'
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' DWord 0

    # --- Content Delivery Manager (suggestions/auto-install ads) ----------
    $cdm = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    foreach ($v in 'SilentInstalledAppsEnabled','SystemPaneSuggestionsEnabled','SoftLandingEnabled',
                    'SubscribedContent-338388Enabled','SubscribedContent-338389Enabled',
                    'SubscribedContent-353698Enabled','PreInstalledAppsEnabled','OemPreInstalledAppsEnabled') {
        Set-Reg $cdm $v DWord 0
    }
    Add-Change 'Start/lockscreen suggestions off'

    # --- Location ---------------------------------------------------------
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' String 'Deny' -Note 'Location access denied'

    # --- Delivery Optimization (P2P update sharing) ----------------------
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' 'DODownloadMode' DWord 0 -Note 'Delivery Optimization P2P off'
    Set-ServiceStart 'DoSvc' Manual

    # --- Wi-Fi Sense ------------------------------------------------------
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting' 'value' DWord 0
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots' 'value' DWord 0

    # --- Show file extensions + hidden files (QoL) -----------------------
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' DWord 0 -Note 'File extensions shown'

    # ---------------------------------------------------------------------
    #  Clean-profile-only, more aggressive trimming.
    # ---------------------------------------------------------------------
    if ($clean) {
        Write-Log 'Clean profile: extra service trim + telemetry tasks' 'INFO'

        # Background apps off (global, per-user) + policy
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' DWord 1 -Note 'Background apps off'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' DWord 2

        # Services to Manual (safe, reversible set from winutil)
        foreach ($svc in 'SysMain','MapsBroker','RetailDemo','WSearch','PcaSvc','RemoteRegistry') {
            Set-ServiceStart $svc Manual
        }

        # Disable known telemetry scheduled tasks (revert does NOT re-enable; noted in README)
        $tasks = @(
            '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
            '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
            '\Microsoft\Windows\Autochk\Proxy',
            '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
            '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
            '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector'
        )
        foreach ($t in $tasks) {
            if ($Global:Sel01Tweaker.DryRun) { Write-Log "DRYRUN disable task: $t" 'INFO'; continue }
            schtasks /Change /TN $t /Disable 2>$null | Out-Null
        }
        Add-Change 'Telemetry scheduled tasks disabled'

        # Disable hibernation (frees disk; also kills Fast Startup)
        if (-not $Global:Sel01Tweaker.DryRun) { powercfg /hibernate off 2>$null | Out-Null }
        Add-Change 'Hibernation off'
    }
}
