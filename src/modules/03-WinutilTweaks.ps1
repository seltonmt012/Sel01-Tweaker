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

    # --- Unused background services -> Manual (both profiles) -------------
    # Manual (NOT Disabled) so an app can still start them on demand: zero idle
    # cost, nothing breaks, fully reversible. Skipped automatically if absent.
    # Deliberately NOT touched: Defender/Update/firewall/crypto, Print Spooler
    # (printing), Bluetooth (headsets/controllers), Audio, networking core.
    # NOTE: DPS (Diagnostic Policy Service) intentionally NOT here - its service
    # key is ACL-protected (TrustedInstaller), so writing Start fails with
    # PermissionDenied. Not worth an ownership takeover for a medium-risk tweak.
    foreach ($svc in 'Fax','WMPNetworkSvc','WerSvc','MapsBroker','RetailDemo',
                      'lfsvc','PhoneSvc','diagsvc','WpcMonSvc','RemoteRegistry',
                      'SensorService','DusmSvc','TabletInputService','wisvc',
                      'PushToInstall','embeddedmode') {
        Set-ServiceStart $svc Manual
    }
    # AllJoyn IoT routing - effectively never used on a gaming PC.
    Set-ServiceStart 'AJRouter' Disabled
    Add-Change 'Unused background services set to Manual'

    # Widgets / News-and-Interests background webview off (policy, reversible).
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' DWord 0 -Note 'Widgets/News background off'

    # Bing / web results in Start search off (backstop for offline runs where the
    # Win11Debloat -DisableBing download is skipped).
    Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' DWord 1 -Note 'Bing/web in Start search off'
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' DWord 0

    # ---------------------------------------------------------------------
    #  Clean-profile-only, more aggressive trimming.
    # ---------------------------------------------------------------------
    if ($clean) {
        Write-Log 'Clean profile: extra service trim + telemetry tasks' 'INFO'

        # Background apps off (global, per-user) + policy
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' DWord 1 -Note 'Background apps off'
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BackgroundAppGlobalToggle' DWord 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' DWord 2

        # Services to Manual (safe, reversible). Clean = Office box, no gaming,
        # so Xbox stack goes Manual too (Gaming profile KEEPS it for Game Bar/HAGS).
        foreach ($svc in 'SysMain','WSearch','PcaSvc',
                          'XblAuthManager','XblGameSave','XboxGipSvc','XboxNetApiSvc',
                          'SCardSvr','ScDeviceEnum','WbioSrvc','SEMgrSvc','stisvc',
                          'icssvc','TrkWks','SharedRealitySvc',
                          'OneSyncSvc','CDPUserSvc','cbdhsvc','PimIndexMaintenanceSvc',
                          'MessagingService','AarSvc') {
            Set-ServiceStart $svc Manual
        }
        foreach ($svc in 'tzautoupdate','WalletService','AssignedAccessManagerSvc') {
            Set-ServiceStart $svc Disabled
        }

        # (Telemetry scheduled tasks are handled centrally + revertably in module 10.)

        # OneDrive consumer autostart off (one fewer startup process). Reversible:
        # -Revert re-creates the Run entry. Does not uninstall OneDrive.
        Remove-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' 'OneDrive' -Note 'OneDrive autostart off (Clean)'

        # Disable hibernation (frees disk; also kills Fast Startup)
        if (-not $Global:Sel01Tweaker.DryRun) { powercfg /hibernate off 2>$null | Out-Null }
        Add-Change 'Hibernation off'
    }
}
