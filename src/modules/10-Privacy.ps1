# ============================================================================
#  Module 10 - Privacy+ / Telemetry deep  (both profiles, Win10 + 11)
#  Additive batch cross-referenced from OSS projects (Disassembler0, Sophia,
#  privacy.sexy, hellzerg/optimizer) by two research passes. All SAFE +
#  reversible; nothing here weakens Defender/SmartScreen, breaks updates,
#  audio, printing, or other apps. Registry via Set-Reg (idempotent); telemetry
#  tasks via Disable-Task (re-enabled on -Revert).
# ============================================================================

function Invoke-Module-Privacy {
    Write-Log '=== Module: Privacy+ / Telemetry (deep) ===' 'STEP'

    # --- CEIP / app-compat inventory -------------------------------------
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\SQMClient\Windows' 'CEIPEnable' DWord 0 -Note 'CEIP off'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows' 'CEIPEnable' DWord 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'AITEnable' DWord 0 -Note 'App-impact telemetry off'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'DisableInventory' DWord 1

    # --- Windows Error Reporting (upload only; local crash handling stays) -
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' 'Disabled' DWord 1 -Note 'Error Reporting upload off'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'Disabled' DWord 1

    # --- Tailored experiences / cloud-optimized content / ad policy -------
    Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' DWord 1 -Note 'Tailored experiences off (policy)'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableCloudOptimizedContent' DWord 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' DWord 1 -Note 'Advertising ID off (policy)'

    # --- Speech / inking / typing personalization ------------------------
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted' DWord 0 -Note 'Online speech recognition off'
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' DWord 1 -Note 'Inking/typing data collection off'
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' DWord 1
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore' 'HarvestContacts' DWord 0
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Personalization\Settings' 'AcceptedPrivacyPolicy' DWord 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\TextInput' 'AllowLinguisticDataCollection' DWord 0
    Set-Reg 'HKCU:\Control Panel\International\User Profile' 'HttpAcceptLanguageOptOut' DWord 1 -Note 'Website language-list access off'

    # --- Feedback nags ---------------------------------------------------
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' DWord 0 -Note 'Feedback frequency = never'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' DWord 1

    # --- Cloud clipboard sync (local Win+V history kept) -----------------
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Clipboard' 'CloudClipboardAutomaticUpload' DWord 0 -Note 'Cloud clipboard sync off (local kept)'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'AllowCrossDeviceClipboard' DWord 0

    # --- Find My Device ---------------------------------------------------
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice' 'AllowFindMyDevice' DWord 0 -Note 'Find My Device off'

    # --- Diagtrack ETW autologger ----------------------------------------
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\AutoLogger-Diagtrack-Listener' 'Start' DWord 0 -Note 'Diagtrack ETW trace off'

    # --- Edge telemetry (browser keeps working) --------------------------
    $edge = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    Set-Reg $edge 'MetricsReportingEnabled'        DWord 0 -Note 'Edge telemetry/metrics off'
    Set-Reg $edge 'SendSiteInfoToImproveServices'  DWord 0
    Set-Reg $edge 'PersonalizationReportingEnabled' DWord 0
    Set-Reg $edge 'UserFeedbackAllowed'            DWord 0

    # --- Edge debloat (shopping/collections/rewards/widget/first-run/DNT) ---
    foreach ($v in 'EdgeShoppingAssistantEnabled','EdgeCollectionsEnabled','ShowMicrosoftRewards',
                    'WebWidgetAllowed','DiagnosticData','EdgeAssetDeliveryServiceEnabled',
                    'ShowRecommendationsEnabled') {
        Set-Reg $edge $v DWord 0
    }
    Set-Reg $edge 'HideFirstRunExperience' DWord 1 -Note 'Edge debloat (shopping/collections/rewards/widget/first-run)'
    Set-Reg $edge 'ConfigureDoNotTrack'    DWord 1
    # Remove Edge auto-launch-at-logon Run entries (one fewer startup process).
    $run = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    if (Test-Path $run) {
        (Get-Item $run).Property | Where-Object { $_ -like 'MicrosoftEdgeAutoLaunch_*' } |
            ForEach-Object { Remove-Reg $run $_ -Note 'Edge auto-launch at logon off' }
    }

    # --- Extra consumer-content / suggestions policies -------------------
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableConsumerAccountStateContent' DWord 1 -Note 'Consumer account-state content off'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableThirdPartySuggestions'       DWord 1

    # --- WPBT (OEM firmware-injected exe at boot) off --------------------
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' 'DisableWpbtExecution' DWord 1 -Note 'WPBT firmware exe execution off'

    # --- Win11 taskbar right-click End Task ------------------------------
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' DWord 1 -Note 'Taskbar right-click End Task on'

    # --- Office telemetry (no-op if Office absent) -----------------------
    Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\office\common\clienttelemetry' 'sendtelemetry' DWord 3 -Note 'Office telemetry off (if installed)'
    Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\osm' 'enablelogging' DWord 0
    Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\osm' 'enableupload'  DWord 0

    # --- Third-party dev-tool telemetry (machine env) --------------------
    Set-MachineEnv 'DOTNET_CLI_TELEMETRY_OPTOUT' '1' -Note '.NET CLI telemetry off'
    Set-MachineEnv 'POWERSHELL_TELEMETRY_OPTOUT' '1' -Note 'PowerShell 7 telemetry off'

    # --- Explorer QoL: Quick Access MRU + Aero Shake ---------------------
    $adv = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-Reg $adv 'ShowRecent'      DWord 0 -Note 'Quick Access recent files off'
    Set-Reg $adv 'ShowFrequent'    DWord 0
    Set-Reg $adv 'DisallowShaking' DWord 1 -Note 'Aero Shake off'

    # --- Update QoL: no forced reboot, active hours (updates NOT disabled)-
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoRebootWithLoggedOnUsers' DWord 1 -Note 'No forced reboot while signed in'
    $ux = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
    Set-Reg $ux 'SetActiveHours'   DWord 1 -Note 'Active hours 8-23'
    Set-Reg $ux 'ActiveHoursStart' DWord 8
    Set-Reg $ux 'ActiveHoursEnd'   DWord 23

    # --- Telemetry / feedback scheduled tasks (re-enabled on revert) -----
    foreach ($t in @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
        '\Microsoft\Windows\Application Experience\AitAgent',
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
        '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
        '\Microsoft\Windows\Autochk\Proxy',
        '\Microsoft\Windows\Feedback\Siuf\DmClient',
        '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
        '\Microsoft\Windows\Windows Error Reporting\QueueReporting',
        '\Microsoft\Windows\CloudExperienceHost\CreateObjectTask',
        '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
        '\Microsoft\Windows\Application Experience\StartupAppTask',
        '\Microsoft\Windows\Application Experience\PcaPatchDbTask',
        '\Microsoft\Windows\Application Experience\MareBackup',
        '\Microsoft\Windows\Maps\MapsToastTask',
        '\Microsoft\Windows\Maps\MapsUpdateTask',
        '\Microsoft\Windows\Retail Demo\CleanupOfflineContent',
        '\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem',
        '\Microsoft\Windows\Maintenance\WinSAT',
        '\Microsoft\Windows\NetTrace\GatherNetworkInfo',
        '\Microsoft\Windows\PI\Sqm-Tasks',
        '\Microsoft\Office\OfficeTelemetryAgentLogOn',
        '\Microsoft\Office\OfficeTelemetryAgentFallBack',
        '\Microsoft\Windows\Application Experience\PcaWallpaperAppDetect',
        '\Microsoft\Windows\ApplicationData\appuriverifierdaily',
        '\Microsoft\Windows\ApplicationData\appuriverifierinstall',
        '\Microsoft\Windows\Flighting\FeatureConfig\ReconcileFeatures',
        '\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReporting',
        '\Microsoft\Windows\Flighting\OneSettings\RefreshCache',
        '\Microsoft\Windows\DiskFootprint\Diagnostics',
        '\Microsoft\Windows\Device Information\Device',
        '\Microsoft\Windows\Device Information\Device User',
        '\Microsoft\Windows\Diagnosis\Scheduled'
    )) { Disable-Task $t }
    Add-Change 'Telemetry/feedback scheduled tasks disabled (revertable)'

    # --- Clean-only: online speech models + cellular metadata ------------
    # Speech models: only safe if voice typing is unused. MNO parser: leave on
    # for cellular laptops, so desktop/Clean only.
    if ($Global:Sel01Tweaker.Profile -eq 'Clean') {
        foreach ($t in @(
            '\Microsoft\Windows\Speech\SpeechModelDownloadTask',
            '\Microsoft\Windows\Mobile Broadband Accounts\MNO Metadata Parser',
            '\Microsoft\Windows\Shell\FamilySafetyMonitor',
            '\Microsoft\Windows\Shell\FamilySafetyRefreshTask',
            '\Microsoft\Windows\Workplace Join\Automatic-Device-Join'
        )) { Disable-Task $t }
    }
}
